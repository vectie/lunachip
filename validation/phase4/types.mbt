///|
pub(all) enum FixtureKind {
  WholeReadOld
  WholeReadNew
  NoChange
  UndefinedSafe
  MaskedWrite
  NonPowerOfTwo
  Enables
  LowerPortIdWins
} derive(Debug, Eq)

///|
pub fn FixtureKind::id(self : FixtureKind) -> String {
  match self {
    WholeReadOld => "whole-read-old"
    WholeReadNew => "whole-read-new"
    NoChange => "no-change"
    UndefinedSafe => "undefined-safe"
    MaskedWrite => "masked-write"
    NonPowerOfTwo => "non-power-of-two"
    Enables => "enables"
    LowerPortIdWins => "lower-port-id-wins"
  }
}

///|
pub(all) enum NegativeFixtureKind {
  FaultOutOfBounds
  DynamicRejectCollision
} derive(Debug, Eq)

///|
pub fn NegativeFixtureKind::id(self : NegativeFixtureKind) -> String {
  match self {
    FaultOutOfBounds => "fault-out-of-bounds"
    DynamicRejectCollision => "dynamic-reject-collision"
  }
}

///|
pub fn NegativeFixtureKind::failure_marker(
  self : NegativeFixtureKind,
) -> String {
  match self {
    FaultOutOfBounds => "lc_mem0_read0_bounds"
    DynamicRejectCollision => "lc_mem0_write0_write1_collision"
  }
}

///|
pub struct FixturePlan {
  kind : FixtureKind
  seed : UInt64
  post_reset_cycles : Int32
} derive(Debug, Eq)

///|
pub fn FixturePlan::checked(
  kind : FixtureKind,
  seed : UInt64,
  post_reset_cycles : Int32,
) -> FixturePlan raise Phase4Error {
  if post_reset_cycles < 1 {
    raise InvalidCycleCount(post_reset_cycles)
  }
  { kind, seed, post_reset_cycles, }
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
pub fn FixturePlan::post_reset_cycles(self : FixturePlan) -> Int32 {
  self.post_reset_cycles
}

///|
pub fn standard_plan() -> ReadOnlyArray[FixturePlan] {
  ReadOnlyArray::from_array([
    {
      kind: WholeReadOld,
      seed: 0x6a09e667f3bcc909UL,
      post_reset_cycles: 13000,
    },
    {
      kind: WholeReadNew,
      seed: 0xbb67ae8584caa73bUL,
      post_reset_cycles: 13000,
    },
    { kind: NoChange, seed: 0x3c6ef372fe94f82bUL, post_reset_cycles: 13000, },
    {
      kind: UndefinedSafe,
      seed: 0xa54ff53a5f1d36f1UL,
      post_reset_cycles: 13000,
    },
    { kind: MaskedWrite, seed: 0x510e527fade682d1UL, post_reset_cycles: 13000, },
    {
      kind: NonPowerOfTwo,
      seed: 0x9b05688c2b3e6c1fUL,
      post_reset_cycles: 13000,
    },
    { kind: Enables, seed: 0x1f83d9abfb41bd6bUL, post_reset_cycles: 13000, },
    {
      kind: LowerPortIdWins,
      seed: 0x5be0cd19137e2179UL,
      post_reset_cycles: 13000,
    },
  ])
}

///|
pub fn total_post_reset_cycles(plans : ArrayView[FixturePlan]) -> Int32 {
  plans.fold(init=0, (sum, plan) => sum + plan.post_reset_cycles)
}

///|
pub(all) struct BundleArtifact {
  path : String
  content : String
} derive(Debug, Eq)

///|
pub struct FixtureBundle {
  plan : FixturePlan
  design : @ir.Design
  emitted : @systemverilog.EmittedDesign
  ports : ReadOnlyArray[@verilator.HarnessPort]
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
pub struct NegativeFixtureBundle {
  kind : NegativeFixtureKind
  artifacts : ReadOnlyArray[BundleArtifact]
  harness_json : String
  stimulus_tsv : String
}

///|
pub fn NegativeFixtureBundle::kind(
  self : NegativeFixtureBundle,
) -> NegativeFixtureKind {
  self.kind
}

///|
pub fn NegativeFixtureBundle::artifacts(
  self : NegativeFixtureBundle,
) -> ReadOnlyArray[BundleArtifact] {
  self.artifacts
}

///|
pub fn NegativeFixtureBundle::harness_json(
  self : NegativeFixtureBundle,
) -> String {
  self.harness_json
}

///|
pub fn NegativeFixtureBundle::stimulus_tsv(
  self : NegativeFixtureBundle,
) -> String {
  self.stimulus_tsv
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
pub fn FixtureBundle::ports(
  self : FixtureBundle,
) -> ReadOnlyArray[@verilator.HarnessPort] {
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
pub(all) suberror Phase4Error {
  InvalidCycleCount(Int32)
  MissingTopModule
  UnknownExpected(tap~ : String, cycle~ : UInt64)
} derive(Debug, Eq)

///|
pub extend FixtureKind with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FixtureKind with Eq::{not_equal, equal}

///|
pub extend NegativeFixtureKind with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend NegativeFixtureKind with Eq::{not_equal, equal}

///|
pub extend FixturePlan with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FixturePlan with Eq::{not_equal, equal}

///|
pub extend BundleArtifact with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend BundleArtifact with Eq::{not_equal, equal}

///|
pub extend FixtureBundle with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FixtureBundle with Eq::{not_equal, equal}

///|
pub extend Phase4Error with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Phase4Error with Eq::{not_equal, equal}
