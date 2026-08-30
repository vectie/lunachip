///|
pub(all) enum HandshakeFixtureKind {
  DirectedScalar
  MultiLeafRational
  CoincidentRefill
  CoordinatedResetFlush
  SeededRational
} derive(Debug, Eq)

///|
pub fn HandshakeFixtureKind::id(self : HandshakeFixtureKind) -> String {
  match self {
    DirectedScalar => "directed-2-stage-scalar"
    MultiLeafRational => "rational-3-stage-multi-leaf"
    CoincidentRefill => "coincident-4-stage-refill"
    CoordinatedResetFlush => "coordinated-reset-unilateral-flush"
    SeededRational => "seeded-rational-stream"
  }
}

///|
pub fn HandshakeFixtureKind::evidence_class(
  self : HandshakeFixtureKind,
) -> String {
  match self {
    CoordinatedResetFlush => "expected-reset-flush-loss"
    _ => "lossless-coordinated-operation"
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
pub struct HandshakeFixtureBundle {
  kind : HandshakeFixtureKind
  design : @ir.Design
  emitted : @systemverilog.EmittedDesign
  stimulus : @verilator.AtomicStimulus
  expected_tsv : String
  sequential_tsv : String
  artifacts : ReadOnlyArray[BundleArtifact]
} derive(Debug, Eq)

///|
pub fn HandshakeFixtureBundle::kind(
  self : HandshakeFixtureBundle,
) -> HandshakeFixtureKind {
  self.kind
}

///|
pub fn HandshakeFixtureBundle::design(
  self : HandshakeFixtureBundle,
) -> @ir.Design {
  self.design
}

///|
pub fn HandshakeFixtureBundle::emitted(
  self : HandshakeFixtureBundle,
) -> @systemverilog.EmittedDesign {
  self.emitted
}

///|
pub fn HandshakeFixtureBundle::stimulus(
  self : HandshakeFixtureBundle,
) -> @verilator.AtomicStimulus {
  self.stimulus
}

///|
pub fn HandshakeFixtureBundle::expected_tsv(
  self : HandshakeFixtureBundle,
) -> String {
  self.expected_tsv
}

///|
pub fn HandshakeFixtureBundle::sequential_tsv(
  self : HandshakeFixtureBundle,
) -> String {
  self.sequential_tsv
}

///|
pub fn HandshakeFixtureBundle::artifacts(
  self : HandshakeFixtureBundle,
) -> ReadOnlyArray[BundleArtifact] {
  self.artifacts
}

///|
pub(all) suberror HandshakeFixtureError {
  MissingTopModule
  MissingDomainClock(Int)
  MissingPortMapping(String)
  InvalidActualResult(reason~ : String, row~ : Int)
  MissingRequiredNegativeMismatch
  UnexpectedMismatch(AtomicMismatch)
} derive(Debug, Eq)
