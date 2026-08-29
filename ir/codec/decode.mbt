///|
priv struct Reader {
  lines : Array[String]
  mut cursor : Int
}

///|
fn Reader::line_number(self : Reader) -> Int {
  self.cursor + 1
}

///|
fn Reader::next(self : Reader, expected : String) -> String raise CodecError {
  if self.cursor >= self.lines.length() - 1 {
    raise UnexpectedEnd(expected~)
  }
  let line = self.lines[self.cursor]
  self.cursor += 1
  line
}

///|
fn Reader::tokens(
  self : Reader,
  expected : String,
) -> (Int, Array[String]) raise CodecError {
  let line_number = self.line_number()
  let line = self.next(expected)
  let tokens = line.split(" ").map(part => part.to_owned()).to_array()
  (line_number, tokens)
}

///|
fn require_token_count(
  line : Int,
  tokens : Array[String],
  count : Int,
  expected : String,
) -> Unit raise CodecError {
  if tokens.length() != count {
    raise UnexpectedLine(line~, expected~, actual=tokens.join(" "))
  }
}

///|
fn require_keyword(
  line : Int,
  tokens : Array[String],
  keyword : String,
  expected : String,
) -> Unit raise CodecError {
  if tokens.length() == 0 || tokens[0] != keyword {
    raise UnexpectedLine(line~, expected~, actual=tokens.join(" "))
  }
}

///|
fn parse_int(
  line : Int,
  field : String,
  value : String,
) -> Int raise CodecError {
  let parsed : Int = @strconv.from_str(value) catch {
    _ => raise InvalidInteger(line~, field~, value~)
  }
  parsed
}

///|
fn parse_uint64(
  line : Int,
  field : String,
  value : String,
) -> UInt64 raise CodecError {
  let parsed : UInt64 = @strconv.from_str(value) catch {
    _ => raise InvalidInteger(line~, field~, value~)
  }
  parsed
}

///|
fn parse_node_id(
  line : Int,
  field : String,
  value : String,
) -> @ir.NodeId raise CodecError {
  @ir.NodeId::new(parse_int(line, field, value)) catch {
    error => raise IrRejected(reason="\{Repr(error)}")
  }
}

///|
fn hex_nibble(code : UInt16) -> Int? {
  let value = code.to_int()
  if value >= 48 && value <= 57 {
    Some(value - 48)
  } else if value >= 97 && value <= 102 {
    Some(value - 97 + 10)
  } else {
    None
  }
}

///|
fn decode_name(line : Int, encoded : String) -> String raise CodecError {
  if encoded.length() == 0 || encoded.length() % 2 != 0 {
    raise InvalidEncodedName(line~, value=encoded)
  }
  let bytes : Array[Byte] = []
  for index in 0..<(encoded.length() / 2) {
    guard hex_nibble(encoded[index * 2]) is Some(high) else {
      raise InvalidEncodedName(line~, value=encoded)
    }
    guard hex_nibble(encoded[index * 2 + 1]) is Some(low) else {
      raise InvalidEncodedName(line~, value=encoded)
    }
    bytes.push(((high << 4) | low).to_byte())
  }
  @utf8.decode(Bytes::from_array(bytes)) catch {
    _ => raise InvalidUtf8Name(line~)
  }
}

///|
fn parse_count(
  line : Int,
  field : String,
  value : String,
) -> Int raise CodecError {
  let count = parse_int(line, field, value)
  if count < 0 {
    raise InvalidCount(line~, field~, value=count)
  }
  count
}

///|
fn parse_type(line : Int, encoded : String) -> @ir.SignalType raise CodecError {
  match encoded {
    "clock" => Clock
    "reset" => Reset
    _ => {
      let pieces = encoded.split(":").map(part => part.to_owned()).to_array()
      if pieces.length() != 2 {
        raise UnexpectedLine(line~, expected="signal type", actual=encoded)
      }
      let width = @ir.Width::new(parse_int(line, "width", pieces[1])) catch {
        error => raise IrRejected(reason="\{Repr(error)}")
      }
      match pieces[0] {
        "bits" => Bits(width)
        "uint" => UInt(width)
        "sint" => SInt(width)
        _ => raise UnexpectedLine(line~, expected="signal type", actual=encoded)
      }
    }
  }
}

///|
fn parse_node_kind(
  line : Int,
  tokens : Array[String],
) -> @ir.NodeKind raise CodecError {
  let operation = tokens[3]
  match operation {
    "input" => {
      require_token_count(line, tokens, 5, "NODE id type input name")
      Input(decode_name(line, tokens[4]))
    }
    "const" => {
      require_token_count(line, tokens, 5, "NODE id type const value")
      Constant(parse_uint64(line, "constant", tokens[4]))
    }
    "add"
    | "sub"
    | "mul_low"
    | "mul_full"
    | "and"
    | "or"
    | "xor"
    | "eq"
    | "lt"
    | "le" => {
      require_token_count(line, tokens, 6, "NODE id type binary lhs rhs")
      let lhs = parse_node_id(line, "lhs", tokens[4])
      let rhs = parse_node_id(line, "rhs", tokens[5])
      match operation {
        "add" => Add(lhs, rhs)
        "sub" => Sub(lhs, rhs)
        "mul_low" => MulLow(lhs, rhs)
        "mul_full" => MulFull(lhs, rhs)
        "and" => BitAnd(lhs, rhs)
        "or" => BitOr(lhs, rhs)
        "xor" => BitXor(lhs, rhs)
        "eq" => Equal(lhs, rhs)
        "lt" => LessThan(lhs, rhs)
        _ => LessEqual(lhs, rhs)
      }
    }
    "not" => {
      require_token_count(line, tokens, 5, "NODE id type not operand")
      let operand = parse_node_id(line, "operand", tokens[4])
      BitNot(operand)
    }
    "shl" | "lshr" | "ashr" => {
      require_token_count(line, tokens, 6, "NODE id type shift value amount")
      let value = parse_node_id(line, "value", tokens[4])
      let amount = parse_node_id(line, "amount", tokens[5])
      match operation {
        "shl" => ShiftLeft(value~, amount~)
        "lshr" => LogicalShiftRight(value~, amount~)
        _ => ArithmeticShiftRight(value~, amount~)
      }
    }
    "slice" => {
      require_token_count(line, tokens, 7, "NODE id type slice value msb lsb")
      let value = parse_node_id(line, "value", tokens[4])
      let msb = parse_int(line, "msb", tokens[5])
      let lsb = parse_int(line, "lsb", tokens[6])
      Slice(value~, msb~, lsb~)
    }
    "concat" => {
      require_token_count(line, tokens, 6, "NODE id type concat msb lsb")
      let most_significant = parse_node_id(line, "most significant", tokens[4])
      let least_significant = parse_node_id(
        line,
        "least significant",
        tokens[5],
      )
      Concat(most_significant~, least_significant~)
    }
    "zext" | "sext" | "trunc" | "reinterpret" => {
      require_token_count(line, tokens, 5, "NODE id type conversion value")
      let value = parse_node_id(line, "value", tokens[4])
      match operation {
        "zext" => ZeroExtend(value)
        "sext" => SignExtend(value)
        "trunc" => Truncate(value)
        _ => Reinterpret(value)
      }
    }
    "mux" => {
      require_token_count(line, tokens, 7, "NODE id type mux select true false")
      let select = parse_node_id(line, "select", tokens[4])
      let when_true = parse_node_id(line, "true", tokens[5])
      let when_false = parse_node_id(line, "false", tokens[6])
      Mux(select~, when_true~, when_false~)
    }
    "reg" => {
      if tokens.length() != 7 && tokens.length() != 8 {
        raise UnexpectedLine(
          line~,
          expected="NODE id type reg clock next none|some value",
          actual=tokens.join(" "),
        )
      }
      let clock = parse_node_id(line, "clock", tokens[4])
      let next = parse_node_id(line, "next", tokens[5])
      let initial = match tokens[6] {
        "none" => {
          require_token_count(
            line, tokens, 7, "NODE id type reg clock next none",
          )
          None
        }
        "some" => {
          require_token_count(
            line, tokens, 8, "NODE id type reg clock next some value",
          )
          Some(parse_uint64(line, "initial", tokens[7]))
        }
        _ =>
          raise UnexpectedLine(
            line~,
            expected="register initial value",
            actual=tokens[6],
          )
      }
      Register(clock~, next~, initial~)
    }
    _ =>
      raise UnexpectedLine(line~, expected="node operation", actual=operation)
  }
}

///|
fn parse_node(reader : Reader) -> @ir.Node raise CodecError {
  let (line, tokens) = reader.tokens("NODE")
  if tokens.length() < 4 {
    raise UnexpectedLine(
      line~,
      expected="NODE id type operation",
      actual=tokens.join(" "),
    )
  }
  require_keyword(line, tokens, "NODE", "NODE")
  let id = parse_node_id(line, "node id", tokens[1])
  let signal_type = parse_type(line, tokens[2])
  @ir.Node::new(id, signal_type, parse_node_kind(line, tokens))
}

///|
fn parse_output(reader : Reader) -> @ir.OutputPort raise CodecError {
  let (line, tokens) = reader.tokens("OUTPUT name type driver")
  require_token_count(line, tokens, 4, "OUTPUT name type driver")
  require_keyword(line, tokens, "OUTPUT", "OUTPUT")
  let name = decode_name(line, tokens[1])
  let signal_type = parse_type(line, tokens[2])
  let driver = parse_node_id(line, "driver", tokens[3])
  @ir.OutputPort::new(name, signal_type, driver)
}

///|
fn parse_module(reader : Reader) -> @ir.Module raise CodecError {
  let (module_line, module_tokens) = reader.tokens("MODULE name")
  require_token_count(module_line, module_tokens, 2, "MODULE name")
  require_keyword(module_line, module_tokens, "MODULE", "MODULE")
  let name = decode_name(module_line, module_tokens[1])
  let (nodes_line, nodes_tokens) = reader.tokens("NODES count")
  require_token_count(nodes_line, nodes_tokens, 2, "NODES count")
  require_keyword(nodes_line, nodes_tokens, "NODES", "NODES")
  let node_count = parse_count(nodes_line, "nodes", nodes_tokens[1])
  let nodes : Array[@ir.Node] = []
  for _ in 0..<node_count {
    nodes.push(parse_node(reader))
  }
  let (outputs_line, outputs_tokens) = reader.tokens("OUTPUTS count")
  require_token_count(outputs_line, outputs_tokens, 2, "OUTPUTS count")
  require_keyword(outputs_line, outputs_tokens, "OUTPUTS", "OUTPUTS")
  let output_count = parse_count(outputs_line, "outputs", outputs_tokens[1])
  let outputs : Array[@ir.OutputPort] = []
  for _ in 0..<output_count {
    outputs.push(parse_output(reader))
  }
  let end_line = reader.line_number()
  let end_module = reader.next("ENDMODULE")
  if end_module != "ENDMODULE" {
    raise UnexpectedLine(line=end_line, expected="ENDMODULE", actual=end_module)
  }
  @ir.Module::checked(name, nodes, outputs) catch {
    error => raise IrRejected(reason="\{Repr(error)}")
  }
}

///|
fn parse_document(text : String) -> @ir.Design raise CodecError {
  let lines = text.split("\n").map(line => line.to_owned()).to_array()
  let reader : Reader = { lines, cursor: 0 }
  let (header_line, header) = reader.tokens("LUNACHIP-IR version")
  require_token_count(header_line, header, 2, "LUNACHIP-IR version")
  require_keyword(header_line, header, "LUNACHIP-IR", "LUNACHIP-IR")
  if header[1] != "1" {
    raise UnsupportedVersion(header[1])
  }
  let (design_line, design_tokens) = reader.tokens("DESIGN name")
  require_token_count(design_line, design_tokens, 2, "DESIGN name")
  require_keyword(design_line, design_tokens, "DESIGN", "DESIGN")
  let design_name = decode_name(design_line, design_tokens[1])
  let (top_line, top_tokens) = reader.tokens("TOP name")
  require_token_count(top_line, top_tokens, 2, "TOP name")
  require_keyword(top_line, top_tokens, "TOP", "TOP")
  let top = decode_name(top_line, top_tokens[1])
  let (modules_line, modules_tokens) = reader.tokens("MODULES count")
  require_token_count(modules_line, modules_tokens, 2, "MODULES count")
  require_keyword(modules_line, modules_tokens, "MODULES", "MODULES")
  let module_count = parse_count(modules_line, "modules", modules_tokens[1])
  let modules : Array[@ir.Module] = []
  for _ in 0..<module_count {
    modules.push(parse_module(reader))
  }
  let end_line = reader.line_number()
  let end_design = reader.next("END")
  if end_design != "END" {
    raise UnexpectedLine(line=end_line, expected="END", actual=end_design)
  }
  if reader.cursor != lines.length() - 1 || lines[lines.length() - 1] != "" {
    let actual = if reader.cursor < lines.length() {
      lines[reader.cursor]
    } else {
      "<end-of-input>"
    }
    raise UnexpectedLine(
      line=reader.line_number(),
      expected="end of document",
      actual~,
    )
  }
  @ir.Design::checked(design_name, modules, top) catch {
    error => raise IrRejected(reason="\{Repr(error)}")
  }
}

///|
/// Parse schema version 1 canonical text and rebuild every object through the
/// checked public IR constructors. Documents that decode but differ from the
/// canonical serializer are rejected instead of being silently normalized.
pub fn parse(text : String) -> @ir.Design raise CodecError {
  let design = parse_document(text)
  if serialize(design) != text {
    raise NonCanonical
  }
  design
}
