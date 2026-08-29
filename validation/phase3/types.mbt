///|
/// Representative Phase 3 design families. Every fixture contains one explicit
/// rising-edge clock and a synchronous reset so compared state is initialized
/// before the first observation.
pub(all) enum FixtureKind {
  CombinationalLogic
  Arithmetic
  ControlledCounter
  Pipeline
  Lfsr
  ReadyValid
} derive(Debug, Eq)

///|
pub fn FixtureKind::id(self : FixtureKind) -> String {
  match self {
    CombinationalLogic => "combinational-logic"
    Arithmetic => "arithmetic"
    ControlledCounter => "controlled-counter"
    Pipeline => "pipeline"
    Lfsr => "lfsr"
    ReadyValid => "ready-valid"
  }
}

///|
/// One deterministic run request. `post_reset_cycles` deliberately excludes
/// the reset preamble edge.
pub struct FixturePlan {
  kind : FixtureKind
  seed : UInt64
  post_reset_cycles : Int
} derive(Debug, Eq)

///|
pub fn FixturePlan::checked(
  kind : FixtureKind,
  seed : UInt64,
  post_reset_cycles : Int,
) -> FixturePlan raise Phase3Error {
  if post_reset_cycles < 1 {
    raise InvalidCycleCount(post_reset_cycles)
  }
  { kind, seed, post_reset_cycles }
}

///|
pub fn FixturePlan::kind(self : FixturePlan) -> FixtureKind {
  self.kind
}

///|
pub fn FixturePlan::seed(self : FixturePlan) -> UInt64 {
  self.seed
}

///|
pub fn FixturePlan::post_reset_cycles(self : FixturePlan) -> Int {
  self.post_reset_cycles
}

///|
/// The standard gate covers 102,000 post-reset cycles without ambient random
/// state. Changing a seed or cycle allocation is an explicit artifact change.
pub fn standard_plan() -> ReadOnlyArray[FixturePlan] {
  ReadOnlyArray::from_array([
    {
      kind: CombinationalLogic,
      seed: 0x243f6a8885a308d3UL,
      post_reset_cycles: 17000,
    },
    { kind: Arithmetic, seed: 0x13198a2e03707344UL, post_reset_cycles: 17000 },
    {
      kind: ControlledCounter,
      seed: 0xa4093822299f31d0UL,
      post_reset_cycles: 17000,
    },
    { kind: Pipeline, seed: 0x082efa98ec4e6c89UL, post_reset_cycles: 17000 },
    { kind: Lfsr, seed: 0x452821e638d01377UL, post_reset_cycles: 17000 },
    { kind: ReadyValid, seed: 0xbe5466cf34e90c6cUL, post_reset_cycles: 17000 },
  ])
}

///|
pub fn total_post_reset_cycles(plans : ArrayView[FixturePlan]) -> Int {
  plans.fold(init=0, (sum, plan) => sum + plan.post_reset_cycles())
}

///|
pub(all) enum PortDirection {
  Input
  Output
} derive(Debug, Eq)

///|
/// Source and emitted identity for one top-level port.
pub struct HarnessPort {
  source_name : String
  emitted_name : String
  direction : PortDirection
  width : Int
  signal_type : @ir.SignalType
} derive(Debug, Eq)

///|
pub fn HarnessPort::source_name(self : HarnessPort) -> String {
  self.source_name
}

///|
pub fn HarnessPort::emitted_name(self : HarnessPort) -> String {
  self.emitted_name
}

///|
pub fn HarnessPort::direction(self : HarnessPort) -> PortDirection {
  self.direction
}

///|
pub fn HarnessPort::width(self : HarnessPort) -> Int {
  self.width
}

///|
pub fn HarnessPort::signal_type(self : HarnessPort) -> @ir.SignalType {
  self.signal_type
}

///|
/// A path/content pair in canonical bundle order.
pub struct BundleArtifact {
  path : String
  content : String
} derive(Debug, Eq)

///|
pub fn BundleArtifact::path(self : BundleArtifact) -> String {
  self.path
}

///|
pub fn BundleArtifact::content(self : BundleArtifact) -> String {
  self.content
}

///|
/// Pure Phase 3 output. Filesystem policy belongs to a thin caller: artifact
/// generation itself is deterministic, testable, and free of host state.
pub struct FixtureBundle {
  plan : FixturePlan
  design : @ir.Design
  emitted : @systemverilog.EmittedDesign
  ports : ReadOnlyArray[HarnessPort]
  stimulus : @differential.StimulusSequence
  expected : @differential.ObservationSet
  harness_json : String
  harness_cpp : String
  stimulus_tsv : String
  expected_tsv : String
  artifacts : ReadOnlyArray[BundleArtifact]
} derive(Debug, Eq)

///|
pub fn FixtureBundle::plan(self : FixtureBundle) -> FixturePlan {
  self.plan
}

///|
pub fn FixtureBundle::design(self : FixtureBundle) -> @ir.Design {
  self.design
}

///|
pub fn FixtureBundle::emitted(
  self : FixtureBundle,
) -> @systemverilog.EmittedDesign {
  self.emitted
}

///|
pub fn FixtureBundle::ports(self : FixtureBundle) -> ReadOnlyArray[HarnessPort] {
  self.ports
}

///|
pub fn FixtureBundle::stimulus(
  self : FixtureBundle,
) -> @differential.StimulusSequence {
  self.stimulus
}

///|
pub fn FixtureBundle::expected(
  self : FixtureBundle,
) -> @differential.ObservationSet {
  self.expected
}

///|
pub fn FixtureBundle::harness_json(self : FixtureBundle) -> String {
  self.harness_json
}

///|
pub fn FixtureBundle::harness_cpp(self : FixtureBundle) -> String {
  self.harness_cpp
}

///|
pub fn FixtureBundle::stimulus_tsv(self : FixtureBundle) -> String {
  self.stimulus_tsv
}

///|
pub fn FixtureBundle::expected_tsv(self : FixtureBundle) -> String {
  self.expected_tsv
}

///|
pub fn FixtureBundle::artifacts(
  self : FixtureBundle,
) -> ReadOnlyArray[BundleArtifact] {
  self.artifacts
}

///|
pub(all) suberror Phase3Error {
  InvalidCycleCount(Int)
  MissingTopModule
  MissingEmittedTopModule
  MissingPortMapping(kind~ : String, ordinal~ : Int)
  MissingClockPort
  MultipleClockPorts
  MissingResetPort
  MultipleResetPorts
  UnsupportedPortWidth(name~ : String, width~ : Int)
  UnsupportedUnknownExpected(tap~ : String, cycle~ : UInt64)
  InvalidResultTsv(reason~ : String, row~ : Int)
} derive(Debug, Eq)
