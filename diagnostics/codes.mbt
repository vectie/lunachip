///|
/// Stable, machine-readable diagnostic categories.
///
/// Consumers must persist `stable_id()`, never an enum ordinal or debug text.
/// New variants may be added, but an existing stable ID never changes meaning.
pub(all) enum DiagnosticCode {
  InvalidWidth
  InvalidReference
  DuplicateDriver
  MissingDriver
  CombinationalCycle
  TypeMismatch
  WidthMismatch
  InvalidClock
  InvalidConstant
  UnsupportedFeature
  InvalidExternalToolManifest
  InvalidName
  DuplicateName
  InvalidSlice
  InvalidSignedness
  MissingTopModule
  InvalidBuilderState
  InternalInvariantViolation
} derive(Debug, Eq)

///|
/// Return the permanent wire identifier for a diagnostic category.
pub fn DiagnosticCode::stable_id(self : DiagnosticCode) -> String {
  match self {
    InvalidWidth => "LC0001"
    InvalidReference => "LC0002"
    DuplicateDriver => "LC0003"
    MissingDriver => "LC0004"
    CombinationalCycle => "LC0005"
    TypeMismatch => "LC0006"
    WidthMismatch => "LC0007"
    InvalidClock => "LC0008"
    InvalidConstant => "LC0009"
    UnsupportedFeature => "LC0010"
    InvalidExternalToolManifest => "LC0011"
    InvalidName => "LC0012"
    DuplicateName => "LC0013"
    InvalidSlice => "LC0014"
    InvalidSignedness => "LC0015"
    MissingTopModule => "LC0016"
    InvalidBuilderState => "LC0017"
    InternalInvariantViolation => "LC9999"
  }
}

///|
/// User-facing importance. Severity is intentionally independent of code so a
/// policy layer may promote warnings without changing their stable identity.
pub(all) enum Severity {
  Error
  Warning
  Note
} derive(Debug, Eq, Compare)

///|
/// Stable lowercase spelling for machine-readable output.
pub fn Severity::stable_name(self : Severity) -> String {
  match self {
    Error => "error"
    Warning => "warning"
    Note => "note"
  }
}
