///|
const MAX_CODEC_AGGREGATE_DEPTH : Int = 64

///|
const MAX_CODEC_AGGREGATE_LEAVES : Int = 65536

///|
const MAX_CODEC_CDC_PRIMITIVES : Int = 65536

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
fn parse_primitive_reset(
  reader : MetadataReader,
) -> @ir.ResetSpec? raise CodecError {
  let (line, tokens) = reader.tokens("RESET contract")
  require_keyword(line, tokens, "RESET", "RESET")
  if tokens.length() == 2 && tokens[1] == "none" {
    return None
  }
  require_token_count(
    line, tokens, 5, "RESET synchronous active_high signal value",
  )
  let mode = match tokens[1] {
    "synchronous" => @ir.ResetMode::Synchronous
    "asynchronous" => raise UnsupportedAsynchronousReset(line~)
    actual => raise UnexpectedLine(line~, expected="reset mode", actual~)
  }
  let polarity = match tokens[2] {
    "active_high" => @ir.ResetPolarity::ActiveHigh
    "active_low" => raise UnsupportedResetPolarity(line~, polarity=tokens[2])
    actual => raise UnexpectedLine(line~, expected="reset polarity", actual~)
  }
  Some(
    @ir.ResetSpec::explicit(
      parse_node_id(line, "primitive reset signal", tokens[3]),
      parse_uint64(line, "primitive reset value", tokens[4]),
      mode,
      polarity,
    ),
  )
}

///|
fn parse_bit_synchronizer(
  reader : MetadataReader,
  id : @ir.CdcPrimitiveId,
  name : String,
) -> @ir.CdcPrimitive raise CodecError {
  let (source_line, source_tokens) = reader.tokens("SOURCE class node")
  require_keyword(source_line, source_tokens, "SOURCE", "SOURCE")
  let (source_domain, source) = match source_tokens {
    ["SOURCE", "asynchronous", node] =>
      (
        @ir.CdcSourceDomain::AsynchronousSource,
        parse_node_id(source_line, "primitive source", node),
      )
    ["SOURCE", "domain", domain, node] =>
      (
        SourceDomain(
          parse_domain_id(source_line, "primitive source domain", domain),
        ),
        parse_node_id(source_line, "primitive source", node),
      )
    _ =>
      raise UnexpectedLine(
        line=source_line,
        expected="SOURCE asynchronous node|SOURCE domain domain node",
        actual=source_tokens.join(" "),
      )
  }
  let (destination_line, destination_tokens) = reader.tokens(
    "DESTINATION domain",
  )
  require_token_count(
    destination_line, destination_tokens, 2, "DESTINATION domain",
  )
  require_keyword(
    destination_line, destination_tokens, "DESTINATION", "DESTINATION",
  )
  let destination = parse_domain_id(
    destination_line,
    "primitive destination domain",
    destination_tokens[1],
  )
  let reset = parse_primitive_reset(reader)
  let (stages_line, stages_tokens) = reader.tokens("STAGES count")
  require_token_count(stages_line, stages_tokens, 2, "STAGES count")
  require_keyword(stages_line, stages_tokens, "STAGES", "STAGES")
  let count = parse_count(stages_line, "synchronizer stages", stages_tokens[1])
  let stages : Array[@ir.NodeId] = []
  for expected in 0..<count {
    let (stage_line, stage_tokens) = reader.tokens("STAGE ordinal node")
    require_token_count(stage_line, stage_tokens, 3, "STAGE ordinal node")
    require_keyword(stage_line, stage_tokens, "STAGE", "STAGE")
    let actual = parse_count(stage_line, "stage ordinal", stage_tokens[1])
    if actual != expected {
      raise UnexpectedLine(
        line=stage_line,
        expected="STAGE \{expected} node",
        actual=stage_tokens.join(" "),
      )
    }
    stages.push(
      parse_node_id(stage_line, "synchronizer stage", stage_tokens[2]),
    )
  }
  let end_line = reader.line_number()
  let end = reader.next("ENDPRIMITIVE")
  if end != "ENDPRIMITIVE" {
    raise UnexpectedLine(line=end_line, expected="ENDPRIMITIVE", actual=end)
  }
  let spec = @ir.BitSynchronizerPrimitive::checked(
    id,
    name,
    source_domain,
    source,
    destination,
    stages,
    reset?,
  ) catch {
    error => raise IrRejected(reason="\{Repr(error)}")
  }
  BitSynchronizer(spec)
}

///|
fn parse_toggle_handshake(
  reader : MetadataReader,
  id : @ir.CdcPrimitiveId,
  name : String,
) -> @ir.CdcPrimitive raise CodecError {
  let source_domain = parse_named_domain(
    reader, "SOURCE_DOMAIN", "handshake source domain",
  )
  let destination_domain = parse_named_domain(
    reader, "DESTINATION_DOMAIN", "handshake destination domain",
  )
  let source_reset = parse_named_reset(reader, "SOURCE_RESET")
  let destination_reset = parse_named_reset(reader, "DESTINATION_RESET")
  let (payload_shape, leaf_count) = parse_aggregate_shape(reader, 0)
  let source_valid = parse_named_node(
    reader, "SOURCE_VALID", "handshake source valid",
  )
  let source_ready = parse_named_node(
    reader, "SOURCE_READY", "handshake source ready",
  )
  let source_accept = parse_named_node(
    reader, "SOURCE_ACCEPT", "handshake source accept",
  )
  let (payload_line, payload_tokens) = reader.tokens("SOURCE_PAYLOADS count")
  require_token_count(payload_line, payload_tokens, 2, "SOURCE_PAYLOADS count")
  require_keyword(
    payload_line, payload_tokens, "SOURCE_PAYLOADS", "SOURCE_PAYLOADS",
  )
  let source_count = parse_count(
    payload_line,
    "handshake source payloads",
    payload_tokens[1],
  )
  if source_count != leaf_count {
    raise UnexpectedLine(
      line=payload_line,
      expected="SOURCE_PAYLOADS \{leaf_count}",
      actual=payload_tokens.join(" "),
    )
  }
  let source_payload : Array[@ir.NodeId] = []
  let held_payload : Array[@ir.NodeId] = []
  for expected in 0..<source_count {
    let (leaf_line, leaf_tokens) = reader.tokens(
      "SOURCE_PAYLOAD ordinal source held",
    )
    require_token_count(
      leaf_line, leaf_tokens, 4, "SOURCE_PAYLOAD ordinal source held",
    )
    require_keyword(leaf_line, leaf_tokens, "SOURCE_PAYLOAD", "SOURCE_PAYLOAD")
    let actual = parse_count(leaf_line, "payload ordinal", leaf_tokens[1])
    if actual != expected {
      raise UnexpectedLine(
        line=leaf_line,
        expected="SOURCE_PAYLOAD \{expected} source held",
        actual=leaf_tokens.join(" "),
      )
    }
    source_payload.push(
      parse_node_id(leaf_line, "handshake source payload", leaf_tokens[2]),
    )
    held_payload.push(
      parse_node_id(leaf_line, "handshake held payload", leaf_tokens[3]),
    )
  }
  let request_toggle = parse_named_node(
    reader, "REQUEST_TOGGLE", "handshake request toggle",
  )
  let request_stages = parse_named_stages(
    reader,
    "REQUEST_STAGES",
    "REQUEST_STAGE",
    "handshake request stage",
    None,
  )
  let request_changed = parse_named_node(
    reader, "REQUEST_CHANGED", "handshake request changed",
  )
  let destination_ready = parse_named_node(
    reader, "DESTINATION_READY", "handshake destination ready",
  )
  let destination_valid = parse_named_node(
    reader, "DESTINATION_VALID", "handshake destination valid",
  )
  let destination_available = parse_named_node(
    reader, "DESTINATION_AVAILABLE", "handshake destination available",
  )
  let destination_capture = parse_named_node(
    reader, "DESTINATION_CAPTURE", "handshake destination capture",
  )
  let destination_consume = parse_named_node(
    reader, "DESTINATION_CONSUME", "handshake destination consume",
  )
  let (destination_line, destination_tokens) = reader.tokens(
    "DESTINATION_PAYLOADS count",
  )
  require_token_count(
    destination_line, destination_tokens, 2, "DESTINATION_PAYLOADS count",
  )
  require_keyword(
    destination_line, destination_tokens, "DESTINATION_PAYLOADS", "DESTINATION_PAYLOADS",
  )
  let destination_count = parse_count(
    destination_line,
    "handshake destination payloads",
    destination_tokens[1],
  )
  if destination_count != leaf_count {
    raise UnexpectedLine(
      line=destination_line,
      expected="DESTINATION_PAYLOADS \{leaf_count}",
      actual=destination_tokens.join(" "),
    )
  }
  let destination_payload : Array[@ir.NodeId] = []
  for expected in 0..<destination_count {
    let (leaf_line, leaf_tokens) = reader.tokens(
      "DESTINATION_PAYLOAD ordinal node",
    )
    require_token_count(
      leaf_line, leaf_tokens, 3, "DESTINATION_PAYLOAD ordinal node",
    )
    require_keyword(
      leaf_line, leaf_tokens, "DESTINATION_PAYLOAD", "DESTINATION_PAYLOAD",
    )
    let actual = parse_count(leaf_line, "payload ordinal", leaf_tokens[1])
    if actual != expected {
      raise UnexpectedLine(
        line=leaf_line,
        expected="DESTINATION_PAYLOAD \{expected} node",
        actual=leaf_tokens.join(" "),
      )
    }
    destination_payload.push(
      parse_node_id(leaf_line, "handshake destination payload", leaf_tokens[2]),
    )
  }
  let acknowledge_toggle = parse_named_node(
    reader, "ACKNOWLEDGE_TOGGLE", "handshake acknowledge toggle",
  )
  let acknowledge_stages = parse_named_stages(
    reader,
    "ACKNOWLEDGE_STAGES",
    "ACKNOWLEDGE_STAGE",
    "handshake acknowledge stage",
    Some(request_stages.length()),
  )
  let end_line = reader.line_number()
  let end = reader.next("ENDPRIMITIVE")
  if end != "ENDPRIMITIVE" {
    raise UnexpectedLine(line=end_line, expected="ENDPRIMITIVE", actual=end)
  }
  let spec = @ir.ToggleHandshakePrimitive::checked(
    id, name, source_domain, destination_domain, source_reset, destination_reset,
    payload_shape, source_valid, source_ready, source_accept, source_payload, held_payload,
    request_toggle, request_stages, request_changed, destination_ready, destination_valid,
    destination_capture, destination_consume, destination_available, destination_payload,
    acknowledge_toggle, acknowledge_stages,
  ) catch {
    error => raise IrRejected(reason="\{Repr(error)}")
  }
  ToggleHandshake(spec)
}

///|
fn parse_cdc_primitive(
  reader : MetadataReader,
) -> @ir.CdcPrimitive raise CodecError {
  let (line, tokens) = reader.tokens("PRIMITIVE id kind name")
  require_token_count(line, tokens, 4, "PRIMITIVE id kind name")
  require_keyword(line, tokens, "PRIMITIVE", "PRIMITIVE")
  let id = @ir.CdcPrimitiveId::new(parse_count(line, "primitive ID", tokens[1])) catch {
    error => raise IrRejected(reason="\{Repr(error)}")
  }
  let name = decode_name(line, tokens[3])
  match tokens[2] {
    "bit_synchronizer" => parse_bit_synchronizer(reader, id, name)
    "toggle_handshake" => parse_toggle_handshake(reader, id, name)
    "async_fifo" => parse_async_fifo(reader, id, name)
    actual => raise UnexpectedLine(line~, expected="primitive kind", actual~)
  }
}

///|
fn parse_cdc_primitives(
  reader : MetadataReader,
) -> Array[@ir.CdcPrimitive] raise CodecError {
  let (line, tokens) = reader.tokens("PRIMITIVES count")
  require_token_count(line, tokens, 2, "PRIMITIVES count")
  require_keyword(line, tokens, "PRIMITIVES", "PRIMITIVES")
  let count = parse_count(line, "primitives", tokens[1])
  if count > MAX_CODEC_CDC_PRIMITIVES {
    raise InvalidCount(line~, field="primitives", value=count)
  }
  let primitives : Array[@ir.CdcPrimitive] = []
  for _ in 0..<count {
    primitives.push(parse_cdc_primitive(reader))
  }
  primitives
}

///|
fn parse_schema_four_post_ground_metadata(
  reader : MetadataReader,
  parameters : ArrayView[@ir.ModuleParameter],
) -> @ir.ModuleMetadata raise CodecError {
  let input_timings = parse_input_timings(reader)
  let output_timings = parse_output_timings(reader)
  let aggregate_bindings = parse_aggregate_bindings(reader)
  let cdc_primitives = parse_cdc_primitives(reader)
  @ir.ModuleMetadata::checked_complete(
    parameters, aggregate_bindings, input_timings, output_timings, cdc_primitives,
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
