///|
const MAX_CODEC_AGGREGATE_DEPTH : Int = 64

///|
const MAX_CODEC_AGGREGATE_LEAVES : Int = 65536

///|
priv struct MetadataReader {
  lines : Array[String]
  mut cursor : Int
}

///|
fn MetadataReader::line_number(self : MetadataReader) -> Int {
  self.cursor + 1
}

///|
fn MetadataReader::next(
  self : MetadataReader,
  expected : String,
) -> String raise CodecError {
  if self.cursor >= self.lines.length() - 1 {
    raise UnexpectedEnd(expected~)
  }
  let line = self.lines[self.cursor]
  self.cursor += 1
  line
}

///|
fn MetadataReader::tokens(
  self : MetadataReader,
  expected : String,
) -> (Int, Array[String]) raise CodecError {
  let line_number = self.line_number()
  let line = self.next(expected)
  let tokens = line.split(" ").map(part => part.to_owned()).to_array()
  (line_number, tokens)
}

///|
fn parse_int64(
  line : Int,
  field : String,
  value : String,
) -> Int64 raise CodecError {
  let parsed : Int64 = @strconv.from_str(value) catch {
    _ => raise InvalidInteger(line~, field~, value~)
  }
  parsed
}

///|
fn parse_parameter(
  reader : MetadataReader,
) -> @ir.ModuleParameter raise CodecError {
  let (line, tokens) = reader.tokens("PARAMETER name kind value")
  require_token_count(line, tokens, 4, "PARAMETER name kind value")
  require_keyword(line, tokens, "PARAMETER", "PARAMETER")
  let name = decode_name(line, tokens[1])
  let value = match tokens[2] {
    "boolean" =>
      match tokens[3] {
        "true" => @ir.ParameterValue::Boolean(true)
        "false" => Boolean(false)
        actual =>
          raise UnexpectedLine(
            line~,
            expected="boolean parameter value",
            actual~,
          )
      }
    "signed" => Signed(parse_int64(line, "signed parameter", tokens[3]))
    "unsigned" => Unsigned(parse_uint64(line, "unsigned parameter", tokens[3]))
    "text" => {
      let text = if tokens[3] == "-" {
        ""
      } else {
        decode_name(line, tokens[3])
      }
      Text(text)
    }
    "signal_type" => SignalTypeValue(parse_type(line, tokens[3]))
    actual => raise UnexpectedLine(line~, expected="parameter kind", actual~)
  }
  @ir.ModuleParameter::checked(name, value) catch {
    error => raise IrRejected(reason="\{Repr(error)}")
  }
}

///|
fn parse_parameters(
  reader : MetadataReader,
) -> Array[@ir.ModuleParameter] raise CodecError {
  let (line, tokens) = reader.tokens("PARAMETERS count")
  require_token_count(line, tokens, 2, "PARAMETERS count")
  require_keyword(line, tokens, "PARAMETERS", "PARAMETERS")
  let count = parse_count(line, "parameters", tokens[1])
  let parameters : Array[@ir.ModuleParameter] = []
  for _ in 0..<count {
    parameters.push(parse_parameter(reader))
  }
  parameters
}

///|
fn parse_input_timing(
  reader : MetadataReader,
) -> @ir.InputTimingBinding raise CodecError {
  let (line, tokens) = reader.tokens("INPUT_TIMING node timing")
  require_keyword(line, tokens, "INPUT_TIMING", "INPUT_TIMING")
  if tokens.length() != 3 && tokens.length() != 4 {
    raise UnexpectedLine(
      line~,
      expected="INPUT_TIMING node asynchronous|sampled_in domain",
      actual=tokens.join(" "),
    )
  }
  let input = parse_node_id(line, "timed input", tokens[1])
  let timing = match tokens[2] {
    "asynchronous" => {
      require_token_count(line, tokens, 3, "INPUT_TIMING node asynchronous")
      @ir.InputTiming::Asynchronous
    }
    "sampled_in" => {
      require_token_count(
        line, tokens, 4, "INPUT_TIMING node sampled_in domain",
      )
      SampledIn(parse_domain_id(line, "sampled input domain", tokens[3]))
    }
    actual => raise UnexpectedLine(line~, expected="input timing", actual~)
  }
  @ir.InputTimingBinding::new(input, timing)
}

///|
fn parse_input_timings(
  reader : MetadataReader,
) -> Array[@ir.InputTimingBinding] raise CodecError {
  let (line, tokens) = reader.tokens("INPUT_TIMINGS count")
  require_token_count(line, tokens, 2, "INPUT_TIMINGS count")
  require_keyword(line, tokens, "INPUT_TIMINGS", "INPUT_TIMINGS")
  let count = parse_count(line, "input timings", tokens[1])
  let timings : Array[@ir.InputTimingBinding] = []
  for _ in 0..<count {
    timings.push(parse_input_timing(reader))
  }
  timings
}

///|
fn parse_output_timing(
  reader : MetadataReader,
) -> @ir.OutputTimingBinding raise CodecError {
  let (line, tokens) = reader.tokens("OUTPUT_TIMING output timing")
  require_keyword(line, tokens, "OUTPUT_TIMING", "OUTPUT_TIMING")
  if tokens.length() != 3 && tokens.length() != 4 {
    raise UnexpectedLine(
      line~,
      expected="OUTPUT_TIMING output static|asynchronous|produced_in domain",
      actual=tokens.join(" "),
    )
  }
  let output = decode_name(line, tokens[1])
  let timing = match tokens[2] {
    "static" => {
      require_token_count(line, tokens, 3, "OUTPUT_TIMING output static")
      @ir.OutputTiming::Static
    }
    "asynchronous" => {
      require_token_count(line, tokens, 3, "OUTPUT_TIMING output asynchronous")
      Asynchronous
    }
    "produced_in" => {
      require_token_count(
        line, tokens, 4, "OUTPUT_TIMING output produced_in domain",
      )
      ProducedIn(parse_domain_id(line, "produced output domain", tokens[3]))
    }
    actual => raise UnexpectedLine(line~, expected="output timing", actual~)
  }
  @ir.OutputTimingBinding::checked(output, timing) catch {
    error => raise IrRejected(reason="\{Repr(error)}")
  }
}

///|
fn parse_output_timings(
  reader : MetadataReader,
) -> Array[@ir.OutputTimingBinding] raise CodecError {
  let (line, tokens) = reader.tokens("OUTPUT_TIMINGS count")
  require_token_count(line, tokens, 2, "OUTPUT_TIMINGS count")
  require_keyword(line, tokens, "OUTPUT_TIMINGS", "OUTPUT_TIMINGS")
  let count = parse_count(line, "output timings", tokens[1])
  let timings : Array[@ir.OutputTimingBinding] = []
  for _ in 0..<count {
    timings.push(parse_output_timing(reader))
  }
  timings
}

///|
fn reject_shape_resource(
  line : Int,
  field : String,
  value : Int,
) -> Unit raise CodecError {
  raise InvalidCount(line~, field~, value~)
}

///|
fn parse_aggregate_shape(
  reader : MetadataReader,
  depth : Int,
) -> (@aggregate.Aggregate[@ir.SignalType], Int) raise CodecError {
  let (line, tokens) = reader.tokens("SHAPE leaf|vector|record")
  if depth > MAX_CODEC_AGGREGATE_DEPTH {
    reject_shape_resource(line, "aggregate depth", depth)
  }
  if tokens.length() < 3 {
    raise UnexpectedLine(
      line~,
      expected="SHAPE leaf type|vector count|record count",
      actual=tokens.join(" "),
    )
  }
  require_keyword(line, tokens, "SHAPE", "SHAPE")
  match tokens[1] {
    "leaf" => {
      require_token_count(line, tokens, 3, "SHAPE leaf type")
      (@aggregate.Aggregate::leaf(parse_type(line, tokens[2])), 1)
    }
    "vector" => {
      require_token_count(line, tokens, 3, "SHAPE vector count")
      let length = parse_count(line, "aggregate vector length", tokens[2])
      if length <= 0 || length > MAX_CODEC_AGGREGATE_LEAVES {
        reject_shape_resource(line, "aggregate vector length", length)
      }
      let (element, element_leaves) = parse_aggregate_shape(reader, depth + 1)
      if element_leaves > MAX_CODEC_AGGREGATE_LEAVES / length {
        reject_shape_resource(
          line,
          "aggregate leaves",
          MAX_CODEC_AGGREGATE_LEAVES + 1,
        )
      }
      let shape = @aggregate.Aggregate::vector(Array::make(length, element)) catch {
        error => raise IrRejected(reason="\{Repr(error)}")
      }
      (shape, element_leaves * length)
    }
    "record" => {
      require_token_count(line, tokens, 3, "SHAPE record count")
      let count = parse_count(line, "aggregate field count", tokens[2])
      if count <= 0 || count > MAX_CODEC_AGGREGATE_LEAVES {
        reject_shape_resource(line, "aggregate field count", count)
      }
      let fields : Array[(String, @aggregate.Aggregate[@ir.SignalType])] = []
      let mut leaves = 0
      for _ in 0..<count {
        let (field_line, field_tokens) = reader.tokens("FIELD name")
        require_token_count(field_line, field_tokens, 2, "FIELD name")
        require_keyword(field_line, field_tokens, "FIELD", "FIELD")
        let name = decode_name(field_line, field_tokens[1])
        let (field, field_leaves) = parse_aggregate_shape(reader, depth + 1)
        if field_leaves > MAX_CODEC_AGGREGATE_LEAVES - leaves {
          reject_shape_resource(
            field_line,
            "aggregate leaves",
            MAX_CODEC_AGGREGATE_LEAVES + 1,
          )
        }
        leaves += field_leaves
        fields.push((name, field))
      }
      let shape = @aggregate.Aggregate::record(fields) catch {
        error => raise IrRejected(reason="\{Repr(error)}")
      }
      (shape, leaves)
    }
    actual =>
      raise UnexpectedLine(line~, expected="aggregate shape kind", actual~)
  }
}

///|
fn parse_binding_kind(
  line : Int,
  encoded : String,
) -> @ir.AggregateBindingKind raise CodecError {
  match encoded {
    "input" => InputPort
    "output" => OutputPort
    "internal" => Internal
    actual =>
      raise UnexpectedLine(line~, expected="aggregate binding kind", actual~)
  }
}

///|
fn parse_aggregate_target(
  reader : MetadataReader,
  expected_ordinal : Int,
) -> @ir.AggregateLeafTarget raise CodecError {
  let (line, tokens) = reader.tokens("ENDPOINT ordinal node|output target")
  require_token_count(line, tokens, 4, "ENDPOINT ordinal node|output target")
  require_keyword(line, tokens, "ENDPOINT", "ENDPOINT")
  let ordinal = parse_int(line, "aggregate endpoint ordinal", tokens[1])
  if ordinal != expected_ordinal {
    raise UnexpectedLine(
      line~,
      expected="ENDPOINT \{expected_ordinal}",
      actual="ENDPOINT \{ordinal}",
    )
  }
  match tokens[2] {
    "node" => Node(parse_node_id(line, "aggregate endpoint node", tokens[3]))
    "output" => Output(decode_name(line, tokens[3]))
    actual =>
      raise UnexpectedLine(line~, expected="aggregate endpoint kind", actual~)
  }
}

///|
fn parse_aggregate_binding(
  reader : MetadataReader,
) -> @ir.AggregateBinding raise CodecError {
  let (line, tokens) = reader.tokens("AGGREGATE id kind root")
  require_token_count(line, tokens, 4, "AGGREGATE id kind root")
  require_keyword(line, tokens, "AGGREGATE", "AGGREGATE")
  let id = @ir.AggregateBindingId::new(
    parse_int(line, "aggregate binding id", tokens[1]),
  ) catch {
    error => raise IrRejected(reason="\{Repr(error)}")
  }
  let kind = parse_binding_kind(line, tokens[2])
  let root = decode_name(line, tokens[3])
  let (shape, _) = parse_aggregate_shape(reader, 0)
  let (endpoints_line, endpoints_tokens) = reader.tokens("ENDPOINTS count")
  require_token_count(endpoints_line, endpoints_tokens, 2, "ENDPOINTS count")
  require_keyword(endpoints_line, endpoints_tokens, "ENDPOINTS", "ENDPOINTS")
  let count = parse_count(
    endpoints_line,
    "aggregate endpoints",
    endpoints_tokens[1],
  )
  if count > MAX_CODEC_AGGREGATE_LEAVES {
    reject_shape_resource(endpoints_line, "aggregate endpoints", count)
  }
  let endpoints : Array[@ir.AggregateLeafTarget] = []
  for ordinal in 0..<count {
    endpoints.push(parse_aggregate_target(reader, ordinal))
  }
  let end_line = reader.line_number()
  let end_aggregate = reader.next("ENDAGGREGATE")
  if end_aggregate != "ENDAGGREGATE" {
    raise UnexpectedLine(
      line=end_line,
      expected="ENDAGGREGATE",
      actual=end_aggregate,
    )
  }
  @ir.AggregateBinding::checked(id, kind, root, shape, endpoints) catch {
    error => raise IrRejected(reason="\{Repr(error)}")
  }
}

///|
fn parse_aggregate_bindings(
  reader : MetadataReader,
) -> Array[@ir.AggregateBinding] raise CodecError {
  let (line, tokens) = reader.tokens("AGGREGATES count")
  require_token_count(line, tokens, 2, "AGGREGATES count")
  require_keyword(line, tokens, "AGGREGATES", "AGGREGATES")
  let count = parse_count(line, "aggregate bindings", tokens[1])
  let bindings : Array[@ir.AggregateBinding] = []
  for _ in 0..<count {
    bindings.push(parse_aggregate_binding(reader))
  }
  bindings
}

///|
fn parse_primitives_placeholder(
  reader : MetadataReader,
) -> Unit raise CodecError {
  let (line, tokens) = reader.tokens("PRIMITIVES 0")
  require_token_count(line, tokens, 2, "PRIMITIVES 0")
  require_keyword(line, tokens, "PRIMITIVES", "PRIMITIVES")
  let count = parse_count(line, "primitives", tokens[1])
  if count != 0 {
    raise InvalidCount(line~, field="primitives", value=count)
  }
}

///|
fn parse_schema_four_post_ground_metadata(
  reader : MetadataReader,
  parameters : ArrayView[@ir.ModuleParameter],
) -> @ir.ModuleMetadata raise CodecError {
  let input_timings = parse_input_timings(reader)
  let output_timings = parse_output_timings(reader)
  let aggregate_bindings = parse_aggregate_bindings(reader)
  parse_primitives_placeholder(reader)
  @ir.ModuleMetadata::checked_with_timing(
    parameters, aggregate_bindings, input_timings, output_timings,
  ) catch {
    error => raise IrRejected(reason="\{Repr(error)}")
  }
}

///|
fn decode_schema_four_parameters(
  lines : Array[String],
  cursor : Int,
) -> (Array[@ir.ModuleParameter], Int) raise CodecError {
  let reader : MetadataReader = { lines, cursor }
  let parameters = parse_parameters(reader)
  (parameters, reader.cursor)
}

///|
fn decode_schema_four_post_ground_metadata(
  lines : Array[String],
  cursor : Int,
  parameters : ArrayView[@ir.ModuleParameter],
) -> (@ir.ModuleMetadata, Int) raise CodecError {
  let reader : MetadataReader = { lines, cursor }
  let metadata = parse_schema_four_post_ground_metadata(reader, parameters)
  (metadata, reader.cursor)
}
