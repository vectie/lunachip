///|
/// Stable identity in one module's ordered CDC-primitive table.
pub struct CdcPrimitiveId(Int) derive(Debug, Eq, Compare)

///|
pub fn CdcPrimitiveId::new(ordinal : Int) -> CdcPrimitiveId raise IrError {
  if ordinal < 0 {
    raise InvalidCdcPrimitiveId(ordinal)
  }
  CdcPrimitiveId(ordinal)
}

///|
pub fn CdcPrimitiveId::ordinal(self : CdcPrimitiveId) -> Int {
  let CdcPrimitiveId(ordinal) = self
  ordinal
}

///|
/// The provenance class declared at a CDC primitive's source boundary.
pub(all) enum CdcSourceDomain {
  AsynchronousSource
  SourceDomain(ClockDomainId)
} derive(Debug, Eq)

///|
/// A checked declaration for one structural single-bit synchronizer.
///
/// The enclosing module proves the exact register-chain structure, domain,
/// reset, stage ownership, and intermediate fanout. Merely constructing this
/// value grants no CDC exemption.
pub struct BitSynchronizerPrimitive {
  id : CdcPrimitiveId
  name : String
  source_domain : CdcSourceDomain
  source : NodeId
  destination : ClockDomainId
  stages : ReadOnlyArray[NodeId]
  reset : ResetSpec?
} derive(Debug, Eq)

///|
pub fn BitSynchronizerPrimitive::checked(
  id : CdcPrimitiveId,
  name : String,
  source_domain : CdcSourceDomain,
  source : NodeId,
  destination : ClockDomainId,
  declared_stages : ArrayView[NodeId],
  reset? : ResetSpec,
) -> BitSynchronizerPrimitive raise IrError {
  require_name(name, "CDC primitive")
  let count = declared_stages.length()
  if count < 2 || count > 4 {
    raise InvalidBitSynchronizerStageCount(primitive=id.ordinal(), actual=count)
  }
  let stages = declared_stages.to_owned()
  for index, stage in stages {
    if stage == source {
      raise CdcPrimitiveSourceIsStage(
        primitive=id.ordinal(),
        node=stage.ordinal(),
      )
    }
    for prior in 0..<index {
      if stages[prior] == stage {
        raise DuplicateCdcPrimitiveStage(node=stage.ordinal())
      }
    }
  }
  {
    id,
    name,
    source_domain,
    source,
    destination,
    stages: ReadOnlyArray::from_array(stages),
    reset,
  }
}

///|
pub fn BitSynchronizerPrimitive::id(
  self : BitSynchronizerPrimitive,
) -> CdcPrimitiveId {
  self.id
}

///|
pub fn BitSynchronizerPrimitive::name(
  self : BitSynchronizerPrimitive,
) -> String {
  self.name
}

///|
pub fn BitSynchronizerPrimitive::source_domain(
  self : BitSynchronizerPrimitive,
) -> CdcSourceDomain {
  self.source_domain
}

///|
pub fn BitSynchronizerPrimitive::source(
  self : BitSynchronizerPrimitive,
) -> NodeId {
  self.source
}

///|
pub fn BitSynchronizerPrimitive::destination(
  self : BitSynchronizerPrimitive,
) -> ClockDomainId {
  self.destination
}

///|
pub fn BitSynchronizerPrimitive::stages(
  self : BitSynchronizerPrimitive,
) -> ReadOnlyArray[NodeId] {
  self.stages
}

///|
pub fn BitSynchronizerPrimitive::output(
  self : BitSynchronizerPrimitive,
) -> NodeId {
  self.stages[self.stages.length() - 1]
}

///|
pub fn BitSynchronizerPrimitive::reset(
  self : BitSynchronizerPrimitive,
) -> ResetSpec? {
  self.reset
}

///|
/// Canonical CDC primitive declarations. Later Phase 5 variants extend this
/// closed table without adding annotations or alternate validation paths.
pub(all) enum CdcPrimitive {
  BitSynchronizer(BitSynchronizerPrimitive)
  ToggleHandshake(ToggleHandshakePrimitive)
  AsyncFifo(AsyncFifoPrimitive)
} derive(Debug, Eq)

///|
pub fn CdcPrimitive::id(self : CdcPrimitive) -> CdcPrimitiveId {
  match self {
    BitSynchronizer(spec) => spec.id()
    ToggleHandshake(spec) => spec.id()
    AsyncFifo(spec) => spec.id()
  }
}

///|
pub fn CdcPrimitive::name(self : CdcPrimitive) -> String {
  match self {
    BitSynchronizer(spec) => spec.name()
    ToggleHandshake(spec) => spec.name()
    AsyncFifo(spec) => spec.name()
  }
}

///|
pub fn Module::cdc_primitives(self : Module) -> ReadOnlyArray[CdcPrimitive] {
  self.metadata().cdc_primitives()
}

///|
pub extend CdcPrimitiveId with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CdcPrimitiveId with Eq::{not_equal, equal}

///|
pub extend CdcPrimitiveId with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend CdcSourceDomain with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CdcSourceDomain with Eq::{not_equal, equal}

///|
pub extend BitSynchronizerPrimitive with @moonbitlang/core/debug.Debug::{
  to_repr,
}

///|
pub extend BitSynchronizerPrimitive with Eq::{not_equal, equal}

///|
pub extend CdcPrimitive with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CdcPrimitive with Eq::{not_equal, equal}
