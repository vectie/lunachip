///|
/// Public-pin transport checks on the unchanged predefined 1x1/K2 fetched
/// device. Negative fixtures mutate a harness observation, not production RTL.
pub(all) enum FluxTileFormalFixture {
  PublicTransport
  NegativeRequestBounds
  NegativeRequestStability
} derive(Debug, Eq)

///|
pub fn FluxTileFormalFixture::id(self : FluxTileFormalFixture) -> String {
  match self {
    PublicTransport => "phase6-flux-tile-public-transport"
    NegativeRequestBounds => "phase6-flux-tile-negative-request-bounds"
    NegativeRequestStability => "phase6-flux-tile-negative-request-stability"
  }
}

///|
pub fn FluxTileFormalFixture::from_id(id : String) -> FluxTileFormalFixture? {
  match id {
    "phase6-flux-tile-public-transport" => Some(PublicTransport)
    "phase6-flux-tile-negative-request-bounds" => Some(NegativeRequestBounds)
    "phase6-flux-tile-negative-request-stability" =>
      Some(NegativeRequestStability)
    _ => None
  }
}

///|
pub struct FluxTileFormalBundle {
  fixture : FluxTileFormalFixture
  artifacts : ReadOnlyArray[FormalBundleArtifact]
  tasks : ReadOnlyArray[GateTask]
  job_json : String
  top_identifier : String
  expected_failure : String
} derive(Debug, Eq)

///|
pub fn FluxTileFormalBundle::fixture(
  self : FluxTileFormalBundle,
) -> FluxTileFormalFixture {
  self.fixture
}

///|
pub fn FluxTileFormalBundle::artifacts(
  self : FluxTileFormalBundle,
) -> ReadOnlyArray[FormalBundleArtifact] {
  self.artifacts
}

///|
pub fn FluxTileFormalBundle::tasks(
  self : FluxTileFormalBundle,
) -> ReadOnlyArray[GateTask] {
  self.tasks
}

///|
pub fn FluxTileFormalBundle::job_json(self : FluxTileFormalBundle) -> String {
  self.job_json
}

///|
pub fn FluxTileFormalBundle::top_identifier(
  self : FluxTileFormalBundle,
) -> String {
  self.top_identifier
}

///|
pub fn FluxTileFormalBundle::expected_failure(
  self : FluxTileFormalBundle,
) -> String {
  self.expected_failure
}

///|
pub extend FluxTileFormalFixture with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FluxTileFormalFixture with Eq::{not_equal, equal}

///|
pub extend FluxTileFormalBundle with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FluxTileFormalBundle with Eq::{not_equal, equal}
