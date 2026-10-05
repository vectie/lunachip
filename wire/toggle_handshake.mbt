///|
fn ModuleBuilder::require_handshake_reset(
  self : ModuleBuilder,
  reset : SynchronousReset,
  role : String,
) -> Unit raise {
  if !physical_equal(self.owner, reset.owner) {
    raise ForeignReset
  }
  self.require_signal(reset.signal)
  if reset.value() != 0UL ||
    reset.mode() != Synchronous ||
    reset.polarity() != ActiveHigh {
    raise @ir.IrError::ToggleHandshakeResetMismatch(
      primitive=self.cdc_primitives.length(),
      role~,
      node=reset.signal().id().ordinal(),
    )
  }
}

///|
/// Construct a checked, coordinated-idle-reset toggle handshake.
///
/// The request is acknowledged when the destination captures it into its
/// response buffer. That permits a destination consume and refill on the same
/// edge while the separately registered destination payload remains stable
/// under known backpressure. Unknown controls follow ordinary four-state
/// combinational/register semantics and are not counted as transfers.
pub fn ModuleBuilder::toggle_handshake(
  self : ModuleBuilder,
  name : String,
  source_domain : ClockDomain,
  destination_domain : ClockDomain,
  source : ReadyValidForward,
  destination_ready : ReadyValidBackward,
  source_reset : SynchronousReset,
  destination_reset : SynchronousReset,
  synchronizer_stages? : Int = 2,
) -> ToggleHandshake raise {
  self.require_open()
  self.require_clock_domain(source_domain)
  self.require_clock_domain(destination_domain)
  if source_domain.id() == destination_domain.id() {
    raise @ir.IrError::EqualToggleHandshakeDomains(
      primitive=self.cdc_primitives.length(),
      domain=source_domain.id().ordinal(),
    )
  }
  if !physical_equal(self.owner, source.owner) ||
    !physical_equal(self.owner, destination_ready.owner) {
    raise ForeignSignal
  }
  self.require_ready_valid_control(source.valid())
  self.validate_ready_valid_payload(source.payload())
  self.require_ready_valid_control(destination_ready.ready())
  self.require_handshake_reset(source_reset, "source_reset")
  self.require_handshake_reset(destination_reset, "destination_reset")
  if synchronizer_stages < 2 || synchronizer_stages > 4 {
    raise @ir.IrError::InvalidToggleHandshakeStageCount(
      primitive=self.cdc_primitives.length(),
      actual=synchronizer_stages,
    )
  }
  let bit_type = bits(1)
  let payload_shape = signal_aggregate_shape(source.payload())
  let source_leaves = source.payload().flatten()
  let request = self.register_state_in(
    source_domain,
    bit_type,
    reset=source_reset,
  )
  let destination_valid = self.register_state_in(
    destination_domain,
    bit_type,
    reset=destination_reset,
  )
  let acknowledge = self.register_state_in(
    destination_domain,
    bit_type,
    reset=destination_reset,
  )
  let request_stage_signals : Array[Signal] = []
  let mut request_sample = request.value()
  for _ in 0..<synchronizer_stages {
    request_sample = self.register_in(
      destination_domain,
      request_sample,
      reset=destination_reset,
    )
    request_stage_signals.push(request_sample)
  }
  let acknowledge_stage_signals : Array[Signal] = []
  let mut acknowledge_sample = acknowledge.value()
  for _ in 0..<synchronizer_stages {
    acknowledge_sample = self.register_in(
      source_domain,
      acknowledge_sample,
      reset=source_reset,
    )
    acknowledge_stage_signals.push(acknowledge_sample)
  }
  let source_ready = self.equal(request.value(), acknowledge_sample)
  let source_accept = self.bit_and(source.valid(), source_ready)
  let request_inverted = self.bit_not(request.value())
  let request_next = self.mux(source_accept, request_inverted, request.value())
  self.connect_next(request, request_next)
  let held : Array[Signal] = []
  for leaf in source_leaves {
    held.push(
      self.register_in(
        source_domain,
        leaf.value(),
        reset=source_reset,
        enable=source_accept,
      ),
    )
  }
  let request_equal = self.equal(request_sample, acknowledge.value())
  let request_changed = self.bit_not(request_equal)
  let destination_consume = self.bit_and(
    destination_valid.value(),
    destination_ready.ready(),
  )
  let destination_not_valid = self.bit_not(destination_valid.value())
  let destination_available = self.bit_or(
    destination_not_valid,
    destination_ready.ready(),
  )
  let destination_capture = self.bit_and(request_changed, destination_available)
  let destination_not_consume = self.bit_not(destination_consume)
  let destination_retained = self.bit_and(
    destination_valid.value(),
    destination_not_consume,
  )
  let destination_valid_next = self.bit_or(
    destination_capture, destination_retained,
  )
  self.connect_next(destination_valid, destination_valid_next)
  let destination_payload_signals = held.map(held_signal => {
    self.register_in(
      destination_domain,
      held_signal,
      reset=destination_reset,
      enable=destination_capture,
    )
  })
  let acknowledge_next = self.mux(
    destination_capture,
    request_sample,
    acknowledge.value(),
  )
  self.connect_next(acknowledge, acknowledge_next)
  let destination_payload_aggregate = source
    .payload()
    .reconstruct_like(destination_payload_signals)
  let primitive = @ir.ToggleHandshakePrimitive::checked(
    @ir.CdcPrimitiveId::new(self.cdc_primitives.length()),
    name,
    source_domain.id(),
    destination_domain.id(),
    source_reset.canonical,
    destination_reset.canonical,
    payload_shape,
    source.valid().id(),
    source_ready.id(),
    source_accept.id(),
    source_leaves.map(leaf => leaf.value().id()),
    held.map(state => state.id()),
    request.value().id(),
    request_stage_signals.map(stage => stage.id()),
    request_changed.id(),
    destination_ready.ready().id(),
    destination_valid.value().id(),
    destination_capture.id(),
    destination_consume.id(),
    destination_available.id(),
    destination_payload_signals.map(signal => signal.id()),
    acknowledge.value().id(),
    acknowledge_stage_signals.map(stage => stage.id()),
  )
  self.cdc_primitives.push(ToggleHandshake(primitive))
  {
    source: { owner: self.owner, ready: source_ready, },
    destination: {
      owner: self.owner,
      valid: destination_valid.value(),
      payload: destination_payload_aggregate,
    },
  }
}
