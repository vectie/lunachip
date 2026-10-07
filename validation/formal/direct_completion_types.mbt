///|
/// Separate direct-q3 completion inputs; generation is not proof evidence.
///
/// ```mbt check
/// test {
///   assert_eq(
///     @formal.DirectCompletionFixture::from_id(
///       "phase6-flux-tile-direct-q3-eventual-r2-h2-c2-d252",
///     ),
///     Some(Eventual),
///   )
/// }
/// ```
pub(all) enum DirectCompletionFixture {
  Eventual
  UsefulStore
  NegativeDeadline
} derive(Debug, Eq)

///|
pub fn DirectCompletionFixture::id(self : DirectCompletionFixture) -> String {
  match self {
    Eventual => "phase6-flux-tile-direct-q3-eventual-r2-h2-c2-d252"
    UsefulStore => "phase6-flux-tile-direct-q3-useful-store-r2-h2-c2-d252"
    NegativeDeadline => "phase6-flux-tile-direct-q3-negative-deadline1"
  }
}

///|
pub fn DirectCompletionFixture::from_id(
  id : String,
) -> DirectCompletionFixture? {
  match id {
    "phase6-flux-tile-direct-q3-eventual-r2-h2-c2-d252" => Some(Eventual)
    "phase6-flux-tile-direct-q3-useful-store-r2-h2-c2-d252" => Some(UsefulStore)
    "phase6-flux-tile-direct-q3-negative-deadline1" => Some(NegativeDeadline)
    _ => None
  }
}

///|
pub struct DirectCompletionFormalBundle {
  fixture : DirectCompletionFixture
  artifacts : ReadOnlyArray[FormalBundleArtifact]
  tasks : ReadOnlyArray[GateTask]
  job_json : String
  top_identifier : String
  expected_failure : String
} derive(Debug, Eq)

///|
pub fn DirectCompletionFormalBundle::fixture(
  self : DirectCompletionFormalBundle,
) -> DirectCompletionFixture {
  self.fixture
}

///|
pub fn DirectCompletionFormalBundle::artifacts(
  self : DirectCompletionFormalBundle,
) -> ReadOnlyArray[FormalBundleArtifact] {
  self.artifacts
}

///|
pub fn DirectCompletionFormalBundle::tasks(
  self : DirectCompletionFormalBundle,
) -> ReadOnlyArray[GateTask] {
  self.tasks
}

///|
pub fn DirectCompletionFormalBundle::job_json(
  self : DirectCompletionFormalBundle,
) -> String {
  self.job_json
}

///|
pub fn DirectCompletionFormalBundle::top_identifier(
  self : DirectCompletionFormalBundle,
) -> String {
  self.top_identifier
}

///|
pub fn DirectCompletionFormalBundle::expected_failure(
  self : DirectCompletionFormalBundle,
) -> String {
  self.expected_failure
}

///|
// Arithmetic reproduces the documented proposed allowance, not a proof of it.
fn direct_completion_deadline() -> Int {
  let request_bound = 2
  let response_bound = 2
  let completion_bound = 2
  let transaction = request_bound + response_bound + 2
  let load = 4 * transaction + 4
  let store = 2 * transaction + 4
  let compute = 8
  let engine = if load > store && load > compute {
    load
  } else if store > compute {
    store
  } else {
    compute
  }
  7 * (4 + engine + completion_bound + 2)
}

///|
// Canonical V2 slot-zero packets, all with the deliberately repeated caller ID73.
// Ordinary symbolic watches do not restrict IDs or require canonical syntax.
fn direct_completion_packet(index : Int) -> Array[UInt64] raise FormalGateError {
  let (opcode, rows, columns, reduction, base, stride) : (
    UInt64,
    UInt64,
    UInt64,
    UInt64,
    UInt64,
    UInt64,
  ) = match index {
    0 => (0UL, 1UL, 2UL, 0UL, 32UL, 2UL)
    1 => (1UL, 2UL, 1UL, 0UL, 64UL, 1UL)
    2 => (2UL, 1UL, 1UL, 2UL, 0UL, 0UL)
    3 => (3UL, 1UL, 1UL, 0UL, 128UL, 4UL)
    _ =>
      raise InvalidFormalBundleIdentity(
        "direct completion: canonical packet index",
      )
  }
  [
    (73UL << 32) | (opcode << 16) | 0x200UL,
    rows | (columns << 16) | (reduction << 32),
    base | (stride << 32),
    0UL,
  ]
}

///|
fn direct_completion_packet_literal(
  index : Int,
) -> String raise FormalGateError {
  let lanes = direct_completion_packet(index)
  "{64'd\{lanes[3]}, 64'd\{lanes[2]}, 64'd\{lanes[1]}, 64'd\{lanes[0]}}"
}

///|
pub extend DirectCompletionFixture with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend DirectCompletionFixture with Eq::{not_equal, equal}

///|
pub extend DirectCompletionFormalBundle with @moonbitlang/core/debug.Debug::{
  to_repr,
}

///|
pub extend DirectCompletionFormalBundle with Eq::{not_equal, equal}
