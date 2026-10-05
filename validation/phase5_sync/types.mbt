///|
pub(all) enum SyncFixtureKind {
  AsyncTwoStage
  TimedThreeStage
  TimedFourStage
} derive(Debug, Eq)

///|
pub fn SyncFixtureKind::id(self : SyncFixtureKind) -> String {
  match self {
    AsyncTwoStage => "async-2-stage-reset"
    TimedThreeStage => "timed-3-stage-coprime"
    TimedFourStage => "timed-4-stage-noncoprime"
  }
}

///|
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
pub struct AtomicMismatch {
  time : UInt64
  boundary : UInt64
  output : String
  expected : String
  actual : String
} derive(Debug, Eq)

///|
pub fn AtomicMismatch::time(self : AtomicMismatch) -> UInt64 {
  self.time
}

///|
pub fn AtomicMismatch::boundary(self : AtomicMismatch) -> UInt64 {
  self.boundary
}

///|
pub fn AtomicMismatch::output(self : AtomicMismatch) -> String {
  self.output
}

///|
pub fn AtomicMismatch::expected(self : AtomicMismatch) -> String {
  self.expected
}

///|
pub fn AtomicMismatch::actual(self : AtomicMismatch) -> String {
  self.actual
}

///|
pub struct SyncFixtureBundle {
  kind : SyncFixtureKind
  design : @ir.Design
  emitted : @systemverilog.EmittedDesign
  stimulus : @verilator.AtomicStimulus
  expected_tsv : String
  sequential_tsv : String
  artifacts : ReadOnlyArray[BundleArtifact]
} derive(Debug, Eq)

///|
pub fn SyncFixtureBundle::kind(self : SyncFixtureBundle) -> SyncFixtureKind {
  self.kind
}

///|
pub fn SyncFixtureBundle::design(self : SyncFixtureBundle) -> @ir.Design {
  self.design
}

///|
pub fn SyncFixtureBundle::emitted(
  self : SyncFixtureBundle,
) -> @systemverilog.EmittedDesign {
  self.emitted
}

///|
pub fn SyncFixtureBundle::stimulus(
  self : SyncFixtureBundle,
) -> @verilator.AtomicStimulus {
  self.stimulus
}

///|
pub fn SyncFixtureBundle::expected_tsv(self : SyncFixtureBundle) -> String {
  self.expected_tsv
}

///|
pub fn SyncFixtureBundle::sequential_tsv(self : SyncFixtureBundle) -> String {
  self.sequential_tsv
}

///|
pub fn SyncFixtureBundle::artifacts(
  self : SyncFixtureBundle,
) -> ReadOnlyArray[BundleArtifact] {
  self.artifacts
}

///|
pub(all) suberror SyncFixtureError {
  MissingTopModule
  MissingDomainClock(Int)
  MissingPortMapping(String)
  InvalidActualResult(reason~ : String, row~ : Int)
  ExpectedExactMatch
  UnexpectedMismatch(AtomicMismatch)
  MissingRequiredNegativeMismatch
} derive(Debug, Eq)

///|
pub extend SyncFixtureKind with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend SyncFixtureKind with Eq::{not_equal, equal}

///|
pub extend BundleArtifact with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend BundleArtifact with Eq::{not_equal, equal}

///|
pub extend AtomicMismatch with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AtomicMismatch with Eq::{not_equal, equal}

///|
pub extend SyncFixtureBundle with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend SyncFixtureBundle with Eq::{not_equal, equal}

///|
pub extend SyncFixtureError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend SyncFixtureError with Eq::{not_equal, equal}
