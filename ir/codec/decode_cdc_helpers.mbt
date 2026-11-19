///|
fn parse_named_node(
  reader : MetadataReader,
  keyword : String,
  field : String,
) -> @ir.NodeId raise CodecError {
  let (line, tokens) = reader.tokens("\{keyword} node")
  require_token_count(line, tokens, 2, "\{keyword} node")
  require_keyword(line, tokens, keyword, keyword)
  parse_node_id(line, field, tokens[1])
}

///|
fn parse_named_domain(
  reader : MetadataReader,
  keyword : String,
  field : String,
) -> @ir.ClockDomainId raise CodecError {
  let (line, tokens) = reader.tokens("\{keyword} domain")
  require_token_count(line, tokens, 2, "\{keyword} domain")
  require_keyword(line, tokens, keyword, keyword)
  parse_domain_id(line, field, tokens[1])
}

///|
fn parse_named_reset(
  reader : MetadataReader,
  keyword : String,
) -> @ir.ResetSpec raise CodecError {
  let (line, tokens) = reader.tokens("\{keyword} reset contract")
  require_token_count(
    line,
    tokens,
    5,
    "\{keyword} synchronous active_high signal value",
  )
  require_keyword(line, tokens, keyword, keyword)
  if tokens[1] != "synchronous" {
    if tokens[1] == "asynchronous" {
      raise UnsupportedAsynchronousReset(line~)
    }
    raise UnexpectedLine(line~, expected="reset mode", actual=tokens[1])
  }
  if tokens[2] != "active_high" {
    if tokens[2] == "active_low" {
      raise UnsupportedResetPolarity(line~, polarity=tokens[2])
    }
    raise UnexpectedLine(line~, expected="reset polarity", actual=tokens[2])
  }
  @ir.ResetSpec::new(
    parse_node_id(line, "handshake reset signal", tokens[3]),
    parse_uint64(line, "handshake reset value", tokens[4]),
  )
}

///|
fn parse_named_stages(
  reader : MetadataReader,
  count_keyword : String,
  item_keyword : String,
  field : String,
  exact_count : Int32?,
) -> Array[@ir.NodeId] raise CodecError {
  let (line, tokens) = reader.tokens("\{count_keyword} count")
  require_token_count(line, tokens, 2, "\{count_keyword} count")
  require_keyword(line, tokens, count_keyword, count_keyword)
  let count = parse_count(line, field, tokens[1])
  if count < 2 || count > 4 {
    raise InvalidCount(line~, field~, value=count)
  }
  match exact_count {
    Some(expected) if count != expected =>
      raise UnexpectedLine(
        line~,
        expected="\{count_keyword} \{expected}",
        actual=tokens.join(" "),
      )
    _ => ()
  }
  let stages : Array[@ir.NodeId] = []
  for expected in 0..<count {
    let (stage_line, stage_tokens) = reader.tokens(
      "\{item_keyword} ordinal node",
    )
    require_token_count(
      stage_line,
      stage_tokens,
      3,
      "\{item_keyword} ordinal node",
    )
    require_keyword(stage_line, stage_tokens, item_keyword, item_keyword)
    let actual = parse_count(stage_line, "stage ordinal", stage_tokens[1])
    if actual != expected {
      raise UnexpectedLine(
        line=stage_line,
        expected="\{item_keyword} \{expected} node",
        actual=stage_tokens.join(" "),
      )
    }
    stages.push(parse_node_id(stage_line, field, stage_tokens[2]))
  }
  stages
}
