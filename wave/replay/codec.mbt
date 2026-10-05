///|
const REPLAY_SCHEMA_VERSION : Int = 1

///|
const ATOMIC_REPLAY_SCHEMA_VERSION : Int = 2

///|
fn replay_encode_text(value : String) -> String {
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
fn write_logic(builder : StringBuilder, value : @wave.LogicValue) -> Unit {
  builder.write_string(
    "\{value.width()} \{value.value_bits()} \{value.known_mask()}",
  )
}

///|
fn write_stop(builder : StringBuilder, stop : StopCondition) -> Unit {
  match stop {
    AfterBoundary(boundary) =>
      builder.write_string("STOP after_boundary \{boundary}\n")
    AtCycle(cycle) => builder.write_string("STOP at_cycle \{cycle}\n")
    AtTime(time) => builder.write_string("STOP at_time \{time}\n")
    AtDomainEdge(domain~, count~) =>
      builder.write_string("STOP at_domain_edge \{domain.ordinal()} \{count}\n")
    OutputEquals(name~, value~) => {
      builder.write_string("STOP output_equals \{replay_encode_text(name)} ")
      write_logic(builder, value)
      builder.write_char('\n')
    }
  }
}

///|
/// Serialize a replay bundle to canonical schema-version-1 native text.
fn serialize_schema1(bundle : ReplayBundle) -> String {
  let builder = StringBuilder()
  builder.write_string("LUNACHIP-REPLAY \{REPLAY_SCHEMA_VERSION}\n")
  builder.write_string(
    "SEMANTICS \{replay_encode_text(bundle.semantic_version())}\n",
  )
  builder.write_string("OPTIONS \{bundle.options().length()}\n")
  for option in bundle.options() {
    builder.write_string(
      "OPTION \{replay_encode_text(option.key())} \{replay_encode_text(option.value())}\n",
    )
  }
  let ir_digest = bundle.ir_digest()
  builder.write_string(
    "IR \{ir_digest.algorithm()} \{ir_digest.hex()} \{replay_encode_text(bundle.canonical_ir())}\n",
  )
  builder.write_string("STIMULI \{bundle.stimuli().length()}\n")
  for stimulus in bundle.stimuli() {
    match stimulus.action() {
      Drive(inputs) => {
        builder.write_string(
          "DRIVE \{stimulus.cycle()} \{stimulus.boundary()} \{inputs.length()}\n",
        )
        for input in inputs {
          builder.write_string("INPUT \{replay_encode_text(input.name())} ")
          write_logic(builder, input.value())
          builder.write_char('\n')
        }
      }
      RisingEdge(clock) =>
        builder.write_string(
          "EDGE \{stimulus.cycle()} \{stimulus.boundary()} \{replay_encode_text(clock)}\n",
        )
    }
  }
  write_stop(builder, bundle.stop())
  builder.write_string("TAPS \{bundle.taps().length()}\n")
  for tap in bundle.taps() {
    builder.write_string(
      "TAP \{tap.width()} \{replay_encode_text(tap.path())} \{replay_encode_text(tap.name())}\n",
    )
  }
  let expected = bundle.expected_result()
  builder.write_string("EXPECTED \{expected.algorithm()} \{expected.hex()}\n")
  builder.write_string("END\n")
  builder.to_string()
}

///|
fn serialize_schema2(bundle : ReplayBundle) -> String {
  let builder = StringBuilder()
  builder.write_string("LUNACHIP-REPLAY \{ATOMIC_REPLAY_SCHEMA_VERSION}\n")
  builder.write_string(
    "SEMANTICS \{replay_encode_text(bundle.semantic_version())}\n",
  )
  builder.write_string("OPTIONS \{bundle.options().length()}\n")
  for option in bundle.options() {
    builder.write_string(
      "OPTION \{replay_encode_text(option.key())} \{replay_encode_text(option.value())}\n",
    )
  }
  let ir_digest = bundle.ir_digest()
  builder.write_string(
    "IR \{ir_digest.algorithm()} \{ir_digest.hex()} \{replay_encode_text(bundle.canonical_ir())}\n",
  )
  let timebase = match bundle.timebase() {
    Some(value) => value
    None => abort("validated schema-2 replay is missing its timebase")
  }
  builder.write_string("TIMEBASE \{timebase}\n")
  builder.write_string("EVENTS \{bundle.events().length()}\n")
  for event in bundle.events() {
    builder.write_string(
      "EVENT \{event.time()} \{event.boundary()} \{event.drives().length()} \{event.domains().length()}\n",
    )
    for input in event.drives() {
      builder.write_string("INPUT \{replay_encode_text(input.name())} ")
      write_logic(builder, input.value())
      builder.write_char('\n')
    }
    for domain in event.domains() {
      builder.write_string("DOMAIN \{domain.ordinal()}\n")
    }
  }
  write_stop(builder, bundle.stop())
  builder.write_string("TAPS \{bundle.taps().length()}\n")
  for tap in bundle.taps() {
    builder.write_string(
      "TAP \{tap.width()} \{replay_encode_text(tap.path())} \{replay_encode_text(tap.name())}\n",
    )
  }
  let expected = bundle.expected_result()
  builder.write_string("EXPECTED \{expected.algorithm()} \{expected.hex()}\n")
  builder.write_string("END\n")
  builder.to_string()
}

///|
/// Serialize using the bundle's canonical replay schema.
pub fn serialize(bundle : ReplayBundle) -> String {
  match bundle.schema() {
    Legacy1 => serialize_schema1(bundle)
    Atomic2 => serialize_schema2(bundle)
  }
}

///|
priv struct ReplayReader {
  lines : Array[String]
  mut cursor : Int
}

///|
fn ReplayReader::tokens(
  self : ReplayReader,
  expected : String,
) -> (Int, Array[String]) raise ReplayError {
  if self.cursor >= self.lines.length() - 1 {
    raise UnexpectedEnd(expected~)
  }
  let line_number = self.cursor + 1
  let tokens = self.lines[self.cursor]
    .split(" ")
    .map(part => part.to_owned())
    .to_array()
  self.cursor += 1
  (line_number, tokens)
}

///|
fn replay_require_line(
  line : Int,
  tokens : ArrayView[String],
  keyword : String,
  count : Int,
  expected : String,
) -> Unit raise ReplayError {
  if tokens.length() != count || tokens[0] != keyword {
    raise UnexpectedLine(line~, expected~, actual=tokens.join(" "))
  }
}

///|
fn replay_parse_int(
  line : Int,
  field : String,
  value : String,
) -> Int raise ReplayError {
  @string.parse_int(value) catch {
    _ => raise InvalidInteger(line~, field~, value~)
  }
}

///|
fn replay_parse_uint64(
  line : Int,
  field : String,
  value : String,
) -> UInt64 raise ReplayError {
  @string.parse_uint64(value) catch {
    _ => raise InvalidInteger(line~, field~, value~)
  }
}

///|
fn replay_hex_nibble(code : UInt16) -> Int? {
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
fn replay_decode_text(line : Int, encoded : String) -> String raise ReplayError {
  if encoded == "-" {
    return ""
  }
  if encoded.length() == 0 || encoded.length() % 2 != 0 {
    raise InvalidEncodedText(line~, value=encoded)
  }
  let bytes : Array[Byte] = []
  for index in 0..<(encoded.length() / 2) {
    guard replay_hex_nibble(encoded[index * 2]) is Some(high) else {
      raise InvalidEncodedText(line~, value=encoded)
    }
    guard replay_hex_nibble(encoded[index * 2 + 1]) is Some(low) else {
      raise InvalidEncodedText(line~, value=encoded)
    }
    bytes.push(((high << 4) | low).to_byte())
  }
  @utf8.decode(Bytes::from_array(bytes)) catch {
    _ => raise InvalidUtf8Text(line~)
  }
}

///|
fn parse_logic(
  line : Int,
  width : String,
  value_bits : String,
  known_mask : String,
) -> @wave.LogicValue raise ReplayError {
  @wave.LogicValue::from_masks(
    width=replay_parse_int(line, "width", width),
    value_bits=replay_parse_uint64(line, "value bits", value_bits),
    known_mask=replay_parse_uint64(line, "known mask", known_mask),
  ) catch {
    _ =>
      raise UnexpectedLine(
        line~,
        expected="width-bounded logic value",
        actual="\{width} \{value_bits} \{known_mask}",
      )
  }
}

///|
fn parse_options(
  reader : ReplayReader,
  count : Int,
) -> Array[ReplayOption] raise ReplayError {
  let options : Array[ReplayOption] = []
  for _ in 0..<count {
    let (line, tokens) = reader.tokens("OPTION")
    replay_require_line(line, tokens, "OPTION", 3, "OPTION key value")
    options.push(
      ReplayOption::checked(
        replay_decode_text(line, tokens[1]),
        replay_decode_text(line, tokens[2]),
      ),
    )
  }
  options
}

///|
fn parse_inputs(
  reader : ReplayReader,
  count : Int,
) -> Array[NamedInput] raise ReplayError {
  let inputs : Array[NamedInput] = []
  for _ in 0..<count {
    let (line, tokens) = reader.tokens("INPUT")
    replay_require_line(
      line, tokens, "INPUT", 5, "INPUT name width value known",
    )
    inputs.push(
      NamedInput::checked(
        replay_decode_text(line, tokens[1]),
        parse_logic(line, tokens[2], tokens[3], tokens[4]),
      ),
    )
  }
  inputs
}

///|
fn parse_stimuli(
  reader : ReplayReader,
  count : Int,
) -> Array[ReplayStimulus] raise ReplayError {
  let stimuli : Array[ReplayStimulus] = []
  for _ in 0..<count {
    let (line, tokens) = reader.tokens("DRIVE or EDGE")
    if tokens.length() == 4 && tokens[0] == "DRIVE" {
      let input_count = replay_parse_int(line, "input count", tokens[3])
      if input_count < 1 {
        raise UnexpectedLine(
          line~,
          expected="positive input count",
          actual=tokens[3],
        )
      }
      stimuli.push(
        ReplayStimulus::drive(
          replay_parse_uint64(line, "cycle", tokens[1]),
          replay_parse_uint64(line, "boundary", tokens[2]),
          parse_inputs(reader, input_count),
        ),
      )
    } else if tokens.length() == 4 && tokens[0] == "EDGE" {
      stimuli.push(
        ReplayStimulus::rising_edge(
          replay_parse_uint64(line, "cycle", tokens[1]),
          replay_parse_uint64(line, "boundary", tokens[2]),
          replay_decode_text(line, tokens[3]),
        ),
      )
    } else {
      raise UnexpectedLine(
        line~,
        expected="DRIVE or EDGE",
        actual=tokens.join(" "),
      )
    }
  }
  stimuli
}

///|
fn parse_atomic_events(
  reader : ReplayReader,
  count : Int,
) -> Array[AtomicReplayEvent] raise ReplayError {
  let events : Array[AtomicReplayEvent] = []
  for _ in 0..<count {
    let (line, tokens) = reader.tokens("EVENT")
    replay_require_line(
      line, tokens, "EVENT", 5, "EVENT time boundary drive-count domain-count",
    )
    let drive_count = replay_parse_int(line, "drive count", tokens[3])
    let domain_count = replay_parse_int(line, "domain count", tokens[4])
    if drive_count < 0 || domain_count < 0 {
      raise UnexpectedLine(
        line~,
        expected="nonnegative event counts",
        actual="\{tokens[3]} \{tokens[4]}",
      )
    }
    let drives = parse_inputs(reader, drive_count)
    let domains : Array[@ir.ClockDomainId] = []
    for _ in 0..<domain_count {
      let (domain_line, domain_tokens) = reader.tokens("DOMAIN id")
      replay_require_line(domain_line, domain_tokens, "DOMAIN", 2, "DOMAIN id")
      let ordinal = replay_parse_int(domain_line, "domain", domain_tokens[1])
      domains.push(
        @ir.ClockDomainId::new(ordinal) catch {
          _ =>
            raise UnexpectedLine(
              line=domain_line,
              expected="nonnegative domain ID",
              actual=domain_tokens[1],
            )
        },
      )
    }
    events.push(
      AtomicReplayEvent::checked(
        replay_parse_uint64(line, "time", tokens[1]),
        replay_parse_uint64(line, "boundary", tokens[2]),
        drives,
        domains,
      ),
    )
  }
  events
}

///|
fn parse_stop(reader : ReplayReader) -> StopCondition raise ReplayError {
  let (line, tokens) = reader.tokens("STOP")
  if tokens.length() == 3 && tokens[0] == "STOP" {
    match tokens[1] {
      "after_boundary" =>
        AfterBoundary(replay_parse_uint64(line, "boundary", tokens[2]))
      "at_cycle" => AtCycle(replay_parse_uint64(line, "cycle", tokens[2]))
      "at_time" => AtTime(replay_parse_uint64(line, "time", tokens[2]))
      _ =>
        raise UnexpectedLine(
          line~,
          expected="STOP condition",
          actual=tokens.join(" "),
        )
    }
  } else if tokens.length() == 4 &&
    tokens[0] == "STOP" &&
    tokens[1] == "at_domain_edge" {
    AtDomainEdge(
      domain=@ir.ClockDomainId::new(replay_parse_int(line, "domain", tokens[2])) catch {
        _ =>
          raise UnexpectedLine(
            line~,
            expected="nonnegative domain ID",
            actual=tokens[2],
          )
      },
      count=replay_parse_uint64(line, "domain edge count", tokens[3]),
    )
  } else if tokens.length() == 6 &&
    tokens[0] == "STOP" &&
    tokens[1] == "output_equals" {
    OutputEquals(
      name=replay_decode_text(line, tokens[2]),
      value=parse_logic(line, tokens[3], tokens[4], tokens[5]),
    )
  } else {
    raise UnexpectedLine(
      line~,
      expected="STOP condition",
      actual=tokens.join(" "),
    )
  }
}

///|
fn parse_taps(
  reader : ReplayReader,
  count : Int,
) -> Array[@trace.TraceSignal] raise ReplayError {
  let taps : Array[@trace.TraceSignal] = []
  for _ in 0..<count {
    let (line, tokens) = reader.tokens("TAP")
    replay_require_line(line, tokens, "TAP", 4, "TAP width path name")
    let tap = @trace.TraceSignal::checked(
      replay_decode_text(line, tokens[2]),
      replay_decode_text(line, tokens[3]),
      replay_parse_int(line, "tap width", tokens[1]),
    ) catch {
      error =>
        raise UnexpectedLine(
          line~,
          expected="valid tap",
          actual="\{Repr(error)}",
        )
    }
    taps.push(tap)
  }
  taps
}

///|
/// Decode strict canonical schema-version-1 replay text and verify embedded IR.
fn parse_schema1(source : String) -> ReplayBundle raise ReplayError {
  if !source.has_suffix("\n") {
    raise NonCanonical
  }
  let reader : ReplayReader = {
    lines: source.split("\n").map(part => part.to_owned()).to_array(),
    cursor: 0,
  }
  let (header_line, header) = reader.tokens("LUNACHIP-REPLAY version")
  replay_require_line(
    header_line, header, "LUNACHIP-REPLAY", 2, "LUNACHIP-REPLAY version",
  )
  if header[1] != "1" {
    raise UnsupportedVersion(header[1])
  }
  let (semantic_line, semantic) = reader.tokens("SEMANTICS version")
  replay_require_line(
    semantic_line, semantic, "SEMANTICS", 2, "SEMANTICS version",
  )
  let semantic_version = replay_decode_text(semantic_line, semantic[1])
  let (options_line, options_header) = reader.tokens("OPTIONS count")
  replay_require_line(
    options_line, options_header, "OPTIONS", 2, "OPTIONS count",
  )
  let option_count = replay_parse_int(
    options_line,
    "option count",
    options_header[1],
  )
  if option_count < 0 {
    raise UnexpectedLine(
      line=options_line,
      expected="nonnegative option count",
      actual=options_header[1],
    )
  }
  let options = parse_options(reader, option_count)
  let (ir_line, ir_tokens) = reader.tokens("IR algorithm digest canonical-text")
  replay_require_line(
    ir_line, ir_tokens, "IR", 4, "IR algorithm digest canonical-text",
  )
  let embedded_ir_digest = ReplayDigest::checked(ir_tokens[1], ir_tokens[2])
  let canonical_ir = replay_decode_text(ir_line, ir_tokens[3])
  let design = @codec.parse(canonical_ir) catch {
    error => raise InvalidCanonicalIr("\{Repr(error)}")
  }
  let actual_ir_digest = ir_digest_of(design)
  if embedded_ir_digest != actual_ir_digest {
    raise IrDigestMismatch(
      expected=embedded_ir_digest.hex(),
      actual=actual_ir_digest.hex(),
    )
  }
  let (stimuli_line, stimuli_header) = reader.tokens("STIMULI count")
  replay_require_line(
    stimuli_line, stimuli_header, "STIMULI", 2, "STIMULI count",
  )
  let stimulus_count = replay_parse_int(
    stimuli_line,
    "stimulus count",
    stimuli_header[1],
  )
  if stimulus_count < 0 {
    raise UnexpectedLine(
      line=stimuli_line,
      expected="nonnegative stimulus count",
      actual=stimuli_header[1],
    )
  }
  let stimuli = parse_stimuli(reader, stimulus_count)
  let stop = parse_stop(reader)
  let (taps_line, taps_header) = reader.tokens("TAPS count")
  replay_require_line(taps_line, taps_header, "TAPS", 2, "TAPS count")
  let tap_count = replay_parse_int(taps_line, "tap count", taps_header[1])
  if tap_count < 0 {
    raise UnexpectedLine(
      line=taps_line,
      expected="nonnegative tap count",
      actual=taps_header[1],
    )
  }
  let taps = parse_taps(reader, tap_count)
  let (expected_line, expected_tokens) = reader.tokens(
    "EXPECTED algorithm digest",
  )
  replay_require_line(
    expected_line, expected_tokens, "EXPECTED", 3, "EXPECTED algorithm digest",
  )
  let expected = ReplayDigest::checked(expected_tokens[1], expected_tokens[2])
  let (end_line, end_tokens) = reader.tokens("END")
  replay_require_line(end_line, end_tokens, "END", 1, "END")
  if reader.cursor != reader.lines.length() - 1 {
    raise NonCanonical
  }
  let bundle = freeze_schema1_bundle(
    design, semantic_version, options, stimuli, stop, taps, expected,
  )
  if serialize(bundle) != source {
    raise NonCanonical
  }
  bundle
}

///|
fn parse_schema2(source : String) -> ReplayBundle raise ReplayError {
  if !source.has_suffix("\n") {
    raise NonCanonical
  }
  let reader : ReplayReader = {
    lines: source.split("\n").map(part => part.to_owned()).to_array(),
    cursor: 0,
  }
  let (header_line, header) = reader.tokens("LUNACHIP-REPLAY version")
  replay_require_line(
    header_line, header, "LUNACHIP-REPLAY", 2, "LUNACHIP-REPLAY version",
  )
  if header[1] != "2" {
    raise UnsupportedVersion(header[1])
  }
  let (semantic_line, semantic) = reader.tokens("SEMANTICS version")
  replay_require_line(
    semantic_line, semantic, "SEMANTICS", 2, "SEMANTICS version",
  )
  let semantic_version = replay_decode_text(semantic_line, semantic[1])
  let (options_line, options_header) = reader.tokens("OPTIONS count")
  replay_require_line(
    options_line, options_header, "OPTIONS", 2, "OPTIONS count",
  )
  let option_count = replay_parse_int(
    options_line,
    "option count",
    options_header[1],
  )
  if option_count < 0 {
    raise UnexpectedLine(
      line=options_line,
      expected="nonnegative option count",
      actual=options_header[1],
    )
  }
  let options = parse_options(reader, option_count)
  let (ir_line, ir_tokens) = reader.tokens("IR algorithm digest canonical-text")
  replay_require_line(
    ir_line, ir_tokens, "IR", 4, "IR algorithm digest canonical-text",
  )
  let embedded_ir_digest = ReplayDigest::checked(ir_tokens[1], ir_tokens[2])
  let canonical_ir = replay_decode_text(ir_line, ir_tokens[3])
  let design = @codec.parse(canonical_ir) catch {
    error => raise InvalidCanonicalIr("\{Repr(error)}")
  }
  let actual_ir_digest = ir_digest_of(design)
  if embedded_ir_digest != actual_ir_digest {
    raise IrDigestMismatch(
      expected=embedded_ir_digest.hex(),
      actual=actual_ir_digest.hex(),
    )
  }
  let (timebase_line, timebase_tokens) = reader.tokens("TIMEBASE ticks")
  replay_require_line(
    timebase_line, timebase_tokens, "TIMEBASE", 2, "TIMEBASE ticks",
  )
  let timebase = replay_parse_uint64(
    timebase_line,
    "timebase",
    timebase_tokens[1],
  )
  let (events_line, events_header) = reader.tokens("EVENTS count")
  replay_require_line(events_line, events_header, "EVENTS", 2, "EVENTS count")
  let event_count = replay_parse_int(
    events_line,
    "event count",
    events_header[1],
  )
  if event_count < 0 {
    raise UnexpectedLine(
      line=events_line,
      expected="nonnegative event count",
      actual=events_header[1],
    )
  }
  let events = parse_atomic_events(reader, event_count)
  let stop = parse_stop(reader)
  let (taps_line, taps_header) = reader.tokens("TAPS count")
  replay_require_line(taps_line, taps_header, "TAPS", 2, "TAPS count")
  let tap_count = replay_parse_int(taps_line, "tap count", taps_header[1])
  if tap_count < 0 {
    raise UnexpectedLine(
      line=taps_line,
      expected="nonnegative tap count",
      actual=taps_header[1],
    )
  }
  let taps = parse_taps(reader, tap_count)
  let (expected_line, expected_tokens) = reader.tokens(
    "EXPECTED algorithm digest",
  )
  replay_require_line(
    expected_line, expected_tokens, "EXPECTED", 3, "EXPECTED algorithm digest",
  )
  let expected = ReplayDigest::checked(expected_tokens[1], expected_tokens[2])
  let (end_line, end_tokens) = reader.tokens("END")
  replay_require_line(end_line, end_tokens, "END", 1, "END")
  if reader.cursor != reader.lines.length() - 1 {
    raise NonCanonical
  }
  let bundle = freeze_schema2_bundle(
    design, semantic_version, options, timebase, events, stop, taps, expected,
  )
  if serialize(bundle) != source {
    raise NonCanonical
  }
  bundle
}

///|
/// Decode strict canonical schema-version-1 or schema-version-2 replay text.
/// Parsing preserves canonical legacy artifacts; execution policy is enforced
/// by checked construction and `execute`, not by this migration boundary.
pub fn parse(source : String) -> ReplayBundle raise ReplayError {
  if !source.has_suffix("\n") {
    raise NonCanonical
  }
  let reader : ReplayReader = {
    lines: source.split("\n").map(part => part.to_owned()).to_array(),
    cursor: 0,
  }
  let (line, header) = reader.tokens("LUNACHIP-REPLAY version")
  replay_require_line(
    line, header, "LUNACHIP-REPLAY", 2, "LUNACHIP-REPLAY version",
  )
  match header[1] {
    "1" => parse_schema1(source)
    "2" => parse_schema2(source)
    version => raise UnsupportedVersion(version)
  }
}
