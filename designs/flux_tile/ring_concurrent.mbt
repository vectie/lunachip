///|
/// Fetch draft-0.2 host descriptors into the queued concurrent engines.
/// One three-client transport arbitrates descriptor reads, operand loads and
/// result stores around one array and two physical operand/result slots.
/// Ring consumption means atomic packet admission, not execution completion.
/// Caller IDs may duplicate; internal tickets identify ordered retirement.
/// Reset requires jointly flushing external transactions. The ABI is draft.
/// See PHASE6_RING_CONCURRENT.md for fault ownership and poison semantics.
///
/// ```mbt check
/// test {
///   assert_eq(
///     @flux_tile.ring_concurrent_tile(
///       rows=1,
///       columns=1,
///       max_reduction=2,
///       host_bytes=1024UL,
///       ring_depth=4,
///       queue_depth=3,
///     ).memories().length(),
///     10,
///   )
/// }
/// ```
pub fn ring_concurrent_tile(
  rows~ : Int,
  columns~ : Int,
  max_reduction~ : Int,
  host_bytes~ : UInt64,
  ring_depth~ : Int,
  queue_depth~ : Int,
) -> @ir.Module raise {
  ring_validate_parameters(host_bytes, ring_depth)
  if queue_depth < 2 || queue_depth > 16 {
    raise QueuedTileError::InvalidQueueDepth(
      value=queue_depth,
      minimum=2,
      maximum=16,
    )
  }
  let builder = portable_builder(
    "FluxTileHostConcurrent", rows, columns, max_reduction, host_bytes,
  )
  builder.parameter("slot_count", Signed(2))
  builder.parameter("ring_depth", Signed(ring_depth.to_int64()))
  builder.parameter("queue_depth", Signed(queue_depth.to_int64()))
  let clock = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock)
  let reset_signal = builder.input("reset", @wire.reset())
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let reset_inactive = builder.bit_not(builder.reset_asserted(reset_signal))
  let config_valid = builder.input("config_valid", @wire.bits(1))
  let config_base = builder.input("config_base", @wire.uint(32))
  let config_origin = builder.input("config_origin", @wire.uint(32))
  let publish_valid = builder.input("publish_valid", @wire.bits(1))
  let publish_producer = builder.input("publish_producer", @wire.uint(32))
  let completion_ready = builder.input("completion_ready", @wire.bits(1))
  let bus : ArbiterBusInputs = {
    request_ready: builder.input("memory_request_ready", @wire.bits(1)),
    response_valid: builder.input("memory_response_valid", @wire.bits(1)),
    response_tag: builder.input("memory_response_tag", @wire.uint(32)),
    response_fault: builder.input("memory_response_fault", @wire.uint(2)),
    response_data: builder.input("memory_response_data", @wire.bits(32)),
  }
  let arbitration = arbiter_three_registers(builder, domain, reset)
  let routes = arbiter_three_routes(builder, arbitration, reset_inactive, bus)
  let ring_state = ring_registers(builder, domain, reset)
  // Observe the reader's pre-edge packet registers before connecting its
  // controller. Queue-ready feeds the reader later, without a forward wire.
  let packet_valid = execute_and(builder, [
    reset_inactive,
    builder.bit_not(routes.poisoned),
    builder.equal(ring_state.state.value(), execute_constant(builder, 3, 5)),
  ])
  let packet_lanes = ring_state.lanes.map(lane => lane.value())
  let context = build_queued_concurrent_context(
    builder, domain, reset, reset_inactive, rows, columns, max_reduction,
    queue_depth,
  )
  let clients = build_concurrent_clients(
    builder, domain, reset, reset_inactive, context.dispatch.inputs,
    routes.clients[1], routes.clients[2], routes.poisoned, rows, columns,
    max_reduction, host_bytes,
  )
  let queue = finish_queued_concurrent_graph(
    builder, domain, reset_signal, reset_inactive, context, packet_valid,
    packet_lanes, completion_ready, clients.engine, queue_depth,
  )
  let reader_route = routes.clients[0]
  let ring_ports : RingInputs = {
    config_valid,
    config_base,
    config_origin,
    publish_valid,
    publish_producer,
    descriptor_ready: queue.descriptor_ready,
    request_ready: reader_route.request_ready,
    response_valid: reader_route.response_valid,
    response_tag: reader_route.response_tag,
    response_fault: reader_route.response_fault,
    response_data: reader_route.response_data,
  }
  let ring = build_ring_graph(
    builder, ring_state, reset_inactive, ring_ports, host_bytes, ring_depth,
    transport_poison=routes.poisoned,
  )
  let reader_request : ArbiterRequest = {
    valid: ring.request_valid,
    write: ring.request_write,
    address: ring.address,
    bytes: ring.request_bytes,
    mask: ring.request_mask,
    data: ring.request_data,
    tag: ring.request_tag,
  }
  let response_ready = arbiter_three_controller(
    builder, arbitration, reset_inactive, bus, routes,
    [reader_request, clients.load_request, clients.store_request],
    [ring.response_ready, clients.load_response_ready, clients.store_response_ready],
  )
  ring_concurrent_outputs(
    builder, ring, queue, routes, response_ready, clients.stored,
  )
  builder.finish()
}
