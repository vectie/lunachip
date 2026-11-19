///|
/// A deterministic synthesis bundle for one resetless asynchronous-input
/// single-bit synchronizer built through the public LunaWire API.
pub struct CdcSynthesisBundle {
  stage_count : Int32
  design : @ir.Design
  emitted : @systemverilog.EmittedDesign
  expected_shape_json : String
  artifacts : ReadOnlyArray[BundleArtifact]
} derive(Debug, Eq)

///|
pub fn CdcSynthesisBundle::stage_count(self : CdcSynthesisBundle) -> Int32 {
  self.stage_count
}

///|
pub fn CdcSynthesisBundle::design(self : CdcSynthesisBundle) -> @ir.Design {
  self.design
}

///|
pub fn CdcSynthesisBundle::emitted(
  self : CdcSynthesisBundle,
) -> @systemverilog.EmittedDesign {
  self.emitted
}

///|
pub fn CdcSynthesisBundle::expected_shape_json(
  self : CdcSynthesisBundle,
) -> String {
  self.expected_shape_json
}

///|
pub fn CdcSynthesisBundle::artifacts(
  self : CdcSynthesisBundle,
) -> ReadOnlyArray[BundleArtifact] {
  self.artifacts
}

///|
pub fn cdc_bit_synchronizer_stage_counts() -> ReadOnlyArray[Int32] {
  ReadOnlyArray::from_array([2, 3, 4])
}

///|
pub extend CdcSynthesisBundle with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CdcSynthesisBundle with Eq::{not_equal, equal}
