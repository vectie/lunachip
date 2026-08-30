///|
fn ModuleBuilder::require_ready_valid_control(
  self : ModuleBuilder,
  signal : Signal,
) -> Unit raise {
  self.require_signal(signal)
  if !signal.signal_type.is_data() || signal.signal_type.width().bits() != 1 {
    raise @ir.IrError::ExpectedOneBit(node=signal.id.ordinal())
  }
}

///|
fn ModuleBuilder::validate_ready_valid_payload(
  self : ModuleBuilder,
  payload : @aggregate.Aggregate[Signal],
) -> Unit raise {
  let flattened = payload.flatten()
  let endpoints : Array[@ir.AggregateLeafTarget] = []
  for leaf in flattened {
    let signal = leaf.value()
    self.require_signal(signal)
    if !signal.signal_type.is_data() {
      raise @ir.IrError::TypeMismatch(operation="ready_valid_payload")
    }
    endpoints.push(Node(signal.id))
  }
  // Reuse the canonical IR aggregate validator for homogeneous hardware Vecs
  // and the declared depth/leaf resource limits. This is validation only; the
  // temporary binding is not installed into module metadata.
  ignore(
    @ir.AggregateBinding::checked(
      @ir.AggregateBindingId::new(0),
      Internal,
      "ready_valid_payload",
      signal_aggregate_shape(payload),
      endpoints,
    ),
  )
}

///|
/// Construct the producer-to-consumer half of a ready/valid interface.
///
/// `valid` is exactly one bit and every payload leaf is a builder-owned data
/// signal. This is a structural convention and adds no simulator behavior.
pub fn ModuleBuilder::ready_valid_forward(
  self : ModuleBuilder,
  valid : Signal,
  payload : @aggregate.Aggregate[Signal],
) -> ReadyValidForward raise {
  self.require_open()
  self.require_ready_valid_control(valid)
  self.validate_ready_valid_payload(payload)
  { owner: self.owner, valid, payload }
}

///|
/// Construct the consumer-to-producer half of a ready/valid interface.
/// `ready` must be an exact one-bit builder-owned signal.
pub fn ModuleBuilder::ready_valid_backward(
  self : ModuleBuilder,
  ready : Signal,
) -> ReadyValidBackward raise {
  self.require_open()
  self.require_ready_valid_control(ready)
  { owner: self.owner, ready }
}
