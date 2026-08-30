///|
fn parse_fifo_integer(
  reader : MetadataReader,
  keyword : String,
  field : String,
) -> Int raise CodecError {
  let (line, tokens) = reader.tokens("\{keyword} value")
  require_token_count(line, tokens, 2, "\{keyword} value")
  require_keyword(line, tokens, keyword, keyword)
  parse_int(line, field, tokens[1])
}

///|
fn parse_fifo_payload_list(
  reader : MetadataReader,
  leaf_count : Int,
) -> Array[@ir.NodeId] raise CodecError {
  let (line, tokens) = reader.tokens("SOURCE_PAYLOADS count")
  require_token_count(line, tokens, 2, "SOURCE_PAYLOADS count")
  require_keyword(line, tokens, "SOURCE_PAYLOADS", "SOURCE_PAYLOADS")
  let count = parse_count(line, "FIFO source payloads", tokens[1])
  if count != leaf_count {
    raise UnexpectedLine(
      line~,
      expected="SOURCE_PAYLOADS \{leaf_count}",
      actual=tokens.join(" "),
    )
  }
  let payloads : Array[@ir.NodeId] = []
  for expected in 0..<count {
    let (item_line, item) = reader.tokens("SOURCE_PAYLOAD ordinal node")
    require_token_count(item_line, item, 3, "SOURCE_PAYLOAD ordinal node")
    require_keyword(item_line, item, "SOURCE_PAYLOAD", "SOURCE_PAYLOAD")
    let actual = parse_count(item_line, "FIFO payload ordinal", item[1])
    if actual != expected {
      raise UnexpectedLine(
        line=item_line,
        expected="SOURCE_PAYLOAD \{expected} node",
        actual=item.join(" "),
      )
    }
    payloads.push(parse_node_id(item_line, "FIFO source payload", item[2]))
  }
  payloads
}

///|
fn parse_fifo_destination_payloads(
  reader : MetadataReader,
  leaf_count : Int,
) -> (Array[@ir.NodeId], Array[@ir.NodeId]) raise CodecError {
  let (line, tokens) = reader.tokens("DESTINATION_PAYLOADS count")
  require_token_count(line, tokens, 2, "DESTINATION_PAYLOADS count")
  require_keyword(line, tokens, "DESTINATION_PAYLOADS", "DESTINATION_PAYLOADS")
  let count = parse_count(line, "FIFO destination payloads", tokens[1])
  if count != leaf_count {
    raise UnexpectedLine(
      line~,
      expected="DESTINATION_PAYLOADS \{leaf_count}",
      actual=tokens.join(" "),
    )
  }
  let raw : Array[@ir.NodeId] = []
  let visible : Array[@ir.NodeId] = []
  for expected in 0..<count {
    let (item_line, item) = reader.tokens(
      "DESTINATION_PAYLOAD ordinal raw visible",
    )
    require_token_count(
      item_line, item, 4, "DESTINATION_PAYLOAD ordinal raw visible",
    )
    require_keyword(
      item_line, item, "DESTINATION_PAYLOAD", "DESTINATION_PAYLOAD",
    )
    let actual = parse_count(item_line, "FIFO payload ordinal", item[1])
    if actual != expected {
      raise UnexpectedLine(
        line=item_line,
        expected="DESTINATION_PAYLOAD \{expected} raw visible",
        actual=item.join(" "),
      )
    }
    raw.push(parse_node_id(item_line, "FIFO raw payload", item[2]))
    visible.push(parse_node_id(item_line, "FIFO visible payload", item[3]))
  }
  (raw, visible)
}

///|
fn parse_async_fifo(
  reader : MetadataReader,
  id : @ir.CdcPrimitiveId,
  name : String,
) -> @ir.CdcPrimitive raise CodecError {
  let source_domain = parse_named_domain(
    reader, "SOURCE_DOMAIN", "FIFO source domain",
  )
  let destination_domain = parse_named_domain(
    reader, "DESTINATION_DOMAIN", "FIFO destination domain",
  )
  let depth = parse_fifo_integer(reader, "DEPTH", "FIFO depth")
  if depth < 4 || depth > 1048576 || (depth & (depth - 1)) != 0 {
    raise InvalidCount(
      line=reader.line_number() - 1,
      field="FIFO depth",
      value=depth,
    )
  }
  let pointer_width = parse_fifo_integer(
    reader, "POINTER_WIDTH", "FIFO pointer width",
  )
  let synchronizer_stages = parse_fifo_integer(
    reader, "SYNCHRONIZER_STAGES", "FIFO synchronizer stages",
  )
  if synchronizer_stages < 2 || synchronizer_stages > 4 {
    raise InvalidCount(
      line=reader.line_number() - 1,
      field="FIFO synchronizer stages",
      value=synchronizer_stages,
    )
  }
  let (policy_line, policy_tokens) = reader.tokens("RESET_POLICY policy")
  require_token_count(policy_line, policy_tokens, 2, "RESET_POLICY policy")
  require_keyword(policy_line, policy_tokens, "RESET_POLICY", "RESET_POLICY")
  let reset_policy = match policy_tokens[1] {
    "coordinated_idle" => @ir.AsyncFifoResetPolicy::CoordinatedIdle
    actual =>
      raise UnexpectedLine(
        line=policy_line,
        expected="coordinated_idle reset policy",
        actual~,
      )
  }
  let source_reset = parse_named_reset(reader, "SOURCE_RESET")
  let destination_reset = parse_named_reset(reader, "DESTINATION_RESET")
  let (payload_shape, leaf_count) = parse_aggregate_shape(reader, 0)
  let source_valid = parse_named_node(
    reader, "SOURCE_VALID", "FIFO source valid",
  )
  let source_ready = parse_named_node(
    reader, "SOURCE_READY", "FIFO source ready",
  )
  let source_transfer = parse_named_node(
    reader, "SOURCE_TRANSFER", "FIFO source transfer",
  )
  let source_payload = parse_fifo_payload_list(reader, leaf_count)
  let destination_ready = parse_named_node(
    reader, "DESTINATION_READY", "FIFO destination ready",
  )
  let destination_valid = parse_named_node(
    reader, "DESTINATION_VALID", "FIFO destination valid",
  )
  let destination_transfer = parse_named_node(
    reader, "DESTINATION_TRANSFER", "FIFO destination transfer",
  )
  let (raw_reads, destination_payload) = parse_fifo_destination_payloads(
    reader, leaf_count,
  )
  let write_binary = parse_named_node(
    reader, "WRITE_BINARY", "FIFO write binary",
  )
  let write_binary_next = parse_named_node(
    reader, "WRITE_BINARY_NEXT", "FIFO write binary next",
  )
  let read_binary = parse_named_node(reader, "READ_BINARY", "FIFO read binary")
  let read_binary_next = parse_named_node(
    reader, "READ_BINARY_NEXT", "FIFO read binary next",
  )
  let write_gray = parse_named_node(reader, "WRITE_GRAY", "FIFO write Gray")
  let write_gray_next = parse_named_node(
    reader, "WRITE_GRAY_NEXT", "FIFO write Gray next",
  )
  let read_gray = parse_named_node(reader, "READ_GRAY", "FIFO read Gray")
  let read_gray_next = parse_named_node(
    reader, "READ_GRAY_NEXT", "FIFO read Gray next",
  )
  let read_gray_stages = parse_named_stages(
    reader,
    "READ_GRAY_STAGES",
    "READ_GRAY_STAGE",
    "FIFO read Gray stage",
    Some(synchronizer_stages),
  )
  let write_gray_stages = parse_named_stages(
    reader,
    "WRITE_GRAY_STAGES",
    "WRITE_GRAY_STAGE",
    "FIFO write Gray stage",
    Some(synchronizer_stages),
  )
  let full = parse_named_node(reader, "FULL", "FIFO full")
  let full_next = parse_named_node(reader, "FULL_NEXT", "FIFO full next")
  let nonempty = parse_named_node(reader, "NONEMPTY", "FIFO nonempty")
  let nonempty_next = parse_named_node(
    reader, "NONEMPTY_NEXT", "FIFO nonempty next",
  )
  let write_address = parse_named_node(
    reader, "WRITE_ADDRESS", "FIFO write address",
  )
  let read_address = parse_named_node(
    reader, "READ_ADDRESS", "FIFO read address",
  )
  let end_line = reader.line_number()
  let end = reader.next("ENDPRIMITIVE")
  if end != "ENDPRIMITIVE" {
    raise UnexpectedLine(line=end_line, expected="ENDPRIMITIVE", actual=end)
  }
  let spec = @ir.AsyncFifoPrimitive::checked(
    id, name, source_domain, destination_domain, depth, pointer_width, synchronizer_stages,
    reset_policy, source_reset, destination_reset, payload_shape, source_valid, source_ready,
    source_transfer, source_payload, destination_ready, destination_valid, destination_transfer,
    raw_reads, destination_payload, write_binary, write_binary_next, read_binary,
    read_binary_next, write_gray, write_gray_next, read_gray, read_gray_next, read_gray_stages,
    write_gray_stages, full, full_next, nonempty, nonempty_next, write_address, read_address,
  ) catch {
    error => raise IrRejected(reason="\{Repr(error)}")
  }
  AsyncFifo(spec)
}

///|
