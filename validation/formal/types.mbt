///|
/// Isolated FIFO proof targets. Negative targets are separate source bundles,
/// so their deliberate defects cannot affect the valid FIFO proof.
pub(all) enum FifoFormalFixture {
  ValidFifo
  BrokenFifoData
  BrokenResponseProtocol
  BrokenBounds
} derive(Debug, Eq)

///|
pub fn FifoFormalFixture::id(self : FifoFormalFixture) -> String {
  match self {
    ValidFifo => "valid-fifo"
    BrokenFifoData => "broken-fifo-data"
    BrokenResponseProtocol => "broken-response-protocol"
    BrokenBounds => "broken-bounds"
  }
}

///|
pub fn FifoFormalFixture::from_id(id : String) -> FifoFormalFixture? {
  match id {
    "valid-fifo" => Some(ValidFifo)
    "broken-fifo-data" => Some(BrokenFifoData)
    "broken-response-protocol" => Some(BrokenResponseProtocol)
    "broken-bounds" => Some(BrokenBounds)
    _ => None
  }
}

///|
pub(all) enum GateTaskClass {
  BoundedSafetyTask
  UnboundedSafetyTask
  BoundedCoverTask
} derive(Debug, Eq)

///|
pub struct GateTask {
  name : String
  task : @formal_core.ProofTaskManifest
  task_class : GateTaskClass
  bound : Int
  timeout_seconds : Int
  expected_status : String
} derive(Debug, Eq)

///|
pub fn GateTask::name(self : GateTask) -> String {
  self.name
}

///|
pub fn GateTask::task(self : GateTask) -> @formal_core.ProofTaskManifest {
  self.task
}

///|
pub fn GateTask::task_class(self : GateTask) -> GateTaskClass {
  self.task_class
}

///|
pub fn GateTask::bound(self : GateTask) -> Int {
  self.bound
}

///|
pub fn GateTask::timeout_seconds(self : GateTask) -> Int {
  self.timeout_seconds
}

///|
pub fn GateTask::expected_status(self : GateTask) -> String {
  self.expected_status
}

///|
pub(all) struct FormalBundleArtifact {
  path : String
  content : String
} derive(Debug, Eq)

///|
pub fn FormalBundleArtifact::path(self : FormalBundleArtifact) -> String {
  self.path
}

///|
pub fn FormalBundleArtifact::content(self : FormalBundleArtifact) -> String {
  self.content
}

///|
pub struct FifoFormalBundle {
  fixture : FifoFormalFixture
  artifacts : ReadOnlyArray[FormalBundleArtifact]
  tasks : ReadOnlyArray[GateTask]
  job_json : String
  top_identifier : String
} derive(Debug, Eq)

///|
pub fn FifoFormalBundle::fixture(self : FifoFormalBundle) -> FifoFormalFixture {
  self.fixture
}

///|
pub fn FifoFormalBundle::artifacts(
  self : FifoFormalBundle,
) -> ReadOnlyArray[FormalBundleArtifact] {
  self.artifacts
}

///|
pub fn FifoFormalBundle::tasks(
  self : FifoFormalBundle,
) -> ReadOnlyArray[GateTask] {
  self.tasks
}

///|
pub fn FifoFormalBundle::job_json(self : FifoFormalBundle) -> String {
  self.job_json
}

///|
pub fn FifoFormalBundle::top_identifier(self : FifoFormalBundle) -> String {
  self.top_identifier
}

///|
/// Isolated three-stage synchronizer proof targets. Each negative fixture
/// corrupts only one checked predicate in its own generated harness.
pub(all) enum SynchronizerFormalFixture {
  ValidSynchronizer
  BrokenSynchronizerPipeline
  BrokenSynchronizerDestinationEdge
  BrokenSynchronizerConvergence
} derive(Debug, Eq)

///|
pub fn SynchronizerFormalFixture::id(
  self : SynchronizerFormalFixture,
) -> String {
  match self {
    ValidSynchronizer => "valid-synchronizer"
    BrokenSynchronizerPipeline => "broken-synchronizer-pipeline"
    BrokenSynchronizerDestinationEdge => "broken-synchronizer-destination-edge"
    BrokenSynchronizerConvergence => "broken-synchronizer-convergence"
  }
}

///|
pub fn SynchronizerFormalFixture::from_id(
  id : String,
) -> SynchronizerFormalFixture? {
  match id {
    "valid-synchronizer" => Some(ValidSynchronizer)
    "broken-synchronizer-pipeline" => Some(BrokenSynchronizerPipeline)
    "broken-synchronizer-destination-edge" =>
      Some(BrokenSynchronizerDestinationEdge)
    "broken-synchronizer-convergence" => Some(BrokenSynchronizerConvergence)
    _ => None
  }
}

///|
pub struct SynchronizerFormalBundle {
  fixture : SynchronizerFormalFixture
  artifacts : ReadOnlyArray[FormalBundleArtifact]
  tasks : ReadOnlyArray[GateTask]
  job_json : String
  top_identifier : String
  expected_failure : String
} derive(Debug, Eq)

///|
pub fn SynchronizerFormalBundle::fixture(
  self : SynchronizerFormalBundle,
) -> SynchronizerFormalFixture {
  self.fixture
}

///|
pub fn SynchronizerFormalBundle::artifacts(
  self : SynchronizerFormalBundle,
) -> ReadOnlyArray[FormalBundleArtifact] {
  self.artifacts
}

///|
pub fn SynchronizerFormalBundle::tasks(
  self : SynchronizerFormalBundle,
) -> ReadOnlyArray[GateTask] {
  self.tasks
}

///|
pub fn SynchronizerFormalBundle::job_json(
  self : SynchronizerFormalBundle,
) -> String {
  self.job_json
}

///|
pub fn SynchronizerFormalBundle::top_identifier(
  self : SynchronizerFormalBundle,
) -> String {
  self.top_identifier
}

///|
pub fn SynchronizerFormalBundle::expected_failure(
  self : SynchronizerFormalBundle,
) -> String {
  self.expected_failure
}

///|
pub(all) enum SbyEvidenceKind {
  BaseCounterexampleTrace
  InductionDiagnosticTrace
  CoverWitnessTrace
} derive(Debug, Eq)

///|
pub(all) struct SbyEvidence {
  kind : SbyEvidenceKind
  name : String
  content : String
} derive(Debug, Eq)

///|
pub fn SbyEvidence::checked(
  kind : SbyEvidenceKind,
  name : String,
  content : String,
) -> SbyEvidence raise FormalGateError {
  if name.is_empty() ||
    name.has_prefix("/") ||
    name.contains("\\") ||
    name.split("/").any(part => part is "" || part is "." || part is "..") {
    raise InvalidEvidenceName(name)
  }
  { kind, name, content, }
}

///|
pub fn SbyEvidence::kind(self : SbyEvidence) -> SbyEvidenceKind {
  self.kind
}

///|
pub fn SbyEvidence::name(self : SbyEvidence) -> String {
  self.name
}

///|
pub fn SbyEvidence::content(self : SbyEvidence) -> String {
  self.content
}

///|
/// A typed proof result plus the exact retained SBY trace, when present.
/// Induction diagnostics remain attached even though their proof outcome is
/// inconclusive rather than a reachable counterexample.
pub struct MappedSbyResult {
  result : @formal_core.ProofResultManifest
  evidence : @formal_core.ArtifactRef?
} derive(Debug, Eq)

///|
pub fn MappedSbyResult::result(
  self : MappedSbyResult,
) -> @formal_core.ProofResultManifest {
  self.result
}

///|
pub fn MappedSbyResult::evidence(
  self : MappedSbyResult,
) -> @formal_core.ArtifactRef? {
  self.evidence
}

///|
pub extend FifoFormalFixture with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FifoFormalFixture with Eq::{not_equal, equal}

///|
pub extend GateTaskClass with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend GateTaskClass with Eq::{not_equal, equal}

///|
pub extend GateTask with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend GateTask with Eq::{not_equal, equal}

///|
pub extend FormalBundleArtifact with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FormalBundleArtifact with Eq::{not_equal, equal}

///|
pub extend FifoFormalBundle with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FifoFormalBundle with Eq::{not_equal, equal}

///|
pub extend SynchronizerFormalFixture with @moonbitlang/core/debug.Debug::{
  to_repr,
}

///|
pub extend SynchronizerFormalFixture with Eq::{not_equal, equal}

///|
pub extend SynchronizerFormalBundle with @moonbitlang/core/debug.Debug::{
  to_repr,
}

///|
pub extend SynchronizerFormalBundle with Eq::{not_equal, equal}

///|
pub extend SbyEvidenceKind with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend SbyEvidenceKind with Eq::{not_equal, equal}

///|
pub extend SbyEvidence with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend SbyEvidence with Eq::{not_equal, equal}

///|
pub extend MappedSbyResult with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend MappedSbyResult with Eq::{not_equal, equal}
