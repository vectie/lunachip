///|
/// Stable failures raised while constructing or decoding replay artifacts.
pub(all) suberror ReplayError {
  EmptySemanticVersion
  EmptyOptionKey
  DuplicateOption(String)
  EmptyInputName
  EmptyDrive
  DuplicateInput(String)
  EmptyClockName
  EmptyOutputName
  DuplicateTap(path~ : String, name~ : String)
  NonMonotonicStimulus
  UnsupportedDigestAlgorithm(String)
  InvalidDigestHex(String)
  IrDigestMismatch(expected~ : String, actual~ : String)
  InvalidInteger(line~ : Int, field~ : String, value~ : String)
  InvalidEncodedText(line~ : Int, value~ : String)
  InvalidUtf8Text(line~ : Int)
  UnexpectedEnd(expected~ : String)
  UnexpectedLine(line~ : Int, expected~ : String, actual~ : String)
  UnsupportedVersion(String)
  InvalidCanonicalIr(String)
  NonCanonical
} derive(Debug, Eq)

///|
/// Stable failures that can occur after a replay bundle has been validated.
pub(all) suberror ReplayExecutionError {
  MissingTopModule
  UnknownTap(path~ : String, name~ : String)
  AmbiguousTap(path~ : String, name~ : String)
  TapWidthMismatch(
    path~ : String,
    name~ : String,
    expected~ : Int,
    actual~ : Int
  )
  ScheduledCycleMismatch(
    boundary~ : UInt64,
    expected~ : UInt64,
    actual~ : UInt64
  )
} derive(Debug, Eq)

///|
/// Complete deterministic result of replay execution.
pub struct ReplayResult {
  trace : @trace.Trace
  digest : ReplayDigest
  expected_matches : Bool
  stop_reached : Bool
} derive(Debug, Eq)

///|
pub fn ReplayResult::trace(self : ReplayResult) -> @trace.Trace {
  self.trace
}

///|
pub fn ReplayResult::digest(self : ReplayResult) -> ReplayDigest {
  self.digest
}

///|
pub fn ReplayResult::expected_matches(self : ReplayResult) -> Bool {
  self.expected_matches
}

///|
pub fn ReplayResult::stop_reached(self : ReplayResult) -> Bool {
  self.stop_reached
}

///|
/// A named, deterministic semantic option.
pub struct ReplayOption {
  key : String
  value : String
} derive(Debug, Eq)

///|
pub fn ReplayOption::checked(
  key : String,
  value : String,
) -> ReplayOption raise ReplayError {
  if key.length() == 0 {
    raise EmptyOptionKey
  }
  { key, value }
}

///|
pub fn ReplayOption::key(self : ReplayOption) -> String {
  self.key
}

///|
pub fn ReplayOption::value(self : ReplayOption) -> String {
  self.value
}

///|
/// A checked digest reference. Phase 2 deliberately supports only the same
/// deterministic FNV-1a-64 bootstrap algorithm as canonical IR.
pub struct ReplayDigest {
  algorithm : String
  hex : String
} derive(Debug, Eq)

///|
pub fn ReplayDigest::checked(
  algorithm : String,
  hex : String,
) -> ReplayDigest raise ReplayError {
  if algorithm != "fnv1a-64" {
    raise UnsupportedDigestAlgorithm(algorithm)
  }
  if hex.length() != 16 {
    raise InvalidDigestHex(hex)
  }
  for code in hex {
    if !((code >= '0' && code <= '9') || (code >= 'a' && code <= 'f')) {
      raise InvalidDigestHex(hex)
    }
  }
  { algorithm, hex }
}

///|
pub fn ReplayDigest::algorithm(self : ReplayDigest) -> String {
  self.algorithm
}

///|
pub fn ReplayDigest::hex(self : ReplayDigest) -> String {
  self.hex
}

///|
/// One named input value inside a simultaneous drive event.
pub struct NamedInput {
  name : String
  value : @wave.LogicValue
} derive(Debug, Eq)

///|
pub fn NamedInput::checked(
  name : String,
  value : @wave.LogicValue,
) -> NamedInput raise ReplayError {
  if name.length() == 0 {
    raise EmptyInputName
  }
  { name, value }
}

///|
pub fn NamedInput::name(self : NamedInput) -> String {
  self.name
}

///|
pub fn NamedInput::value(self : NamedInput) -> @wave.LogicValue {
  self.value
}

///|
/// The action applied at one replay boundary.
pub(all) enum ReplayAction {
  Drive(ReadOnlyArray[NamedInput])
  RisingEdge(String)
} derive(Debug, Eq)

///|
/// One ordered deterministic replay stimulus.
pub struct ReplayStimulus {
  cycle : UInt64
  boundary : UInt64
  action : ReplayAction
} derive(Debug, Eq)

///|
/// Construct a simultaneous named-input drive, canonicalized by input name.
pub fn ReplayStimulus::drive(
  cycle : UInt64,
  boundary : UInt64,
  declared : ArrayView[NamedInput],
) -> ReplayStimulus raise ReplayError {
  if declared.length() == 0 {
    raise EmptyDrive
  }
  let inputs = declared.to_owned()
  inputs.sort_by((left, right) => replay_compare_text(left.name(), right.name()))
  for index, input in inputs {
    if index > 0 && inputs[index - 1].name() == input.name() {
      raise DuplicateInput(input.name())
    }
  }
  { cycle, boundary, action: Drive(ReadOnlyArray::from_array(inputs)) }
}

///|
/// Construct one named rising-edge event.
pub fn ReplayStimulus::rising_edge(
  cycle : UInt64,
  boundary : UInt64,
  clock : String,
) -> ReplayStimulus raise ReplayError {
  if clock.length() == 0 {
    raise EmptyClockName
  }
  { cycle, boundary, action: RisingEdge(clock) }
}

///|
pub fn ReplayStimulus::cycle(self : ReplayStimulus) -> UInt64 {
  self.cycle
}

///|
pub fn ReplayStimulus::boundary(self : ReplayStimulus) -> UInt64 {
  self.boundary
}

///|
pub fn ReplayStimulus::action(self : ReplayStimulus) -> ReplayAction {
  self.action
}

///|
/// A deterministic replay termination rule.
pub(all) enum StopCondition {
  AfterBoundary(UInt64)
  AtCycle(UInt64)
  OutputEquals(name~ : String, value~ : @wave.LogicValue)
} derive(Debug, Eq)

///|
/// Immutable replay artifact carrying canonical hardware and stimulus context.
pub struct ReplayBundle {
  canonical_ir : String
  ir_digest : ReplayDigest
  semantic_version : String
  options : ReadOnlyArray[ReplayOption]
  stimuli : ReadOnlyArray[ReplayStimulus]
  stop : StopCondition
  taps : ReadOnlyArray[@trace.TraceSignal]
  expected_result : ReplayDigest
} derive(Debug, Eq)

///|
pub fn ReplayBundle::canonical_ir(self : ReplayBundle) -> String {
  self.canonical_ir
}

///|
pub fn ReplayBundle::ir_digest(self : ReplayBundle) -> ReplayDigest {
  self.ir_digest
}

///|
pub fn ReplayBundle::semantic_version(self : ReplayBundle) -> String {
  self.semantic_version
}

///|
pub fn ReplayBundle::options(
  self : ReplayBundle,
) -> ReadOnlyArray[ReplayOption] {
  self.options
}

///|
pub fn ReplayBundle::stimuli(
  self : ReplayBundle,
) -> ReadOnlyArray[ReplayStimulus] {
  self.stimuli
}

///|
pub fn ReplayBundle::stop(self : ReplayBundle) -> StopCondition {
  self.stop
}

///|
pub fn ReplayBundle::taps(
  self : ReplayBundle,
) -> ReadOnlyArray[@trace.TraceSignal] {
  self.taps
}

///|
pub fn ReplayBundle::expected_result(self : ReplayBundle) -> ReplayDigest {
  self.expected_result
}
