///|
// Capture fifteen authoritative engine references without a builder call.
// Raw State is the register, while Terminal is the existing reset-gated Done
// expression. The metadata includes rejected-preflight owners as well as work.
fn queue_conservation_engine_references(
  observations : Array[QueueConservationObservation],
  load_accept : @wire.Signal,
  compute_accept : @wire.Signal,
  store_accept : @wire.Signal,
  loader : ConcurrentLoaderState,
  loader_view : ConcurrentLoaderView,
  compute : ConcurrentComputeState,
  compute_states : Array[@wire.Signal],
  store : ConcurrentTransferState,
  store_view : ConcurrentStorerView,
) -> Unit {
  for
    (engine, accept, state, ticket, terminal, fault) in [
      (
        0,
        load_accept,
        loader.transfer.state.value(),
        loader.transfer.id.value(),
        loader_view.states[4],
        loader.transfer.fault.value(),
      ),
      (
        1,
        compute_accept,
        compute.state.value(),
        compute.id.value(),
        compute_states[3],
        compute.fault.value(),
      ),
      (
        2,
        store_accept,
        store.state.value(),
        store.id.value(),
        store_view.states[4],
        store.fault.value(),
      ),
    ] {
    queue_conservation_reference(observations, EngineAccept(engine), accept)
    queue_conservation_reference(observations, EngineState(engine), state)
    queue_conservation_reference(observations, EngineTicket(engine), ticket)
    queue_conservation_reference(observations, EngineTerminal(engine), terminal)
    queue_conservation_reference(observations, EngineFault(engine), fault)
  }
}
