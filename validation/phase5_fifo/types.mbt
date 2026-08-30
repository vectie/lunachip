///|
/// Canonical Phase 5 asynchronous-FIFO differential fixtures.
pub(all) enum FifoFixtureKind {
  Depth4ScalarTwoStage
  Depth8AggregateThreeStage
  Depth4AsymmetricFourStage
} derive(Debug, Eq)

///|
pub fn FifoFixtureKind::id(self : FifoFixtureKind) -> String {
  match self {
    Depth4ScalarTwoStage => "depth4-coprime-scalar-2stage"
    Depth8AggregateThreeStage => "depth8-noncoprime-aggregate64-3stage"
    Depth4AsymmetricFourStage => "depth4-asymmetric-coincident-4stage"
  }
}

///|
fn FifoFixtureKind::depth(self : FifoFixtureKind) -> Int {
  match self {
    Depth8AggregateThreeStage => 8
    _ => 4
  }
}

///|
fn FifoFixtureKind::stages(self : FifoFixtureKind) -> Int {
  match self {
    Depth4ScalarTwoStage => 2
    Depth8AggregateThreeStage => 3
    Depth4AsymmetricFourStage => 4
  }
}

///|
fn FifoFixtureKind::aggregate(self : FifoFixtureKind) -> Bool {
  self == Depth8AggregateThreeStage
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
struct FifoCoverage {
  enqueues : Int
  dequeues : Int
  enqueue_only : Int
  dequeue_only : Int
  simultaneous : Int
  coincidences : Int
  backpressure : Int
  full_entries : Int
  full_exits : Int
  empty_entries : Int
  empty_exits : Int
  write_wraps : Int
  read_wraps : Int
  source_reset_assertions : Int
  source_reset_releases : Int
  destination_reset_assertions : Int
  destination_reset_releases : Int
} derive(Debug, Eq)

///|
pub struct FifoFixtureBundle {
  expected_tsv : String
  artifacts : ReadOnlyArray[BundleArtifact]
} derive(Debug, Eq)

///|
struct BuiltFifoFixture {
  kind : FifoFixtureKind
  design : @ir.Design
  emitted : @systemverilog.EmittedDesign
  stimulus : @verilator.AtomicStimulus
  expected_tsv : String
  sequential_tsv : String
  coverage : FifoCoverage
  artifacts : ReadOnlyArray[BundleArtifact]
  bundle : FifoFixtureBundle
} derive(Debug, Eq)

///|
pub fn FifoFixtureBundle::artifacts(
  self : FifoFixtureBundle,
) -> ReadOnlyArray[BundleArtifact] {
  self.artifacts
}

///|
suberror FifoFixtureError {
  MissingTopModule
  MissingDomainClock(Int)
  MissingPortMapping(String)
  InvalidActualResult(reason~ : String, row~ : Int)
  LedgerUnderflow(boundary~ : UInt64)
  LedgerMismatch(
    boundary~ : UInt64,
    leaf~ : Int,
    expected~ : UInt64,
    actual~ : UInt64
  )
  IncompleteCoverage(String)
  MissingRequiredNegativeMismatch
  UnexpectedMismatch(AtomicMismatch)
} derive(Debug, Eq)
