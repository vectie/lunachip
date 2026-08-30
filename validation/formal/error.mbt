///|
/// Checked failures at the Phase 4 FIFO formal-evidence boundary.
pub(all) suberror FormalGateError {
  MissingTopModule
  MissingPort(kind~ : String, name~ : String)
  DuplicatePort(kind~ : String, name~ : String)
  MissingEmittedTop
  DuplicateEmittedTop
  FormalContract(@formal_core.FormalError)
  PropertyContract(@property.PropertyError)
  MemoryContract(@memory.MemoryComponentError)
  IrContract(@ir.IrError)
  EmitContract(@rtl.EmitError)
  InvalidEvidenceName(String)
  MissingCounterexample(String)
  MissingCoverWitness(String)
  UnexpectedEvidence(String)
  UnsupportedSbyStatus(String)
  TaskPropertyBindingMismatch(String)
  InvalidFormalBundleIdentity(String)
} derive(Debug, Eq)
