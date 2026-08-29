///|
pub(all) enum SynthesisKind {
  SingleReadOld
  SingleReadNew
  SingleNoChange
  SingleUndefined
  SingleMasked
  MultiwriteLowerPortIdWins
  MultiwriteReject
  Fifo
  BankedMemory
} derive(Debug, Eq)

///|
pub fn SynthesisKind::id(self : SynthesisKind) -> String {
  match self {
    SingleReadOld => "single-read-old"
    SingleReadNew => "single-read-new"
    SingleNoChange => "single-no-change"
    SingleUndefined => "single-undefined"
    SingleMasked => "single-masked"
    MultiwriteLowerPortIdWins => "multiwrite-lower-port-id-wins"
    MultiwriteReject => "multiwrite-reject"
    Fifo => "fifo"
    BankedMemory => "banked-memory"
  }
}

///|
pub fn SynthesisKind::requires_inferred_memory(self : SynthesisKind) -> Bool {
  match self {
    MultiwriteLowerPortIdWins | MultiwriteReject => false
    _ => true
  }
}

///|
pub fn synthesis_matrix() -> ReadOnlyArray[SynthesisKind] {
  ReadOnlyArray::from_array([
    SingleReadOld,
    SingleReadNew,
    SingleNoChange,
    SingleUndefined,
    SingleMasked,
    MultiwriteLowerPortIdWins,
    MultiwriteReject,
    Fifo,
    BankedMemory,
  ])
}

///|
pub(all) struct BundleArtifact {
  path : String
  content : String
} derive(Debug, Eq)

///|
pub struct SynthesisBundle {
  kind : SynthesisKind
  design : @ir.Design
  emitted : @systemverilog.EmittedDesign
  job_json : String
  artifacts : ReadOnlyArray[BundleArtifact]
} derive(Debug, Eq)

///|
pub fn SynthesisBundle::kind(self : SynthesisBundle) -> SynthesisKind {
  self.kind
}

///|
pub fn SynthesisBundle::design(self : SynthesisBundle) -> @ir.Design {
  self.design
}

///|
pub fn SynthesisBundle::emitted(
  self : SynthesisBundle,
) -> @systemverilog.EmittedDesign {
  self.emitted
}

///|
pub fn SynthesisBundle::job_json(self : SynthesisBundle) -> String {
  self.job_json
}

///|
pub fn SynthesisBundle::artifacts(
  self : SynthesisBundle,
) -> ReadOnlyArray[BundleArtifact] {
  self.artifacts
}

///|
pub(all) suberror SynthesisFixtureError {
  MissingTopModule
  MissingEmittedTopModule
} derive(Debug, Eq)
