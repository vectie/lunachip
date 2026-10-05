///|
fn tsv_cells(line : String) -> Array[String] {
  line.split("\t").map(cell => cell.to_owned()).to_array()
}

///|
fn tsv_hex_nibble(symbol : UInt16) -> Int? {
  if symbol >= '0' && symbol <= '9' {
    Some(symbol.to_int() - '0'.to_int())
  } else if symbol >= 'a' && symbol <= 'f' {
    Some(symbol.to_int() - 'a'.to_int() + 10)
  } else {
    None
  }
}

///|
fn decode_tsv_utf8_hex(text : String, row : Int) -> String raise Phase3Error {
  if text.length() == 0 || text.length() % 2 != 0 {
    raise InvalidResultTsv(reason="invalid semantic UTF-8 hex", row~)
  }
  let bytes : Array[Byte] = []
  for index in 0..<(text.length() / 2) {
    guard tsv_hex_nibble(text[index * 2]) is Some(high) else {
      raise InvalidResultTsv(reason="invalid semantic UTF-8 hex", row~)
    }
    guard tsv_hex_nibble(text[index * 2 + 1]) is Some(low) else {
      raise InvalidResultTsv(reason="invalid semantic UTF-8 hex", row~)
    }
    bytes.push(((high << 4) | low).to_byte())
  }
  @utf8.decode(Bytes::from_array(bytes)) catch {
    _ => raise InvalidResultTsv(reason="invalid semantic UTF-8", row~)
  }
}

///|
fn parse_tsv_cycle(text : String, row : Int) -> UInt64 raise Phase3Error {
  if text.length() == 0 || (text.length() > 1 && text[0] == '0') {
    raise InvalidResultTsv(reason="non-canonical cycle", row~)
  }
  @string.parse_uint64(text) catch {
    _ => raise InvalidResultTsv(reason="invalid cycle", row~)
  }
}

///|
fn parse_tsv_hex(
  text : String,
  width : Int,
  row : Int,
) -> UInt64 raise Phase3Error {
  if text.length() != (width + 3) / 4 {
    raise InvalidResultTsv(reason="wrong value width", row~)
  }
  let mut value = 0UL
  for symbol in text {
    let nibble = if symbol >= '0' && symbol <= '9' {
      symbol.to_int() - '0'.to_int()
    } else if symbol >= 'a' && symbol <= 'f' {
      symbol.to_int() - 'a'.to_int() + 10
    } else {
      raise InvalidResultTsv(reason="non-canonical hexadecimal value", row~)
    }
    value = (value << 4) | nibble.to_uint64()
  }
  if width < 64 && value >> width != 0UL {
    raise InvalidResultTsv(reason="nonzero unused high bits", row~)
  }
  value
}

///|
/// Parse an independently produced TSV result, including the identity embedded
/// by the compiled harness. No identity is borrowed from the expected result.
pub fn FixtureBundle::parse_actual_tsv(
  self : FixtureBundle,
  source : String,
) -> @differential.ObservationSet raise {
  if !source.has_suffix("\n") {
    raise InvalidResultTsv(reason="missing final newline", row=0)
  }
  let lines = source.split("\n").map(line => line.to_owned()).to_array()
  if lines.length() < 3 || lines[lines.length() - 1] != "" {
    raise InvalidResultTsv(reason="truncated result", row=0)
  }
  let identity_cells = tsv_cells(lines[0])
  if identity_cells.length() != 7 ||
    identity_cells[0] != "LUNACHIP-PHASE3-RESULT" ||
    identity_cells[1] != "1" ||
    identity_cells[3] != "sha256" ||
    identity_cells[5] != "sha256" {
    raise InvalidResultTsv(reason="invalid identity header", row=1)
  }
  let design_identity = @differential.DesignIdentity::checked(
    decode_tsv_utf8_hex(identity_cells[2], 1),
    identity_cells[4],
  )
  let result_identity = @differential.ResultIdentity::checked(
    design_identity,
    identity_cells[6],
  )
  let outputs = output_ports(self.ports)
  if lines[1] + "\n" != tsv_header(outputs) {
    raise InvalidResultTsv(reason="invalid port header", row=2)
  }
  if lines.length() != self.plan.post_reset_cycles + 3 {
    raise InvalidResultTsv(reason="wrong result row count", row=0)
  }
  let observations : Array[@differential.Observation] = []
  for index in 0..<self.plan.post_reset_cycles {
    let row_number = index + 3
    let cells = tsv_cells(lines[index + 2])
    if cells.length() != outputs.length() + 1 {
      raise InvalidResultTsv(reason="wrong column count", row=row_number)
    }
    let expected_cycle = (index + 1).to_uint64()
    let cycle = parse_tsv_cycle(cells[0], row_number)
    if cycle != expected_cycle {
      raise InvalidResultTsv(reason="non-contiguous cycle", row=row_number)
    }
    let event = cycle * 3UL + 2UL
    for output_index, output in outputs {
      let value = parse_tsv_hex(
        cells[output_index + 1],
        output.width,
        row_number,
      )
      observations.push(
        @differential.Observation::checked(
          event,
          cycle,
          PostEdge,
          output.source_name,
          normalized_known(output.width, value),
        ),
      )
    }
  }
  @differential.ObservationSet::checked(result_identity, observations)
}

///|
pub fn FixtureBundle::compare_actual_tsv(
  self : FixtureBundle,
  source : String,
) -> @differential.Comparison raise {
  self.compare_actual(self.parse_actual_tsv(source))
}
