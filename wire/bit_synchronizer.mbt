///|
/// Construct a checked two-through-four-stage single-bit synchronizer.
///
/// Omit `source_domain` for an asynchronous source. Supplying a builder-owned
/// source domain declares a timed foreign-domain source; it must differ from
/// `destination`. Every stage is an ordinary exact one-bit destination-domain
/// register without an enable. Omitted `reset` explicitly declares no reset;
/// a supplied reset is the supported active-high synchronous destination reset
/// contract shared by every stage.
pub fn ModuleBuilder::bit_synchronizer(
  self : ModuleBuilder,
  name : String,
  source : Signal,
  destination : ClockDomain,
  stages : Int32,
  source_domain? : ClockDomain,
  reset? : SynchronousReset,
) -> Signal raise {
  self.require_open()
  self.require_signal(source)
  if !source.signal_type.is_data() || source.signal_type.width().bits() != 1 {
    raise @ir.IrError::ExpectedOneBit(node=source.id.ordinal())
  }
  self.require_clock_domain(destination)
  let declared_source = match source_domain {
    None => @ir.CdcSourceDomain::AsynchronousSource
    Some(domain) => {
      self.require_clock_domain(domain)
      if domain.canonical.id() == destination.canonical.id() {
        raise @ir.IrError::EqualCdcPrimitiveDomains(
          primitive=self.cdc_primitives.length(),
          domain=domain.canonical.id().ordinal(),
        )
      }
      SourceDomain(domain.canonical.id())
    }
  }
  let (_, canonical_reset, _, _) = self.canonical_register_controls(
    source.signal_type,
    destination,
    reset,
    None,
    None,
  )
  let stage_ids : Array[@ir.NodeId] = []
  for offset in 0..<stages {
    stage_ids.push(@ir.NodeId::new(self.nodes.length() + offset))
  }
  let primitive = @ir.BitSynchronizerPrimitive::checked(
    @ir.CdcPrimitiveId::new(self.cdc_primitives.length()),
    name,
    declared_source,
    source.id,
    destination.canonical.id(),
    stage_ids,
    reset?=canonical_reset,
  )
  let mut current = source
  for _ in 0..<stages {
    current = self.register_in(destination, current, reset?)
  }
  self.cdc_primitives.push(BitSynchronizer(primitive))
  current
}
