///|
/// Dependency-only bounded monitors on the unchanged direct 1x1/K2/q3 graph.
/// Negative fixtures alter comparison observations, not hardware or assumptions.
pub(all) enum DependencyFormalFixture {
  LatestWriter
  LatestWriterGenerationSupport
  NegativeFailedGeneration
  NegativeNewIntentPriority
  NegativeInnerIdentity
} derive(Debug, Eq)

///|
pub fn DependencyFormalFixture::id(self : DependencyFormalFixture) -> String {
  match self {
    LatestWriter => "phase6-dependency-latest-writer"
    LatestWriterGenerationSupport => "phase6-dependency-generation-support"
    NegativeFailedGeneration => "phase6-dependency-negative-failed-generation"
    NegativeNewIntentPriority =>
      "phase6-dependency-negative-new-intent-priority"
    NegativeInnerIdentity => "phase6-dependency-negative-inner-identity"
  }
}

///|
pub fn DependencyFormalFixture::from_id(
  id : String,
) -> DependencyFormalFixture? {
  match id {
    "phase6-dependency-latest-writer" => Some(LatestWriter)
    "phase6-dependency-generation-support" =>
      Some(LatestWriterGenerationSupport)
    "phase6-dependency-negative-failed-generation" =>
      Some(NegativeFailedGeneration)
    "phase6-dependency-negative-new-intent-priority" =>
      Some(NegativeNewIntentPriority)
    "phase6-dependency-negative-inner-identity" => Some(NegativeInnerIdentity)
    _ => None
  }
}

///|
pub struct DependencyFormalBundle {
  fixture : DependencyFormalFixture
  artifacts : ReadOnlyArray[FormalBundleArtifact]
  tasks : ReadOnlyArray[GateTask]
  job_json : String
  top_identifier : String
  expected_failure : String
} derive(Debug, Eq)

///|
pub fn DependencyFormalBundle::fixture(
  self : DependencyFormalBundle,
) -> DependencyFormalFixture {
  self.fixture
}

///|
pub fn DependencyFormalBundle::artifacts(
  self : DependencyFormalBundle,
) -> ReadOnlyArray[FormalBundleArtifact] {
  self.artifacts
}

///|
pub fn DependencyFormalBundle::tasks(
  self : DependencyFormalBundle,
) -> ReadOnlyArray[GateTask] {
  self.tasks
}

///|
pub fn DependencyFormalBundle::job_json(
  self : DependencyFormalBundle,
) -> String {
  self.job_json
}

///|
pub fn DependencyFormalBundle::top_identifier(
  self : DependencyFormalBundle,
) -> String {
  self.top_identifier
}

///|
pub fn DependencyFormalBundle::expected_failure(
  self : DependencyFormalBundle,
) -> String {
  self.expected_failure
}

///|
pub extend DependencyFormalFixture with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend DependencyFormalFixture with Eq::{not_equal, equal}

///|
pub extend DependencyFormalBundle with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend DependencyFormalBundle with Eq::{not_equal, equal}
