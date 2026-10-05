///|
/// Public-API fixture variants for toggle-handshake synthesis evidence.
pub(all) enum ToggleSynthesisKind {
  Scalar2Stage
  Record3Stage
  Record4Stage
} derive(Debug, Eq)

///|
pub fn ToggleSynthesisKind::id(self : ToggleSynthesisKind) -> String {
  match self {
    Scalar2Stage => "toggle-scalar-2-stage"
    Record3Stage => "toggle-record-3-stage"
    Record4Stage => "toggle-record-4-stage"
  }
}

///|
pub fn ToggleSynthesisKind::stage_count(self : ToggleSynthesisKind) -> Int {
  match self {
    Scalar2Stage => 2
    Record3Stage => 3
    Record4Stage => 4
  }
}

///|
pub fn ToggleSynthesisKind::payload_leaf_count(
  self : ToggleSynthesisKind,
) -> Int {
  match self {
    Scalar2Stage => 1
    Record3Stage | Record4Stage => 2
  }
}

///|
pub fn toggle_synthesis_matrix() -> ReadOnlyArray[ToggleSynthesisKind] {
  ReadOnlyArray::from_array([Scalar2Stage, Record3Stage, Record4Stage])
}

///|
pub struct ToggleSynthesisBundle {
  kind : ToggleSynthesisKind
  design : @ir.Design
  emitted : @systemverilog.EmittedDesign
  expected_shape_json : String
  artifacts : ReadOnlyArray[BundleArtifact]
} derive(Debug, Eq)

///|
pub fn ToggleSynthesisBundle::kind(
  self : ToggleSynthesisBundle,
) -> ToggleSynthesisKind {
  self.kind
}

///|
pub fn ToggleSynthesisBundle::design(
  self : ToggleSynthesisBundle,
) -> @ir.Design {
  self.design
}

///|
pub fn ToggleSynthesisBundle::emitted(
  self : ToggleSynthesisBundle,
) -> @systemverilog.EmittedDesign {
  self.emitted
}

///|
pub fn ToggleSynthesisBundle::expected_shape_json(
  self : ToggleSynthesisBundle,
) -> String {
  self.expected_shape_json
}

///|
pub fn ToggleSynthesisBundle::artifacts(
  self : ToggleSynthesisBundle,
) -> ReadOnlyArray[BundleArtifact] {
  self.artifacts
}

///|
pub extend ToggleSynthesisKind with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ToggleSynthesisKind with Eq::{not_equal, equal}

///|
pub extend ToggleSynthesisBundle with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ToggleSynthesisBundle with Eq::{not_equal, equal}
