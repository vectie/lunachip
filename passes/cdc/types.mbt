///|
/// Canonical data provenance. Domain IDs are sorted and unique; asynchronous
/// provenance is independent, so async-plus-domain information is never lost.
pub struct CdcProvenance {
  has_asynchronous : Bool
  domains : ReadOnlyArray[@ir.ClockDomainId]
} derive(Debug, Eq)

///|
pub fn CdcProvenance::has_asynchronous(self : CdcProvenance) -> Bool {
  self.has_asynchronous
}

///|
pub fn CdcProvenance::domains(
  self : CdcProvenance,
) -> ReadOnlyArray[@ir.ClockDomainId] {
  self.domains
}

///|
pub fn CdcProvenance::is_neutral(self : CdcProvenance) -> Bool {
  !self.has_asynchronous && self.domains.is_empty()
}

///|
/// The canonical origin retained for one minimal provenance witness.
pub(all) enum CdcOrigin {
  AsynchronousInput(@ir.NodeId)
  TimedInput(input~ : @ir.NodeId, domain~ : @ir.ClockDomainId)
  RegisterState(node~ : @ir.NodeId, domain~ : @ir.ClockDomainId)
  MemoryReadState(
    node~ : @ir.NodeId,
    memory~ : @ir.MemoryId,
    port~ : @ir.MemoryReadPortId,
    domain~ : @ir.ClockDomainId
  )
  AsyncFifoReadState(
    node~ : @ir.NodeId,
    primitive~ : @ir.CdcPrimitiveId,
    leaf~ : Int32,
    domain~ : @ir.ClockDomainId
  )
} derive(Debug, Eq)

///|
/// One deterministic source-to-consumer node path.
pub struct CdcWitness {
  origin : CdcOrigin
  path : ReadOnlyArray[@ir.NodeId]
} derive(Debug, Eq)

///|
pub fn CdcWitness::origin(self : CdcWitness) -> CdcOrigin {
  self.origin
}

///|
pub fn CdcWitness::path(self : CdcWitness) -> ReadOnlyArray[@ir.NodeId] {
  self.path
}

///|
/// The exact structural sink role that rejected a dependency.
pub(all) enum CdcSink {
  RegisterNext(@ir.NodeId)
  RegisterEnable(@ir.NodeId)
  SynchronousReset(@ir.NodeId)
  AsynchronousReset(@ir.NodeId)
  MemoryReadAddress(memory~ : @ir.MemoryId, port~ : @ir.MemoryReadPortId)
  MemoryReadEnable(memory~ : @ir.MemoryId, port~ : @ir.MemoryReadPortId)
  MemoryWriteAddress(memory~ : @ir.MemoryId, port~ : @ir.MemoryWritePortId)
  MemoryWriteData(memory~ : @ir.MemoryId, port~ : @ir.MemoryWritePortId)
  MemoryWriteEnable(memory~ : @ir.MemoryId, port~ : @ir.MemoryWritePortId)
  MemoryWriteMask(memory~ : @ir.MemoryId, port~ : @ir.MemoryWritePortId)
  ToggleSourceValid(@ir.CdcPrimitiveId)
  ToggleSourcePayload(primitive~ : @ir.CdcPrimitiveId, leaf~ : Int32)
  ToggleDestinationReady(@ir.CdcPrimitiveId)
  FifoSourceValid(@ir.CdcPrimitiveId)
  FifoDestinationReady(@ir.CdcPrimitiveId)
  FifoPayloadWrite(primitive~ : @ir.CdcPrimitiveId, leaf~ : Int32)
  FifoWriteTransfer(@ir.CdcPrimitiveId)
  FifoPointerStage(primitive~ : @ir.CdcPrimitiveId, side~ : String)
  FifoPrivateRead(primitive~ : @ir.CdcPrimitiveId, leaf~ : Int32)
  Output(String)
} derive(Debug, Eq)

///|
/// Stable failures from the one canonical structural CDC pass.
pub(all) suberror CdcError {
  TimingUnavailable(module_name~ : String)
  PrimitiveSourceMismatch(
    module_name~ : String,
    primitive~ : @ir.CdcPrimitiveId,
    source~ : @ir.NodeId,
    declared~ : @ir.CdcSourceDomain,
    actual~ : CdcProvenance,
    witness~ : CdcWitness?
  )
  UnsafeDependency(
    module_name~ : String,
    sink~ : CdcSink,
    destination~ : @ir.ClockDomainId,
    actual~ : CdcProvenance,
    witness~ : CdcWitness
  )
  UnsafeAsynchronousReset(
    module_name~ : String,
    sink~ : CdcSink,
    destination~ : @ir.ClockDomainId,
    actual~ : CdcProvenance,
    witness~ : CdcWitness?
  )
  OutputTimingMismatch(
    module_name~ : String,
    output~ : String,
    declared~ : @ir.OutputTiming,
    actual~ : CdcProvenance,
    witness~ : CdcWitness?
  )
} derive(Debug, Eq)

///|
/// A minimal witness for one exact domain component.
pub struct CdcDomainWitness {
  domain : @ir.ClockDomainId
  witness : CdcWitness
} derive(Debug, Eq)

///|
pub fn CdcDomainWitness::domain(self : CdcDomainWitness) -> @ir.ClockDomainId {
  self.domain
}

///|
pub fn CdcDomainWitness::witness(self : CdcDomainWitness) -> CdcWitness {
  self.witness
}

///|
/// Provenance and canonical witnesses for one node.
pub struct CdcNodeAnalysis {
  node : @ir.NodeId
  provenance : CdcProvenance
  asynchronous_witness : CdcWitness?
  domain_witnesses : ReadOnlyArray[CdcDomainWitness]
} derive(Debug, Eq)

///|
pub fn CdcNodeAnalysis::node(self : CdcNodeAnalysis) -> @ir.NodeId {
  self.node
}

///|
pub fn CdcNodeAnalysis::provenance(self : CdcNodeAnalysis) -> CdcProvenance {
  self.provenance
}

///|
pub fn CdcNodeAnalysis::asynchronous_witness(
  self : CdcNodeAnalysis,
) -> CdcWitness? {
  self.asynchronous_witness
}

///|
pub fn CdcNodeAnalysis::domain_witnesses(
  self : CdcNodeAnalysis,
) -> ReadOnlyArray[CdcDomainWitness] {
  self.domain_witnesses
}

///|
/// Immutable node provenance for one canonical module.
pub struct CdcAnalysis {
  nodes : ReadOnlyArray[CdcNodeAnalysis]
} derive(Debug, Eq)

///|
pub fn CdcAnalysis::nodes(self : CdcAnalysis) -> ReadOnlyArray[CdcNodeAnalysis] {
  self.nodes
}

///|
pub fn CdcAnalysis::node(
  self : CdcAnalysis,
  id : @ir.NodeId,
) -> CdcNodeAnalysis? {
  self.nodes.get(id.ordinal())
}

///|
pub extend CdcProvenance with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CdcProvenance with Eq::{not_equal, equal}

///|
pub extend CdcOrigin with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CdcOrigin with Eq::{not_equal, equal}

///|
pub extend CdcWitness with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CdcWitness with Eq::{not_equal, equal}

///|
pub extend CdcSink with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CdcSink with Eq::{not_equal, equal}

///|
pub extend CdcError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CdcError with Eq::{not_equal, equal}

///|
pub extend CdcDomainWitness with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CdcDomainWitness with Eq::{not_equal, equal}

///|
pub extend CdcNodeAnalysis with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CdcNodeAnalysis with Eq::{not_equal, equal}

///|
pub extend CdcAnalysis with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CdcAnalysis with Eq::{not_equal, equal}
