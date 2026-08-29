///|
const SCHEMA_VERSION : Int = 1

///|
fn encode_name(name : String) -> String {
  let bytes = @utf8.encode(name)
  let builder = StringBuilder(size_hint=bytes.length() * 2)
  for byte in bytes {
    let encoded = byte.to_hex()
    if encoded.length() == 1 {
      builder.write_char('0')
    }
    builder.write_string(encoded)
  }
  builder.to_string()
}

///|
fn encoded_name_compare(left : String, right : String) -> Int {
  let left_name = encode_name(left)
  let right_name = encode_name(right)
  let common = left_name.length().min(right_name.length())
  for index in 0..<common {
    let left_code = left_name[index].to_int()
    let right_code = right_name[index].to_int()
    if left_code != right_code {
      return left_code - right_code
    }
  }
  left_name.length() - right_name.length()
}

///|
fn encode_type(signal_type : @ir.SignalType) -> String {
  match signal_type {
    Clock => "clock"
    Reset => "reset"
    Bits(width) => "bits:\{width.bits()}"
    UInt(width) => "uint:\{width.bits()}"
    SInt(width) => "sint:\{width.bits()}"
  }
}

///|
fn write_node(builder : StringBuilder, node : @ir.Node) -> Unit {
  builder.write_string(
    "NODE \{node.id().ordinal()} \{encode_type(node.signal_type())} ",
  )
  match node.kind() {
    Input(name) => builder.write_string("input \{encode_name(name)}")
    Constant(value) => builder.write_string("const \{value}")
    Add(lhs, rhs) =>
      builder.write_string("add \{lhs.ordinal()} \{rhs.ordinal()}")
    Sub(lhs, rhs) =>
      builder.write_string("sub \{lhs.ordinal()} \{rhs.ordinal()}")
    MulLow(lhs, rhs) =>
      builder.write_string("mul_low \{lhs.ordinal()} \{rhs.ordinal()}")
    MulFull(lhs, rhs) =>
      builder.write_string("mul_full \{lhs.ordinal()} \{rhs.ordinal()}")
    BitAnd(lhs, rhs) =>
      builder.write_string("and \{lhs.ordinal()} \{rhs.ordinal()}")
    BitOr(lhs, rhs) =>
      builder.write_string("or \{lhs.ordinal()} \{rhs.ordinal()}")
    BitXor(lhs, rhs) =>
      builder.write_string("xor \{lhs.ordinal()} \{rhs.ordinal()}")
    BitNot(operand) => builder.write_string("not \{operand.ordinal()}")
    Equal(lhs, rhs) =>
      builder.write_string("eq \{lhs.ordinal()} \{rhs.ordinal()}")
    LessThan(lhs, rhs) =>
      builder.write_string("lt \{lhs.ordinal()} \{rhs.ordinal()}")
    LessEqual(lhs, rhs) =>
      builder.write_string("le \{lhs.ordinal()} \{rhs.ordinal()}")
    ShiftLeft(value~, amount~) =>
      builder.write_string("shl \{value.ordinal()} \{amount.ordinal()}")
    LogicalShiftRight(value~, amount~) =>
      builder.write_string("lshr \{value.ordinal()} \{amount.ordinal()}")
    ArithmeticShiftRight(value~, amount~) =>
      builder.write_string("ashr \{value.ordinal()} \{amount.ordinal()}")
    Slice(value~, msb~, lsb~) =>
      builder.write_string("slice \{value.ordinal()} \{msb} \{lsb}")
    Concat(most_significant~, least_significant~) =>
      builder.write_string(
        "concat \{most_significant.ordinal()} \{least_significant.ordinal()}",
      )
    ZeroExtend(value) => builder.write_string("zext \{value.ordinal()}")
    SignExtend(value) => builder.write_string("sext \{value.ordinal()}")
    Truncate(value) => builder.write_string("trunc \{value.ordinal()}")
    Reinterpret(value) => builder.write_string("reinterpret \{value.ordinal()}")
    Mux(select~, when_true~, when_false~) =>
      builder.write_string(
        "mux \{select.ordinal()} \{when_true.ordinal()} \{when_false.ordinal()}",
      )
    Register(clock~, next~, initial~) => {
      builder.write_string("reg \{clock.ordinal()} \{next.ordinal()} ")
      match initial {
        None => builder.write_string("none")
        Some(value) => builder.write_string("some \{value}")
      }
    }
  }
  builder.write_char('\n')
}

///|
fn write_module(builder : StringBuilder, hardware_module : @ir.Module) -> Unit {
  builder.write_string("MODULE \{encode_name(hardware_module.name())}\n")
  let nodes = hardware_module.nodes()
  builder.write_string("NODES \{nodes.length()}\n")
  for node in nodes {
    write_node(builder, node)
  }
  let outputs = hardware_module.outputs().iter().to_array()
  outputs.sort_by((left, right) => {
    encoded_name_compare(left.name(), right.name())
  })
  builder.write_string("OUTPUTS \{outputs.length()}\n")
  for output in outputs {
    builder.write_string(
      "OUTPUT \{encode_name(output.name())} \{encode_type(output.signal_type())} \{output.driver().ordinal()}\n",
    )
  }
  builder.write_string("ENDMODULE\n")
}

///|
/// Serialize a validated design to LunaChip canonical IR text schema version
/// 1. Modules and output ports are ordered by their UTF-8 hex names; nodes stay
/// in validated ordinal order because their identifiers encode dependencies.
/// The result always ends in exactly one newline.
pub fn serialize(design : @ir.Design) -> String {
  let builder = StringBuilder()
  builder.write_string("LUNACHIP-IR \{SCHEMA_VERSION}\n")
  builder.write_string("DESIGN \{encode_name(design.name())}\n")
  builder.write_string("TOP \{encode_name(design.top_name())}\n")
  let modules = design.modules().iter().to_array()
  modules.sort_by((left, right) => {
    encoded_name_compare(left.name(), right.name())
  })
  builder.write_string("MODULES \{modules.length()}\n")
  for hardware_module in modules {
    write_module(builder, hardware_module)
  }
  builder.write_string("END\n")
  builder.to_string()
}

///|
/// Compute FNV-1a-64 over the exact UTF-8 bytes returned by `serialize`.
/// This bootstrap digest is deterministic but deliberately non-cryptographic.
pub fn content_digest(design : @ir.Design) -> ContentDigest64 {
  let canonical = @utf8.encode(serialize(design))
  let mut hash = 14695981039346656037UL
  for byte in canonical {
    hash = (hash ^ byte.to_uint64()) * 1099511628211UL
  }
  ContentDigest64(hash)
}
