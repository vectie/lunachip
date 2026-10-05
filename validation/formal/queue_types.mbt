///|
/// Structural queue conservation on the unchanged direct 1x1/K2/q3 device.
/// The negative fixture changes only a monitor comparison, not the hardware.
pub(all) enum QueueFormalFixture {
  Conservation
  NegativePopulation
} derive(Debug, Eq)

///|
pub fn QueueFormalFixture::id(self : QueueFormalFixture) -> String {
  match self {
    Conservation => "phase6-queue-conservation"
    NegativePopulation => "phase6-queue-negative-population"
  }
}

///|
pub fn QueueFormalFixture::from_id(id : String) -> QueueFormalFixture? {
  match id {
    "phase6-queue-conservation" => Some(Conservation)
    "phase6-queue-negative-population" => Some(NegativePopulation)
    _ => None
  }
}

///|
pub struct QueueFormalBundle {
  fixture : QueueFormalFixture
  artifacts : ReadOnlyArray[FormalBundleArtifact]
  tasks : ReadOnlyArray[GateTask]
  job_json : String
  top_identifier : String
  expected_failure : String
} derive(Debug, Eq)

///|
pub fn QueueFormalBundle::fixture(
  self : QueueFormalBundle,
) -> QueueFormalFixture {
  self.fixture
}

///|
pub fn QueueFormalBundle::artifacts(
  self : QueueFormalBundle,
) -> ReadOnlyArray[FormalBundleArtifact] {
  self.artifacts
}

///|
pub fn QueueFormalBundle::tasks(
  self : QueueFormalBundle,
) -> ReadOnlyArray[GateTask] {
  self.tasks
}

///|
pub fn QueueFormalBundle::job_json(self : QueueFormalBundle) -> String {
  self.job_json
}

///|
pub fn QueueFormalBundle::top_identifier(self : QueueFormalBundle) -> String {
  self.top_identifier
}

///|
pub fn QueueFormalBundle::expected_failure(self : QueueFormalBundle) -> String {
  self.expected_failure
}

///|
pub extend QueueFormalFixture with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend QueueFormalFixture with Eq::{not_equal, equal}

///|
pub extend QueueFormalBundle with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend QueueFormalBundle with Eq::{not_equal, equal}
