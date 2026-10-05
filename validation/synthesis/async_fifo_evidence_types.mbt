///|
enum AsyncFifoEvidenceCheckStatus {
  EvidenceCheckPass
  EvidenceCheckFail
} derive(Debug, Eq)

///|
struct AsyncFifoEvidenceCheck {
  name : String
  status : AsyncFifoEvidenceCheckStatus
} derive(Debug, Eq)

///|
struct AsyncFifoEvidenceInputBinding {
  sha256 : String
  bytes : Int
  nonempty : Bool
} derive(Debug, Eq)

///|
struct AsyncFifoEvidenceInputs {
  inventory_json : AsyncFifoEvidenceInputBinding
  pre_map_json : AsyncFifoEvidenceInputBinding
  pre_map_rtlil : AsyncFifoEvidenceInputBinding
  yosys_lock : AsyncFifoEvidenceInputBinding
} derive(Debug, Eq)

///|
struct AsyncFifoEvidenceCounts {
  checks_total : Int
  checks_passed : Int
  checks_failed : Int
  issues : Int
  sequential_bits : Int
  memory_bits : Int
} derive(Debug, Eq)

///|
struct AsyncFifoEvidenceClaims {
  pre_map_typed_graph : Bool
  two_state_role_equivalence : Bool
  owned_state_exact : Bool
  memory_topology : Bool
  ram_mapping : Bool
  timing : Bool
  physical_cdc : Bool
  metastability : Bool
  four_state_equivalence : Bool
} derive(Debug, Eq)

///|
/// Final, provenance-bound Phase 5 asynchronous-FIFO synthesis evidence.
/// This is distinct from `AsyncFifoPreMapReport`, whose serializer remains an
/// intentionally incomplete diagnostic artifact.
pub struct AsyncFifoSynthesisEvidenceReport {
  fixture : String
  top_module : String
  yosys_creator : String
  inputs : AsyncFifoEvidenceInputs
  checks : Array[AsyncFifoEvidenceCheck]
  issues : Array[AsyncFifoPreMapIssue]
  counts : AsyncFifoEvidenceCounts
  claims : AsyncFifoEvidenceClaims
  pass : Bool
} derive(Debug, Eq)

///|
pub fn AsyncFifoSynthesisEvidenceReport::passed(
  self : AsyncFifoSynthesisEvidenceReport,
) -> Bool {
  self.pass
}

///|
pub fn AsyncFifoSynthesisEvidenceReport::issues(
  self : AsyncFifoSynthesisEvidenceReport,
) -> ReadOnlyArray[AsyncFifoPreMapIssue] {
  ReadOnlyArray::from_array(self.issues)
}

///|
pub extend AsyncFifoEvidenceCheckStatus with @moonbitlang/core/debug.Debug::{
  to_repr,
}

///|
pub extend AsyncFifoEvidenceCheckStatus with Eq::{not_equal, equal}

///|
pub extend AsyncFifoEvidenceCheck with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AsyncFifoEvidenceCheck with Eq::{not_equal, equal}

///|
pub extend AsyncFifoEvidenceInputBinding with @moonbitlang/core/debug.Debug::{
  to_repr,
}

///|
pub extend AsyncFifoEvidenceInputBinding with Eq::{not_equal, equal}

///|
pub extend AsyncFifoEvidenceInputs with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AsyncFifoEvidenceInputs with Eq::{not_equal, equal}

///|
pub extend AsyncFifoEvidenceCounts with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AsyncFifoEvidenceCounts with Eq::{not_equal, equal}

///|
pub extend AsyncFifoEvidenceClaims with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AsyncFifoEvidenceClaims with Eq::{not_equal, equal}

///|
pub extend AsyncFifoSynthesisEvidenceReport with @moonbitlang/core/debug.Debug::{
  to_repr,
}

///|
pub extend AsyncFifoSynthesisEvidenceReport with Eq::{not_equal, equal}
