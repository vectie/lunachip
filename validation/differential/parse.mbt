///|
priv struct CanonicalReader {
  lines : Array[String]
  mut cursor : Int
}

///|
fn CanonicalReader::tokens(
  self : CanonicalReader,
  expected : String,
) -> (Int, Array[String]) raise DifferentialError {
  if self.cursor >= self.lines.length() - 1 {
    raise InvalidCanonicalLine(
      line=self.cursor + 1,
      expected~,
      actual="end of input",
    )
  }
  let line = self.cursor + 1
  let actual = self.lines[self.cursor]
  let tokens = actual.split(" ").map(part => part.to_owned()).to_array()
  self.cursor += 1
  (line, tokens)
}

///|
fn require_tokens(
  line : Int,
  tokens : ArrayView[String],
  keyword : String,
  count : Int,
  expected : String,
) -> Unit raise DifferentialError {
  if tokens.length() != count || tokens[0] != keyword {
    raise InvalidCanonicalLine(line~, expected~, actual=tokens.join(" "))
  }
}

///|
fn parse_int(
  line : Int,
  field : String,
  value : String,
) -> Int raise DifferentialError {
  @strconv.from_str(value) catch {
    _ => raise InvalidCanonicalInteger(line~, field~, value~)
  }
}

///|
fn parse_uint64(
  line : Int,
  field : String,
  value : String,
) -> UInt64 raise DifferentialError {
  @strconv.from_str(value) catch {
    _ => raise InvalidCanonicalInteger(line~, field~, value~)
  }
}

///|
fn hex_nibble(symbol : UInt16) -> Int? {
  let value = symbol.to_int()
  if value >= 48 && value <= 57 {
    Some(value - 48)
  } else if value >= 97 && value <= 102 {
    Some(value - 97 + 10)
  } else {
    None
  }
}

///|
fn decode_text(line : Int, encoded : String) -> String raise DifferentialError {
  if encoded.length() == 0 || encoded.length() % 2 != 0 {
    raise InvalidCanonicalText(line~, value=encoded)
  }
  let bytes : Array[Byte] = []
  for index in 0..<(encoded.length() / 2) {
    guard hex_nibble(encoded[index * 2]) is Some(high) else {
      raise InvalidCanonicalText(line~, value=encoded)
    }
    guard hex_nibble(encoded[index * 2 + 1]) is Some(low) else {
      raise InvalidCanonicalText(line~, value=encoded)
    }
    bytes.push(((high << 4) | low).to_byte())
  }
  @utf8.decode(Bytes::from_array(bytes)) catch {
    _ => raise InvalidCanonicalText(line~, value=encoded)
  }
}

///|
fn read_header(
  reader : CanonicalReader,
  kind : String,
) -> Unit raise DifferentialError {
  let (line, tokens) = reader.tokens("\{kind} version")
  require_tokens(line, tokens, kind, 2, "\{kind} version")
  if tokens[1] != "1" {
    raise UnsupportedCanonicalVersion(version=tokens[1])
  }
}

///|
fn read_design_identity(
  reader : CanonicalReader,
) -> DesignIdentity raise DifferentialError {
  let (semantic_line, semantic) = reader.tokens("SEMANTIC utf8-hex")
  require_tokens(semantic_line, semantic, "SEMANTIC", 2, "SEMANTIC utf8-hex")
  let (design_line, design) = reader.tokens("DESIGN sha256 digest")
  require_tokens(design_line, design, "DESIGN", 3, "DESIGN sha256 digest")
  if design[1] != "sha256" {
    raise InvalidCanonicalLine(
      line=design_line,
      expected="DESIGN sha256 digest",
      actual=design.join(" "),
    )
  }
  DesignIdentity::checked(decode_text(semantic_line, semantic[1]), design[2]) catch {
    error =>
      raise InvalidCanonicalLine(
        line=design_line,
        expected="valid design identity",
        actual="\{Repr(error)}",
      )
  }
}

///|
fn ensure_finished(
  reader : CanonicalReader,
  source : String,
  canonical : String,
) -> Unit raise DifferentialError {
  let (line, tokens) = reader.tokens("END")
  require_tokens(line, tokens, "END", 1, "END")
  if reader.cursor != reader.lines.length() - 1 || canonical != source {
    raise NonCanonicalArtifact
  }
}

///|
/// Strictly parse and re-canonicalize a differential stimulus artifact.
pub fn parse_stimulus_sequence(
  source : String,
) -> StimulusSequence raise DifferentialError {
  if !source.has_suffix("\n") {
    raise NonCanonicalArtifact
  }
  let reader : CanonicalReader = {
    lines: source.split("\n").map(part => part.to_owned()).to_array(),
    cursor: 0,
  }
  read_header(reader, "LUNACHIP-DIFFERENTIAL-STIMULUS")
  let identity = read_design_identity(reader)
  let (seed_line, seed_tokens) = reader.tokens("SEED integer")
  require_tokens(seed_line, seed_tokens, "SEED", 2, "SEED integer")
  let seed = parse_uint64(seed_line, "seed", seed_tokens[1])
  let (count_line, count_tokens) = reader.tokens("STIMULI count")
  require_tokens(count_line, count_tokens, "STIMULI", 2, "STIMULI count")
  let count = parse_int(count_line, "stimulus count", count_tokens[1])
  if count < 0 {
    raise InvalidCanonicalInteger(
      line=count_line,
      field="stimulus count",
      value=count_tokens[1],
    )
  }
  let stimuli : Array[Stimulus] = []
  for ordinal in 0..<count {
    let (line, tokens) = reader.tokens("S ordinal event cycle action")
    if tokens.length() < 6 || tokens[0] != "S" {
      raise InvalidCanonicalLine(
        line~,
        expected="S ordinal event cycle action payload",
        actual=tokens.join(" "),
      )
    }
    let parsed_ordinal = parse_int(line, "ordinal", tokens[1])
    if parsed_ordinal != ordinal {
      raise InvalidCanonicalLine(
        line~,
        expected="ordinal \{ordinal}",
        actual=tokens[1],
      )
    }
    let event = parse_uint64(line, "event", tokens[2])
    let cycle = parse_uint64(line, "cycle", tokens[3])
    let stimulus = match tokens[4] {
      "drive" if tokens.length() == 9 =>
        Stimulus::drive(
          event,
          cycle,
          decode_text(line, tokens[5]),
          parse_normalized(line, tokens[6], tokens[7], tokens[8]),
        )
      "edge" if tokens.length() == 6 =>
        Stimulus::rising_edge(event, cycle, decode_text(line, tokens[5]))
      "sample" if tokens.length() == 6 =>
        Stimulus::sample(event, cycle, decode_text(line, tokens[5]))
      _ =>
        raise InvalidCanonicalLine(
          line~,
          expected="drive name width value-bits known-mask, edge domain, or sample tap",
          actual=tokens.join(" "),
        )
    }
    stimuli.push(stimulus)
  }
  let sequence = StimulusSequence::checked(identity, seed, stimuli)
  ensure_finished(reader, source, sequence.to_canonical_text())
  sequence
}

///|
fn parse_phase(
  line : Int,
  text : String,
) -> ObservationPhase raise DifferentialError {
  match text {
    "input" => InputApplied
    "pre-edge" => PreEdge
    "post-edge" => PostEdge
    "settled" => Settled
    _ =>
      raise InvalidCanonicalLine(
        line~,
        expected="observation phase",
        actual=text,
      )
  }
}

///|
fn parse_normalized(
  line : Int,
  width_text : String,
  bits : String,
  known : String,
) -> NormalizedValue raise DifferentialError {
  let width = parse_int(line, "value width", width_text)
  let value = NormalizedValue::from_planes(bits, known)
  if width != value.width() {
    raise InvalidCanonicalLine(
      line~,
      expected="width-matched value and known planes",
      actual="\{width_text} \{bits} \{known}",
    )
  }
  value
}

///|
/// Strictly parse and re-canonicalize a normalized result artifact.
pub fn parse_observation_set(
  source : String,
) -> ObservationSet raise DifferentialError {
  if !source.has_suffix("\n") {
    raise NonCanonicalArtifact
  }
  let reader : CanonicalReader = {
    lines: source.split("\n").map(part => part.to_owned()).to_array(),
    cursor: 0,
  }
  read_header(reader, "LUNACHIP-DIFFERENTIAL-RESULT")
  let design = read_design_identity(reader)
  let (stimulus_line, stimulus_tokens) = reader.tokens("STIMULUS sha256 digest")
  require_tokens(
    stimulus_line, stimulus_tokens, "STIMULUS", 3, "STIMULUS sha256 digest",
  )
  if stimulus_tokens[1] != "sha256" {
    raise InvalidCanonicalLine(
      line=stimulus_line,
      expected="STIMULUS sha256 digest",
      actual=stimulus_tokens.join(" "),
    )
  }
  let identity = ResultIdentity::checked(design, stimulus_tokens[2]) catch {
    error =>
      raise InvalidCanonicalLine(
        line=stimulus_line,
        expected="valid result identity",
        actual="\{Repr(error)}",
      )
  }
  let (count_line, count_tokens) = reader.tokens("OBSERVATIONS count")
  require_tokens(
    count_line, count_tokens, "OBSERVATIONS", 2, "OBSERVATIONS count",
  )
  let count = parse_int(count_line, "observation count", count_tokens[1])
  if count < 0 {
    raise InvalidCanonicalInteger(
      line=count_line,
      field="observation count",
      value=count_tokens[1],
    )
  }
  let observations : Array[Observation] = []
  for ordinal in 0..<count {
    let (line, tokens) = reader.tokens("O ordinal event cycle phase tap value")
    require_tokens(
      line, tokens, "O", 9, "O ordinal event cycle phase tap width value-bits known-mask",
    )
    let parsed_ordinal = parse_int(line, "ordinal", tokens[1])
    if parsed_ordinal != ordinal {
      raise InvalidCanonicalLine(
        line~,
        expected="ordinal \{ordinal}",
        actual=tokens[1],
      )
    }
    observations.push(
      Observation::checked(
        parse_uint64(line, "event", tokens[2]),
        parse_uint64(line, "cycle", tokens[3]),
        parse_phase(line, tokens[4]),
        decode_text(line, tokens[5]),
        parse_normalized(line, tokens[6], tokens[7], tokens[8]),
      ),
    )
  }
  let result = ObservationSet::checked(identity, observations)
  ensure_finished(reader, source, result.to_canonical_text())
  result
}
