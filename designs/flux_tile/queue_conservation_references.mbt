///|
// Host-side metadata only: no builder, derived signal, port or state element.
fn queue_conservation_reference(
  observations : Array[QueueConservationObservation],
  role : QueueConservationRole,
  signal : @wire.Signal,
) -> Unit {
  observations.push({
    role,
    node: signal.id(),
    signal_type: signal.signal_type(),
  })
}
