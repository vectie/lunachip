///|
/// Remaining groups are deliberately not represented by booleans supplied by
/// callers. This reconciliation cannot promote cover evidence to a phase pass.
pub(all) enum Phase6OpenGate {
  FetchedSymbolicSafetyAddressAndDependency
  ExplicitFairness8x8Completion
  RemainingWorkloadFaultAndSynthesisMatrix
  SameSnapshotFinalNativeAndToolAggregate
} derive(Debug, Eq)

///|
pub extend Phase6OpenGate with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Phase6OpenGate with Eq::{equal, not_equal}

///|
pub struct Phase6EvidenceAggregate {
  fetched_store : FetchedStoreWitnessReceipt
}

///|
pub fn Phase6EvidenceAggregate::with_fetched_store(
  receipt : FetchedStoreWitnessReceipt,
) -> Phase6EvidenceAggregate {
  { fetched_store: receipt, }
}

///|
/// Open groups are not an estimate of the number of proof tasks left.
///
/// ```mbt check
/// test {
///   assert_eq(@phase6_evidence.remaining_gates().length(), 4)
/// }
/// ```
pub fn remaining_gates() -> ReadOnlyArray[Phase6OpenGate] {
  [
    FetchedSymbolicSafetyAddressAndDependency,
    ExplicitFairness8x8Completion,
    RemainingWorkloadFaultAndSynthesisMatrix,
    SameSnapshotFinalNativeAndToolAggregate,
  ]
}

///|
pub fn Phase6EvidenceAggregate::phase6_passed(
  _self : Phase6EvidenceAggregate,
) -> Bool {
  false
}

///|
pub fn Phase6EvidenceAggregate::to_canonical_text(
  self : Phase6EvidenceAggregate,
) -> String {
  let pin = digest(self.fetched_store.to_canonical_text())
  "LUNACHIP-PHASE6-EVIDENCE-AGGREGATE 1\n" +
  "KIND partial-reconciliation-not-final-phase-gate\nSTATE incomplete\n" +
  "ACCEPTED fetched-useful-Store-existential-cover receipt.sha256 \{pin}\n" +
  "OPEN fetched-symbolic-safety-address-and-dependency\n" +
  "OPEN explicit-fairness8x8-completion\n" +
  "OPEN remaining-workload-fault-and-synthesis-matrix\n" +
  "OPEN same-snapshot-final-native-and-tool-aggregate\n" +
  "HISTORICAL Store-and-packet-safety-accepted-scopes-unchanged-not-recollected\n" +
  "HISTORICAL prior-failures-and-timeouts-retained-not-replaced\n" +
  "PHASE6-PASS false\nEND\n"
}
