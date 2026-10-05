///|
// Preserve the legacy two-client arbiter and construction order while sharing
// the engine clients with shells that own their own memory arbitration.
fn build_concurrent_graph(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  reset_inactive : @wire.Signal,
  inputs : ConcurrentInputs,
  rows : Int,
  columns : Int,
  max_reduction : Int,
  host_bytes : UInt64,
  formal_observations? : Array[QueuedConcurrentFormalObservation],
  queue_observations? : Array[QueueConservationObservation],
) -> ConcurrentSignals raise {
  let bus = inputs.bus
  let arbitration = arbiter_registers(builder, domain, reset)
  let routes = arbiter_routes(builder, arbitration, reset_inactive, bus)
  let clients = build_concurrent_clients(
    builder,
    domain,
    reset,
    reset_inactive,
    { load: inputs.load, compute: inputs.compute, store: inputs.store, },
    routes.reader,
    routes.engine,
    routes.poisoned,
    rows,
    columns,
    max_reduction,
    host_bytes,
    formal_observations?,
    queue_observations?,
  )
  let response_ready = arbiter_controller(
    builder,
    arbitration,
    reset_inactive,
    bus,
    routes,
    clients.load_request,
    clients.load_response_ready,
    clients.store_request,
    clients.store_response_ready,
  )
  {
    load: clients.engine.load,
    compute: clients.engine.compute,
    store: clients.engine.store,
    memory: {
      request_valid: routes.request_valid,
      request_write: routes.request_write,
      address: routes.address,
      request_bytes: routes.request_bytes,
      request_mask: routes.request_mask,
      request_data: routes.request_data,
      request_tag: routes.request_tag,
      response_ready,
      halted: routes.poisoned,
    },
    stored: clients.stored,
  }
}
