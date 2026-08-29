///|
fn parse_memory_id(
  line : Int,
  field : String,
  value : String,
) -> @ir.MemoryId raise CodecError {
  @ir.MemoryId::new(parse_int(line, field, value)) catch {
    error => raise IrRejected(reason="\{Repr(error)}")
  }
}

///|
fn parse_read_port_id(
  line : Int,
  value : String,
) -> @ir.MemoryReadPortId raise CodecError {
  @ir.MemoryReadPortId::new(parse_int(line, "read port id", value)) catch {
    error => raise IrRejected(reason="\{Repr(error)}")
  }
}

///|
fn parse_write_port_id(
  line : Int,
  value : String,
) -> @ir.MemoryWritePortId raise CodecError {
  @ir.MemoryWritePortId::new(parse_int(line, "write port id", value)) catch {
    error => raise IrRejected(reason="\{Repr(error)}")
  }
}

///|
fn parse_memory_depth(
  line : Int,
  value : String,
) -> @ir.MemoryDepth raise CodecError {
  @ir.MemoryDepth::new(parse_int(line, "memory depth", value)) catch {
    error => raise IrRejected(reason="\{Repr(error)}")
  }
}

///|
fn parse_optional_node(
  line : Int,
  field : String,
  value : String,
) -> @ir.NodeId? raise CodecError {
  if value == "-" {
    None
  } else {
    Some(parse_node_id(line, field, value))
  }
}

///|
fn parse_rising_domain(
  line : Int,
  clock : String,
  edge : String,
) -> @ir.ClockDomain raise CodecError {
  if edge != "rising" {
    raise UnexpectedLine(line~, expected="rising clock edge", actual=edge)
  }
  @ir.ClockDomain::rising(parse_node_id(line, "clock", clock))
}

///|
fn parse_read_write_policy(
  line : Int,
  encoded : String,
) -> @ir.MemoryReadWritePolicy raise CodecError {
  match encoded {
    "read_old" => ReadOld
    "read_new" => ReadNew
    "no_change" => NoChange
    "undefined" => Undefined
    "reject" => Reject
    _ =>
      raise UnexpectedLine(
        line~,
        expected="memory read/write policy",
        actual=encoded,
      )
  }
}

///|
fn parse_multi_write_policy(
  line : Int,
  encoded : String,
) -> @ir.MemoryMultiWritePolicy raise CodecError {
  match encoded {
    "reject" => Reject
    "lower_port_id_wins" => LowerPortIdWins
    _ =>
      raise UnexpectedLine(
        line~,
        expected="memory multi-write policy",
        actual=encoded,
      )
  }
}

///|
fn parse_bounds_policy(
  line : Int,
  encoded : String,
) -> @ir.MemoryBoundsPolicy raise CodecError {
  match encoded {
    "fault" => Fault
    "undefined" => Undefined
    _ =>
      raise UnexpectedLine(
        line~,
        expected="memory bounds policy",
        actual=encoded,
      )
  }
}

///|
fn parse_read_enable_behavior(
  line : Int,
  encoded : String,
) -> @ir.MemoryReadEnableBehavior raise CodecError {
  match encoded {
    "hold_last" => HoldLast
    "undefined" => Undefined
    _ =>
      raise UnexpectedLine(
        line~,
        expected="memory read-enable behavior",
        actual=encoded,
      )
  }
}

///|
fn parse_read_port(reader : Reader) -> @ir.MemoryReadPort raise CodecError {
  let (line, tokens) = reader.tokens("READ")
  require_token_count(
    line, tokens, 10, "READ id name clock rising address enable one behavior result",
  )
  require_keyword(line, tokens, "READ", "READ")
  if tokens[7] != "one" {
    raise UnexpectedLine(
      line~,
      expected="one-cycle memory read latency",
      actual=tokens[7],
    )
  }
  @ir.MemoryReadPort::new(
    parse_read_port_id(line, tokens[1]),
    decode_name(line, tokens[2]),
    parse_rising_domain(line, tokens[3], tokens[4]),
    parse_node_id(line, "read address", tokens[5]),
    enable?=parse_optional_node(line, "read enable", tokens[6]),
    OneCycle,
    parse_read_enable_behavior(line, tokens[8]),
    parse_node_id(line, "read result", tokens[9]),
  )
}

///|
fn parse_write_port(reader : Reader) -> @ir.MemoryWritePort raise CodecError {
  let (line, tokens) = reader.tokens("WRITE")
  if tokens.length() != 9 && tokens.length() != 11 {
    raise UnexpectedLine(
      line~,
      expected="WRITE id name clock rising address data enable all|granular mask granularity",
      actual=tokens.join(" "),
    )
  }
  require_keyword(line, tokens, "WRITE", "WRITE")
  let mask = match tokens[8] {
    "all" => {
      require_token_count(
        line, tokens, 9, "WRITE id name clock rising address data enable all",
      )
      @ir.MemoryWriteMask::All
    }
    "granular" => {
      require_token_count(
        line, tokens, 11, "WRITE id name clock rising address data enable granular mask granularity",
      )
      let width = @ir.Width::new(
        parse_int(line, "mask granularity", tokens[10]),
      ) catch {
        error => raise IrRejected(reason="\{Repr(error)}")
      }
      Granular(
        signal=parse_node_id(line, "write mask", tokens[9]),
        granularity=width,
      )
    }
    encoded =>
      raise UnexpectedLine(line~, expected="memory write mask", actual=encoded)
  }
  @ir.MemoryWritePort::new(
    parse_write_port_id(line, tokens[1]),
    decode_name(line, tokens[2]),
    parse_rising_domain(line, tokens[3], tokens[4]),
    parse_node_id(line, "write address", tokens[5]),
    parse_node_id(line, "write data", tokens[6]),
    enable?=parse_optional_node(line, "write enable", tokens[7]),
    mask,
  )
}

///|
fn parse_memory(reader : Reader) -> @ir.MemorySpec raise CodecError {
  let (line, tokens) = reader.tokens("MEMORY")
  require_token_count(
    line, tokens, 10, "MEMORY id name type depth clock rising read-write multi-write bounds",
  )
  require_keyword(line, tokens, "MEMORY", "MEMORY")
  let id = parse_memory_id(line, "memory id", tokens[1])
  let name = decode_name(line, tokens[2])
  let element_type = parse_type(line, tokens[3])
  let depth = parse_memory_depth(line, tokens[4])
  let domain = parse_rising_domain(line, tokens[5], tokens[6])
  let read_write_policy = parse_read_write_policy(line, tokens[7])
  let multi_write_policy = parse_multi_write_policy(line, tokens[8])
  let bounds_policy = parse_bounds_policy(line, tokens[9])
  let (reads_line, reads_tokens) = reader.tokens("READS count")
  require_token_count(reads_line, reads_tokens, 2, "READS count")
  require_keyword(reads_line, reads_tokens, "READS", "READS")
  let read_count = parse_count(reads_line, "reads", reads_tokens[1])
  let reads : Array[@ir.MemoryReadPort] = []
  for _ in 0..<read_count {
    reads.push(parse_read_port(reader))
  }
  let (writes_line, writes_tokens) = reader.tokens("WRITES count")
  require_token_count(writes_line, writes_tokens, 2, "WRITES count")
  require_keyword(writes_line, writes_tokens, "WRITES", "WRITES")
  let write_count = parse_count(writes_line, "writes", writes_tokens[1])
  let writes : Array[@ir.MemoryWritePort] = []
  for _ in 0..<write_count {
    writes.push(parse_write_port(reader))
  }
  let end_line = reader.line_number()
  let end_memory = reader.next("ENDMEMORY")
  if end_memory != "ENDMEMORY" {
    raise UnexpectedLine(line=end_line, expected="ENDMEMORY", actual=end_memory)
  }
  @ir.MemorySpec::new(
    id, name, element_type, depth, domain, reads, writes, read_write_policy, multi_write_policy,
    bounds_policy,
  )
}
