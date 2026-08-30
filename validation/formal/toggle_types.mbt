///|
/// Toggle-handshake proof targets. The three valid fixtures bind the public
/// constructor with two, three, and four synchronizer stages. Every negative
/// fixture preserves the production design and exported predicates while
/// mutating exactly one monitored behavior path around the identical
/// three-stage record design.
pub(all) enum ToggleFormalFixture {
  ValidToggleScalar2
  ValidToggleRecord3
  ValidToggleRecord4
  BrokenToggleCapacity
  BrokenToggleSourcePayload
  BrokenToggleBackpressure
  BrokenToggleDuplicate
  BrokenToggleDataIntegrity
  BrokenToggleCompletion
} derive(Debug, Eq)

///|
pub fn ToggleFormalFixture::id(self : ToggleFormalFixture) -> String {
  match self {
    ValidToggleScalar2 => "valid-toggle-scalar-2"
    ValidToggleRecord3 => "valid-toggle-record-3"
    ValidToggleRecord4 => "valid-toggle-record-4"
    BrokenToggleCapacity => "broken-toggle-capacity"
    BrokenToggleSourcePayload => "broken-toggle-source-payload"
    BrokenToggleBackpressure => "broken-toggle-backpressure"
    BrokenToggleDuplicate => "broken-toggle-duplicate"
    BrokenToggleDataIntegrity => "broken-toggle-data-integrity"
    BrokenToggleCompletion => "broken-toggle-completion"
  }
}

///|
pub fn ToggleFormalFixture::from_id(id : String) -> ToggleFormalFixture? {
  match id {
    "valid-toggle-scalar-2" => Some(ValidToggleScalar2)
    "valid-toggle-record-3" => Some(ValidToggleRecord3)
    "valid-toggle-record-4" => Some(ValidToggleRecord4)
    "broken-toggle-capacity" => Some(BrokenToggleCapacity)
    "broken-toggle-source-payload" => Some(BrokenToggleSourcePayload)
    "broken-toggle-backpressure" => Some(BrokenToggleBackpressure)
    "broken-toggle-duplicate" => Some(BrokenToggleDuplicate)
    "broken-toggle-data-integrity" => Some(BrokenToggleDataIntegrity)
    "broken-toggle-completion" => Some(BrokenToggleCompletion)
    _ => None
  }
}

///|
fn ToggleFormalFixture::stage_count(self : ToggleFormalFixture) -> Int {
  match self {
    ValidToggleScalar2 => 2
    ValidToggleRecord4 => 4
    _ => 3
  }
}

///|
fn ToggleFormalFixture::has_record_payload(self : ToggleFormalFixture) -> Bool {
  self != ValidToggleScalar2
}

///|
fn ToggleFormalFixture::is_valid(self : ToggleFormalFixture) -> Bool {
  match self {
    ValidToggleScalar2 | ValidToggleRecord3 | ValidToggleRecord4 => true
    _ => false
  }
}

///|
pub struct ToggleFormalBundle {
  fixture : ToggleFormalFixture
  artifacts : ReadOnlyArray[FormalBundleArtifact]
  tasks : ReadOnlyArray[GateTask]
  job_json : String
  top_identifier : String
  expected_failure : String
  completion_bound : Int
} derive(Debug, Eq)

///|
pub fn ToggleFormalBundle::fixture(
  self : ToggleFormalBundle,
) -> ToggleFormalFixture {
  self.fixture
}

///|
pub fn ToggleFormalBundle::artifacts(
  self : ToggleFormalBundle,
) -> ReadOnlyArray[FormalBundleArtifact] {
  self.artifacts
}

///|
pub fn ToggleFormalBundle::tasks(
  self : ToggleFormalBundle,
) -> ReadOnlyArray[GateTask] {
  self.tasks
}

///|
pub fn ToggleFormalBundle::job_json(self : ToggleFormalBundle) -> String {
  self.job_json
}

///|
pub fn ToggleFormalBundle::top_identifier(self : ToggleFormalBundle) -> String {
  self.top_identifier
}

///|
pub fn ToggleFormalBundle::expected_failure(
  self : ToggleFormalBundle,
) -> String {
  self.expected_failure
}

///|
pub fn ToggleFormalBundle::completion_bound(self : ToggleFormalBundle) -> Int {
  self.completion_bound
}
