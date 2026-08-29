///|
const TRACE_SOURCE_MAP_SCHEMA_VERSION : Int = 1

///|
fn source_segment_parts(
  segment : @diagnostics.SemanticPathSegment,
) -> (String, String) {
  match segment {
    Design(value) => ("design", encode_text(value))
    Module(value) => ("module", encode_text(value))
    Instance(value) => ("instance", encode_text(value))
    Port(value) => ("port", encode_text(value))
    Node(id) => ("node", id.to_string())
    Field(value) => ("field", encode_text(value))
    Operation(value) => ("operation", encode_text(value))
  }
}

///|
fn write_source_span(
  builder : StringBuilder,
  span : @diagnostics.SourceSpan,
) -> Unit {
  let start = span.start()
  let end = span.end()
  builder.write_string(
    "SPAN \{encode_text(span.source_id())} \{start.line()} \{start.column()} \{start.byte_offset()} \{end.line()} \{end.column()} \{end.byte_offset()}\n",
  )
}

///|
/// Serialize a trace source map as canonical schema-version-1 text.
///
/// The `VCD` field is the stable manifest key that joins each source entry to
/// the identifier emitted by `to_vcd`, without changing trace or VCD bytes.
pub fn serialize_source_map(source_map : TraceSourceMap) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "LUNACHIP-TRACE-SOURCE-MAP \{TRACE_SOURCE_MAP_SCHEMA_VERSION}\n",
  )
  builder.write_string("ENTRIES \{source_map.entries().length()}\n")
  for entry in source_map.entries() {
    let signal = entry.signal()
    let segments = entry.semantic_path().segments()
    let span_tag = if entry.source_span() is Some(_) { "span" } else { "none" }
    builder.write_string(
      "ENTRY \{entry.signal_index()} \{signal.width()} \{encode_text(signal.path())} \{encode_text(signal.name())} \{segments.length()} \{span_tag}\n",
    )
    builder.write_string("VCD \{entry.vcd_identifier()}\n")
    for segment in segments {
      let (kind, value) = source_segment_parts(segment)
      builder.write_string("SEGMENT \{kind} \{value}\n")
    }
    match entry.source_span() {
      Some(span) => write_source_span(builder, span)
      None => ()
    }
  }
  builder.write_string("END\n")
  builder.to_string()
}

///|
fn parse_source_segment(
  line : Int,
  kind : String,
  value : String,
) -> @diagnostics.SemanticPathSegment raise TraceError {
  match kind {
    "design" => Design(decode_text(line, value))
    "module" => Module(decode_text(line, value))
    "instance" => Instance(decode_text(line, value))
    "port" => Port(decode_text(line, value))
    "node" => Node(trace_parse_int(line, "semantic node", value))
    "field" => Field(decode_text(line, value))
    "operation" => Operation(decode_text(line, value))
    _ =>
      raise UnexpectedLine(line~, expected="semantic path segment", actual=kind)
  }
}

///|
fn checked_semantic_path(
  line : Int,
  segments : ArrayView[@diagnostics.SemanticPathSegment],
) -> @diagnostics.SemanticPath raise TraceError {
  @diagnostics.SemanticPath::checked(segments) catch {
    _ => raise InvalidSourceMetadata(line~, field="semantic path")
  }
}

///|
fn checked_position(
  line : Int,
  field : String,
  position_line : String,
  column : String,
  byte_offset : String,
) -> @diagnostics.SourcePosition raise TraceError {
  let parsed_line = trace_parse_int(line, "\{field} line", position_line)
  let parsed_column = trace_parse_int(line, "\{field} column", column)
  let parsed_offset = trace_parse_int(line, "\{field} byte offset", byte_offset)
  @diagnostics.SourcePosition::new(parsed_line, parsed_column, parsed_offset) catch {
    _ => raise InvalidSourceMetadata(line~, field~)
  }
}

///|
fn parse_source_span(
  reader : TraceReader,
) -> @diagnostics.SourceSpan raise TraceError {
  let (line, tokens) = reader.tokens("SPAN")
  require_line(
    line, tokens, "SPAN", 8, "SPAN source start-line start-column start-byte end-line end-column end-byte",
  )
  let source_id = decode_text(line, tokens[1])
  let start = checked_position(line, "start", tokens[2], tokens[3], tokens[4])
  let end = checked_position(line, "end", tokens[5], tokens[6], tokens[7])
  @diagnostics.SourceSpan::new(source_id, start, end) catch {
    _ => raise InvalidSourceMetadata(line~, field="source span")
  }
}

///|
fn parse_source_entry(
  reader : TraceReader,
  expected_index : Int,
  previous_signal : TraceSignal?,
) -> TraceSourceEntry raise TraceError {
  let (line, tokens) = reader.tokens("ENTRY")
  require_line(
    line, tokens, "ENTRY", 7, "ENTRY index width path name segments span-mode",
  )
  let index = trace_parse_int(line, "signal index", tokens[1])
  if index != expected_index {
    raise UnexpectedLine(
      line~,
      expected="ENTRY \{expected_index}",
      actual=tokens.join(" "),
    )
  }
  let signal = TraceSignal::checked(
    decode_text(line, tokens[3]),
    decode_text(line, tokens[4]),
    trace_parse_int(line, "width", tokens[2]),
  )
  match previous_signal {
    Some(previous) if compare_signal(previous, signal) >= 0 =>
      raise NonCanonical
    _ => ()
  }
  let segment_count = trace_parse_int(line, "segment count", tokens[5])
  if segment_count < 0 {
    raise UnexpectedLine(
      line~,
      expected="nonnegative segment count",
      actual=tokens[5],
    )
  }
  let (vcd_line, vcd_tokens) = reader.tokens("VCD")
  require_line(vcd_line, vcd_tokens, "VCD", 2, "VCD identifier")
  if vcd_tokens[1] != vcd_identifier(index) {
    raise InvalidVcdIdentifier(index~, actual=vcd_tokens[1])
  }
  let segments : Array[@diagnostics.SemanticPathSegment] = []
  for _ in 0..<segment_count {
    let (segment_line, segment_tokens) = reader.tokens("SEGMENT")
    require_line(
      segment_line, segment_tokens, "SEGMENT", 3, "SEGMENT kind value",
    )
    segments.push(
      parse_source_segment(segment_line, segment_tokens[1], segment_tokens[2]),
    )
  }
  let source_span = match tokens[6] {
    "none" => None
    "span" => Some(parse_source_span(reader))
    actual => raise UnexpectedLine(line~, expected="span mode", actual~)
  }
  {
    signal_index: index,
    signal,
    semantic_path: checked_semantic_path(line, segments),
    source_span,
  }
}

///|
/// Parse strict canonical schema-version-1 trace source-map text.
pub fn parse_source_map(source : String) -> TraceSourceMap raise TraceError {
  if !source.has_suffix("\n") {
    raise NonCanonical
  }
  let reader : TraceReader = {
    lines: source.split("\n").map(part => part.to_owned()).to_array(),
    cursor: 0,
  }
  let (header_line, header) = reader.tokens("LUNACHIP-TRACE-SOURCE-MAP version")
  require_line(
    header_line, header, "LUNACHIP-TRACE-SOURCE-MAP", 2, "LUNACHIP-TRACE-SOURCE-MAP version",
  )
  if header[1] != "1" {
    raise UnsupportedVersion(header[1])
  }
  let (entries_line, entries_header) = reader.tokens("ENTRIES count")
  require_line(entries_line, entries_header, "ENTRIES", 2, "ENTRIES count")
  let count = trace_parse_int(entries_line, "entry count", entries_header[1])
  if count < 0 {
    raise UnexpectedLine(
      line=entries_line,
      expected="nonnegative entry count",
      actual=entries_header[1],
    )
  }
  let entries : Array[TraceSourceEntry] = []
  for index in 0..<count {
    let previous = if index == 0 {
      None
    } else {
      Some(entries[index - 1].signal())
    }
    entries.push(parse_source_entry(reader, index, previous))
  }
  let (end_line, end_tokens) = reader.tokens("END")
  require_line(end_line, end_tokens, "END", 1, "END")
  if reader.cursor != reader.lines.length() - 1 {
    raise NonCanonical
  }
  let source_map : TraceSourceMap = {
    entries: ReadOnlyArray::from_array(entries),
  }
  if serialize_source_map(source_map) != source {
    raise NonCanonical
  }
  source_map
}
