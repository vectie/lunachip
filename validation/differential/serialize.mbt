///|
fn hex_digit(value : Int32) -> Char {
  match value {
    0 => '0'
    1 => '1'
    2 => '2'
    3 => '3'
    4 => '4'
    5 => '5'
    6 => '6'
    7 => '7'
    8 => '8'
    9 => '9'
    10 => 'a'
    11 => 'b'
    12 => 'c'
    13 => 'd'
    14 => 'e'
    _ => 'f'
  }
}

///|
fn encode_text(text : String) -> String {
  let bytes = @utf8.encode(text)
  let output = StringBuilder(size_hint=bytes.length() * 2)
  for byte in bytes {
    let value = byte.to_int()
    output.write_char(hex_digit(value >> 4))
    output.write_char(hex_digit(value & 15))
  }
  output.to_string()
}

///|
fn phase_text(phase : ObservationPhase) -> String {
  match phase {
    InputApplied => "input"
    PreEdge => "pre-edge"
    PostEdge => "post-edge"
    Settled => "settled"
  }
}

///|
/// Serialize a canonical normalized result artifact.
pub fn ObservationSet::to_canonical_text(self : ObservationSet) -> String {
  let output = StringBuilder()
  output <+ "LUNACHIP-DIFFERENTIAL-RESULT 1\n"
  output <+ "SEMANTIC \{encode_text(self.identity.design.semantic_version)}\n"
  output <+ "DESIGN sha256 \{self.identity.design.design_sha256}\n"
  output <+ "STIMULUS sha256 \{self.identity.stimulus_sha256}\n"
  output <+ "OBSERVATIONS \{self.observations.length()}\n"
  for index, observation in self.observations {
    output <+
      "O \{index} \{observation.event} \{observation.cycle} \{phase_text(observation.phase)} \{encode_text(observation.tap)} \{observation.value.width()} \{observation.value.value_bits()} \{observation.value.known_mask()}\n"
  }
  output <+ "END\n"
  output.to_string()
}

///|
/// Serialize a canonical replay fixture. Array order is semantic and each line
/// carries an explicit ordinal, while names are UTF-8 hex encoded.
pub fn StimulusSequence::to_canonical_text(self : StimulusSequence) -> String {
  let output = StringBuilder()
  output <+ "LUNACHIP-DIFFERENTIAL-STIMULUS 1\n"
  output <+ "SEMANTIC \{encode_text(self.identity.semantic_version)}\n"
  output <+ "DESIGN sha256 \{self.identity.design_sha256}\n"
  output <+ "SEED \{self.seed}\n"
  output <+ "STIMULI \{self.stimuli.length()}\n"
  for index, stimulus in self.stimuli {
    match stimulus.action {
      Drive(tap~, value~) =>
        output <+
          "S \{index} \{stimulus.event} \{stimulus.cycle} drive \{encode_text(tap)} \{value.width()} \{value.value_bits()} \{value.known_mask()}\n"
      RisingEdge(domain~) =>
        output <+
          "S \{index} \{stimulus.event} \{stimulus.cycle} edge \{encode_text(domain)}\n"
      Sample(tap~) =>
        output <+
          "S \{index} \{stimulus.event} \{stimulus.cycle} sample \{encode_text(tap)}\n"
    }
  }
  output <+ "END\n"
  output.to_string()
}
