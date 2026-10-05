///|
const TRACE_SCHEMA_VERSION : Int = 1

///|
const ATOMIC_TRACE_SCHEMA_VERSION : Int = 2

///|
fn encode_text(value : String) -> String {
  let bytes = @utf8.encode(value)
  if bytes.length() == 0 {
    return "-"
  }
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
fn event_parts(event : TraceEvent) -> (String, String) {
  match event {
    Initial => ("initial", "-")
    Settled => ("settled", "-")
    InputDriven(name) => ("input", encode_text(name))
    RisingEdge(name) => ("edge", encode_text(name))
    Marker(label) => ("marker", encode_text(label))
  }
}

///|
/// Serialize a trace to canonical schema-version-1 native text.
fn serialize_schema1(trace : Trace) -> String {
  let builder = StringBuilder()
  builder.write_string("LUNACHIP-TRACE \{TRACE_SCHEMA_VERSION}\n")
  builder.write_string("SIGNALS \{trace.signals().length()}\n")
  for index, signal in trace.signals() {
    builder.write_string(
      "SIGNAL \{index} \{signal.width()} \{encode_text(signal.path())} \{encode_text(signal.name())}\n",
    )
  }
  builder.write_string("FRAMES \{trace.frames().length()}\n")
  for frame in trace.frames() {
    let (tag, argument) = event_parts(frame.event())
    builder.write_string(
      "FRAME \{frame.cycle()} \{frame.boundary()} \{tag} \{argument} \{frame.changes().length()}\n",
    )
    for change in frame.changes() {
      let value = change.value()
      builder.write_string(
        "CHANGE \{change.signal_index()} \{value.value_bits()} \{value.known_mask()}\n",
      )
    }
  }
  builder.write_string("END\n")
  builder.to_string()
}

///|
fn atomic_event_parts(event : AtomicTraceEvent) -> (String, String) {
  match event {
    AtomicInitial => ("initial", "-")
    AtomicBatch => ("batch", "-")
    AtomicMarker(label) => ("marker", encode_text(label))
    Legacy(old) => {
      let (tag, argument) = event_parts(old)
      ("legacy_" + tag, argument)
    }
  }
}

///|
fn serialize_schema2(trace : Trace) -> String {
  let builder = StringBuilder()
  builder.write_string("LUNACHIP-TRACE \{ATOMIC_TRACE_SCHEMA_VERSION}\n")
  let semantic_version = match trace.semantic_version() {
    Some(value) => value
    None => abort("validated schema-2 trace lacks semantic version")
  }
  let digest = match trace.ir_digest() {
    Some(value) => value
    None => abort("validated schema-2 trace lacks IR digest")
  }
  let timebase = match trace.timebase() {
    Some(value) => value
    None => abort("validated schema-2 trace lacks timebase")
  }
  builder.write_string("SEMANTICS \{encode_text(semantic_version)}\n")
  builder.write_string("IR \{digest.algorithm()} \{digest.hex()}\n")
  builder.write_string("TIMEBASE \{timebase}\n")
  builder.write_string("DOMAINS \{trace.domains().length()}\n")
  for domain in trace.domains() {
    builder.write_string(
      "DOMAIN \{domain.id()} \{encode_text(domain.clock())}\n",
    )
  }
  builder.write_string("SIGNALS \{trace.signals().length()}\n")
  for index, signal in trace.signals() {
    builder.write_string(
      "SIGNAL \{index} \{signal.width()} \{encode_text(signal.path())} \{encode_text(signal.name())}\n",
    )
  }
  builder.write_string("FRAMES \{trace.atomic_frames().length()}\n")
  let totals = try! atomic_trace_totals(trace.atomic_frames())
  builder.write_string(
    "TOTALS \{totals.drives} \{totals.domains} \{totals.changes}\n",
  )
  for frame in trace.atomic_frames() {
    let (tag, argument) = atomic_event_parts(frame.event())
    builder.write_string(
      "FRAME \{frame.time()} \{frame.boundary()} \{tag} \{argument} \{frame.drives().length()} \{frame.active_domains().length()} \{frame.changes().length()}\n",
    )
    for drive in frame.drives() {
      builder.write_string("DRIVE \{encode_text(drive)}\n")
    }
    for domain in frame.active_domains() {
      builder.write_string("ACTIVE \{domain}\n")
    }
    for change in frame.changes() {
      let value = change.value()
      builder.write_string(
        "CHANGE \{change.signal_index()} \{value.value_bits()} \{value.known_mask()}\n",
      )
    }
  }
  builder.write_string("END\n")
  builder.to_string()
}

///|
/// Serialize a canonical schema-1 or schema-2 trace.
pub fn serialize(trace : Trace) -> String {
  match trace.schema() {
    Legacy1 => serialize_schema1(trace)
    Atomic2 => serialize_schema2(trace)
  }
}

///|
priv struct TraceReader {
  lines : Array[String]
  mut cursor : Int
}

///|
fn TraceReader::next(
  self : TraceReader,
  expected : String,
) -> (Int, String) raise TraceError {
  if self.cursor >= self.lines.length() - 1 {
    raise UnexpectedEnd(expected~)
  }
  let line_number = self.cursor + 1
  let line = self.lines[self.cursor]
  self.cursor += 1
  (line_number, line)
}

///|
fn TraceReader::tokens(
  self : TraceReader,
  expected : String,
) -> (Int, Array[String]) raise TraceError {
  let (line, text) = self.next(expected)
  (line, text.split(" ").map(part => part.to_owned()).to_array())
}

///|
fn require_line(
  line : Int,
  tokens : ArrayView[String],
  keyword : String,
  count : Int,
  expected : String,
) -> Unit raise TraceError {
  if tokens.length() != count || tokens[0] != keyword {
    raise UnexpectedLine(line~, expected~, actual=tokens.join(" "))
  }
}

///|
fn trace_parse_int(
  line : Int,
  field : String,
  value : String,
) -> Int raise TraceError {
  @string.parse_int(value) catch {
    _ => raise InvalidInteger(line~, field~, value~)
  }
}

///|
fn trace_parse_uint64(
  line : Int,
  field : String,
  value : String,
) -> UInt64 raise TraceError {
  @string.parse_uint64(value) catch {
    _ => raise InvalidInteger(line~, field~, value~)
  }
}

///|
fn trace_hex_nibble(code : UInt16) -> Int? {
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
fn decode_text(line : Int, encoded : String) -> String raise TraceError {
  if encoded == "-" {
    return ""
  }
  if encoded.length() == 0 || encoded.length() % 2 != 0 {
    raise InvalidEncodedText(line~, value=encoded)
  }
  let bytes : Array[Byte] = []
  for index in 0..<(encoded.length() / 2) {
    guard trace_hex_nibble(encoded[index * 2]) is Some(high) else {
      raise InvalidEncodedText(line~, value=encoded)
    }
    guard trace_hex_nibble(encoded[index * 2 + 1]) is Some(low) else {
      raise InvalidEncodedText(line~, value=encoded)
    }
    bytes.push(((high << 4) | low).to_byte())
  }
  @utf8.decode(Bytes::from_array(bytes)) catch {
    _ => raise InvalidUtf8Text(line~)
  }
}

///|
fn parse_event(
  line : Int,
  tag : String,
  argument : String,
) -> TraceEvent raise TraceError {
  match tag {
    "initial" => {
      if argument != "-" {
        raise UnexpectedLine(line~, expected="initial -", actual=argument)
      }
      Initial
    }
    "settled" => {
      if argument != "-" {
        raise UnexpectedLine(line~, expected="settled -", actual=argument)
      }
      Settled
    }
    "input" => InputDriven(decode_text(line, argument))
    "edge" => RisingEdge(decode_text(line, argument))
    "marker" => Marker(decode_text(line, argument))
    _ => raise UnexpectedLine(line~, expected="trace event", actual=tag)
  }
}

///|
fn parse_signal_table(
  reader : TraceReader,
  count : Int,
) -> Array[TraceSignal] raise TraceError {
  let signals : Array[TraceSignal] = []
  for expected_index in 0..<count {
    let (line, tokens) = reader.tokens("SIGNAL")
    require_line(line, tokens, "SIGNAL", 5, "SIGNAL index width path name")
    let index = trace_parse_int(line, "signal index", tokens[1])
    if index != expected_index {
      raise UnexpectedLine(
        line~,
        expected="SIGNAL \{expected_index}",
        actual=tokens.join(" "),
      )
    }
    let signal = TraceSignal::checked(
      decode_text(line, tokens[3]),
      decode_text(line, tokens[4]),
      trace_parse_int(line, "width", tokens[2]),
    )
    if expected_index > 0 &&
      compare_signal(signals[expected_index - 1], signal) >= 0 {
      raise NonCanonical
    }
    signals.push(signal)
  }
  signals
}

///|
fn parse_changes(
  reader : TraceReader,
  signals : ArrayView[TraceSignal],
  count : Int,
) -> Array[TraceChange] raise TraceError {
  let changes : Array[TraceChange] = []
  let mut previous_index = -1
  for _ in 0..<count {
    let (line, tokens) = reader.tokens("CHANGE")
    require_line(line, tokens, "CHANGE", 4, "CHANGE signal value known")
    let index = trace_parse_int(line, "signal index", tokens[1])
    if index <= previous_index || index < 0 || index >= signals.length() {
      raise UnexpectedLine(
        line~,
        expected="ordered signal index",
        actual=tokens[1],
      )
    }
    let signal = signals[index]
    let value = @wave.LogicValue::from_masks(
      width=signal.width(),
      value_bits=trace_parse_uint64(line, "value bits", tokens[2]),
      known_mask=trace_parse_uint64(line, "known mask", tokens[3]),
    ) catch {
      _ =>
        raise UnexpectedLine(
          line~,
          expected="width-bounded logic value",
          actual=tokens.join(" "),
        )
    }
    changes.push({ signal_index: index, value, })
    previous_index = index
  }
  changes
}

///|
fn parse_frames(
  reader : TraceReader,
  signals : ArrayView[TraceSignal],
  count : Int,
) -> Array[TraceFrame] raise TraceError {
  let frames : Array[TraceFrame] = []
  let previous : Array[@wave.LogicValue?] = Array::make(signals.length(), None)
  let mut last_cycle : UInt64? = None
  let mut last_boundary : UInt64? = None
  for frame_index in 0..<count {
    let (line, tokens) = reader.tokens("FRAME")
    require_line(
      line, tokens, "FRAME", 6, "FRAME cycle boundary event argument changes",
    )
    let cycle = trace_parse_uint64(line, "cycle", tokens[1])
    let boundary = trace_parse_uint64(line, "boundary", tokens[2])
    match (last_cycle, last_boundary) {
      (Some(old_cycle), Some(old_boundary)) =>
        if cycle < old_cycle || (cycle == old_cycle && boundary <= old_boundary) {
          raise NonMonotonicBoundary
        }
      _ => ()
    }
    let change_count = trace_parse_int(line, "change count", tokens[5])
    if change_count < 0 || change_count > signals.length() {
      raise UnexpectedLine(
        line~,
        expected="valid change count",
        actual=tokens[5],
      )
    }
    if frame_index == 0 && change_count != signals.length() {
      raise UnexpectedLine(
        line~,
        expected="complete first frame",
        actual=tokens[5],
      )
    }
    let changes = parse_changes(reader, signals, change_count)
    for change in changes {
      let index = change.signal_index()
      if previous[index] == Some(change.value()) {
        raise NonCanonical
      }
      previous[index] = Some(change.value())
    }
    frames.push({
      cycle,
      boundary,
      event: parse_event(line, tokens[3], tokens[4]),
      changes: ReadOnlyArray::from_array(changes),
    })
    last_cycle = Some(cycle)
    last_boundary = Some(boundary)
  }
  frames
}

///|
fn parse_atomic_event(
  line : Int,
  tag : String,
  argument : String,
) -> AtomicTraceEvent raise TraceError {
  match tag {
    "initial" => {
      if argument != "-" {
        raise UnexpectedLine(line~, expected="initial -", actual=argument)
      }
      AtomicInitial
    }
    "batch" => {
      if argument != "-" {
        raise UnexpectedLine(line~, expected="batch -", actual=argument)
      }
      AtomicBatch
    }
    "marker" => AtomicMarker(decode_text(line, argument))
    _ =>
      if tag.has_prefix("legacy_") {
        Legacy(parse_event(line, tag[7:].to_owned(), argument))
      } else {
        raise UnexpectedLine(line~, expected="atomic trace event", actual=tag)
      }
  }
}

///|
fn parse_domain_table(
  reader : TraceReader,
  count : Int,
) -> Array[TraceDomain] raise TraceError {
  require_trace_limit("domains", count, MAX_TRACE_DOMAINS)
  let domains : Array[TraceDomain] = []
  for _ in 0..<count {
    let (line, tokens) = reader.tokens("DOMAIN")
    require_line(line, tokens, "DOMAIN", 3, "DOMAIN id clock")
    domains.push(
      TraceDomain::checked(
        trace_parse_int(line, "domain ID", tokens[1]),
        decode_text(line, tokens[2]),
      ),
    )
  }
  domains
}

///|
fn parse_atomic_frames(
  reader : TraceReader,
  signals : ArrayView[TraceSignal],
  count : Int,
  expected_totals : AtomicTraceTotals,
) -> Array[AtomicTraceFrame] raise TraceError {
  require_trace_limit("frames", count, MAX_TRACE_FRAMES)
  let frames : Array[AtomicTraceFrame] = []
  let mut drives_total = 0
  let mut domains_total = 0
  let mut changes_total = 0
  let mut members_total = 0
  for _ in 0..<count {
    let (line, tokens) = reader.tokens("FRAME")
    require_line(
      line, tokens, "FRAME", 8, "FRAME time boundary event argument drives domains changes",
    )
    let drive_count = trace_parse_int(line, "drive count", tokens[5])
    let domain_count = trace_parse_int(line, "domain count", tokens[6])
    let change_count = trace_parse_int(line, "change count", tokens[7])
    if drive_count < 0 || domain_count < 0 || change_count < 0 {
      raise UnexpectedLine(
        line~,
        expected="nonnegative frame counts",
        actual="\{tokens[5]} \{tokens[6]} \{tokens[7]}",
      )
    }
    require_trace_limit("frame drives", drive_count, MAX_TRACE_EVENT_MEMBERS)
    require_trace_limit("frame domains", domain_count, MAX_TRACE_EVENT_MEMBERS)
    if change_count > signals.length() {
      raise TraceResourceLimitExceeded(
        kind="frame changes",
        maximum=signals.length(),
        actual=change_count,
      )
    }
    members_total = add_trace_total(
      "total event members",
      members_total,
      drive_count,
      MAX_TRACE_TOTAL_EVENT_MEMBERS,
    )
    members_total = add_trace_total(
      "total event members",
      members_total,
      domain_count,
      MAX_TRACE_TOTAL_EVENT_MEMBERS,
    )
    changes_total = add_trace_total(
      "total changes",
      changes_total,
      change_count,
      MAX_TRACE_TOTAL_CHANGES,
    )
    drives_total += drive_count
    domains_total += domain_count
    let drives : Array[String] = []
    for _ in 0..<drive_count {
      let (drive_line, drive_tokens) = reader.tokens("DRIVE")
      require_line(drive_line, drive_tokens, "DRIVE", 2, "DRIVE name")
      drives.push(decode_text(drive_line, drive_tokens[1]))
    }
    let domains : Array[Int] = []
    for _ in 0..<domain_count {
      let (domain_line, domain_tokens) = reader.tokens("ACTIVE")
      require_line(domain_line, domain_tokens, "ACTIVE", 2, "ACTIVE domain")
      domains.push(
        trace_parse_int(domain_line, "active domain", domain_tokens[1]),
      )
    }
    frames.push(
      AtomicTraceFrame::checked(
        trace_parse_uint64(line, "time", tokens[1]),
        trace_parse_uint64(line, "boundary", tokens[2]),
        parse_atomic_event(line, tokens[3], tokens[4]),
        drives,
        domains,
        parse_changes(reader, signals, change_count),
      ),
    )
  }
  if drives_total != expected_totals.drives ||
    domains_total != expected_totals.domains ||
    changes_total != expected_totals.changes {
    raise NonCanonical
  }
  frames
}

///|
/// Decode strict canonical schema-version-1 trace text.
fn parse_schema1(source : String) -> Trace raise TraceError {
  if !source.has_suffix("\n") {
    raise NonCanonical
  }
  let reader : TraceReader = {
    lines: source.split("\n").map(part => part.to_owned()).to_array(),
    cursor: 0,
  }
  let (header_line, header) = reader.tokens("LUNACHIP-TRACE version")
  require_line(
    header_line, header, "LUNACHIP-TRACE", 2, "LUNACHIP-TRACE version",
  )
  if header[1] != "1" {
    raise UnsupportedVersion(header[1])
  }
  let (signals_line, signals_header) = reader.tokens("SIGNALS count")
  require_line(signals_line, signals_header, "SIGNALS", 2, "SIGNALS count")
  let signal_count = trace_parse_int(
    signals_line,
    "signal count",
    signals_header[1],
  )
  if signal_count < 0 {
    raise UnexpectedLine(
      line=signals_line,
      expected="nonnegative signal count",
      actual=signals_header[1],
    )
  }
  let signals = parse_signal_table(reader, signal_count)
  let (frames_line, frames_header) = reader.tokens("FRAMES count")
  require_line(frames_line, frames_header, "FRAMES", 2, "FRAMES count")
  let frame_count = trace_parse_int(
    frames_line,
    "frame count",
    frames_header[1],
  )
  if frame_count < 0 {
    raise UnexpectedLine(
      line=frames_line,
      expected="nonnegative frame count",
      actual=frames_header[1],
    )
  }
  let frames = parse_frames(reader, signals, frame_count)
  let (end_line, end_tokens) = reader.tokens("END")
  require_line(end_line, end_tokens, "END", 1, "END")
  if reader.cursor != reader.lines.length() - 1 {
    raise NonCanonical
  }
  let trace : Trace = {
    schema: Legacy1,
    signals: ReadOnlyArray::from_array(signals),
    frames: ReadOnlyArray::from_array(frames),
    semantic_version: None,
    ir_digest: None,
    timebase: None,
    domains: ReadOnlyArray::from_array([]),
    atomic_frames: ReadOnlyArray::from_array([]),
  }
  if serialize(trace) != source {
    raise NonCanonical
  }
  trace
}

///|
fn parse_schema2(source : String) -> Trace raise TraceError {
  if !source.has_suffix("\n") {
    raise NonCanonical
  }
  let reader : TraceReader = {
    lines: source.split("\n").map(part => part.to_owned()).to_array(),
    cursor: 0,
  }
  let (header_line, header) = reader.tokens("LUNACHIP-TRACE version")
  require_line(
    header_line, header, "LUNACHIP-TRACE", 2, "LUNACHIP-TRACE version",
  )
  if header[1] != "2" {
    raise UnsupportedVersion(header[1])
  }
  let (semantic_line, semantic_tokens) = reader.tokens("SEMANTICS version")
  require_line(
    semantic_line, semantic_tokens, "SEMANTICS", 2, "SEMANTICS version",
  )
  let semantic_version = decode_text(semantic_line, semantic_tokens[1])
  let (ir_line, ir_tokens) = reader.tokens("IR algorithm digest")
  require_line(ir_line, ir_tokens, "IR", 3, "IR algorithm digest")
  let digest = TraceDigest::checked(ir_tokens[1], ir_tokens[2])
  let (timebase_line, timebase_tokens) = reader.tokens("TIMEBASE ticks")
  require_line(timebase_line, timebase_tokens, "TIMEBASE", 2, "TIMEBASE ticks")
  let timebase = trace_parse_uint64(
    timebase_line,
    "timebase",
    timebase_tokens[1],
  )
  let (domains_line, domains_header) = reader.tokens("DOMAINS count")
  require_line(domains_line, domains_header, "DOMAINS", 2, "DOMAINS count")
  let domain_count = trace_parse_int(
    domains_line,
    "domain count",
    domains_header[1],
  )
  if domain_count < 0 {
    raise UnexpectedLine(
      line=domains_line,
      expected="nonnegative domain count",
      actual=domains_header[1],
    )
  }
  let domains = parse_domain_table(reader, domain_count)
  let (signals_line, signals_header) = reader.tokens("SIGNALS count")
  require_line(signals_line, signals_header, "SIGNALS", 2, "SIGNALS count")
  let signal_count = trace_parse_int(
    signals_line,
    "signal count",
    signals_header[1],
  )
  if signal_count < 0 {
    raise UnexpectedLine(
      line=signals_line,
      expected="nonnegative signal count",
      actual=signals_header[1],
    )
  }
  require_trace_limit("signals", signal_count, MAX_TRACE_SIGNALS)
  let signals = parse_signal_table(reader, signal_count)
  let (frames_line, frames_header) = reader.tokens("FRAMES count")
  require_line(frames_line, frames_header, "FRAMES", 2, "FRAMES count")
  let frame_count = trace_parse_int(
    frames_line,
    "frame count",
    frames_header[1],
  )
  if frame_count < 0 {
    raise UnexpectedLine(
      line=frames_line,
      expected="nonnegative frame count",
      actual=frames_header[1],
    )
  }
  let (totals_line, totals_tokens) = reader.tokens("TOTALS counts")
  require_line(
    totals_line, totals_tokens, "TOTALS", 4, "TOTALS drives domains changes",
  )
  let expected_totals = AtomicTraceTotals::{
    drives: trace_parse_int(totals_line, "total drives", totals_tokens[1]),
    domains: trace_parse_int(totals_line, "total domains", totals_tokens[2]),
    changes: trace_parse_int(totals_line, "total changes", totals_tokens[3]),
  }
  if expected_totals.drives < 0 ||
    expected_totals.domains < 0 ||
    expected_totals.changes < 0 {
    raise UnexpectedLine(
      line=totals_line,
      expected="nonnegative totals",
      actual=totals_tokens.join(" "),
    )
  }
  ignore(
    add_trace_total(
      "total event members",
      expected_totals.drives,
      expected_totals.domains,
      MAX_TRACE_TOTAL_EVENT_MEMBERS,
    ),
  )
  require_trace_limit(
    "total changes",
    expected_totals.changes,
    MAX_TRACE_TOTAL_CHANGES,
  )
  let frames = parse_atomic_frames(
    reader, signals, frame_count, expected_totals,
  )
  let (end_line, end_tokens) = reader.tokens("END")
  require_line(end_line, end_tokens, "END", 1, "END")
  if reader.cursor != reader.lines.length() - 1 {
    raise NonCanonical
  }
  let trace = Trace::checked_atomic(
    semantic_version, digest, timebase, domains, signals, frames,
  )
  if serialize(trace) != source {
    raise NonCanonical
  }
  trace
}

///|
/// Decode strict canonical schema-version-1 or schema-version-2 trace text.
pub fn parse(source : String) -> Trace raise TraceError {
  if !source.has_suffix("\n") {
    raise NonCanonical
  }
  let reader : TraceReader = {
    lines: source.split("\n").map(part => part.to_owned()).to_array(),
    cursor: 0,
  }
  let (line, header) = reader.tokens("LUNACHIP-TRACE version")
  require_line(line, header, "LUNACHIP-TRACE", 2, "LUNACHIP-TRACE version")
  match header[1] {
    "1" => parse_schema1(source)
    "2" => parse_schema2(source)
    version => raise UnsupportedVersion(version)
  }
}
