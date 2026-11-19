///|
/// Fetch host-ring descriptors and execute them through one shared memory bus.
/// Ring consumption means atomic queue acceptance, not command completion.
/// The transport uses globally tagged, serialized, fair request arbitration.
/// Reset requires flushing the external transport. The device ABI is draft.
/// See PHASE6_HOST_RING.md for fault ownership and cancellation semantics.
///
/// ```mbt check
/// test {
///   assert_eq(
///     @flux_tile.ring_tile(
///       rows=1,
///       columns=1,
///       max_reduction=2,
///       host_bytes=1024UL,
///       ring_depth=4,
///       queue_depth=3,
///     )
///     .memories()
///     .length(),
///     7,
///   )
/// }
/// ```
pub fn ring_tile(
  rows~ : Int32,
  columns~ : Int32,
  max_reduction~ : Int32,
  host_bytes~ : UInt64,
  ring_depth~ : Int32,
  queue_depth~ : Int32,
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
    "FluxTileHost", rows, columns, max_reduction, host_bytes,
  )
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
  let arbitration = arbiter_registers(builder, domain, reset)
  let routes = arbiter_routes(builder, arbitration, reset_inactive, bus)
  let ring_state = ring_registers(builder, domain, reset)
  let packet_valid = execute_and(builder, [
    reset_inactive,
    builder.bit_not(routes.poisoned),
    builder.equal(ring_state.state.value(), execute_constant(builder, 3, 5)),
  ])
  let packet_lanes = ring_state.lanes.map(lane => lane.value())
  let context = queued_context(
    builder,
    domain,
    reset,
    reset_inactive,
    transport_poison=routes.poisoned,
  )
  let ports : PortablePorts = {
    command_valid: context.issue,
    opcode: context.descriptor.opcode,
    id: context.descriptor.id,
    rows: context.descriptor.rows,
    columns: context.descriptor.columns,
    reduction: context.descriptor.reduction,
    base: context.descriptor.base,
    stride: context.descriptor.stride,
    completion_ready: context.states[4],
    request_ready: routes.engine.request_ready,
    response_valid: routes.engine.response_valid,
    response_tag: routes.engine.response_tag,
    response_fault: routes.engine.response_fault,
    response_data: routes.engine.response_data,
  }
  let queue = build_queued_graph(
    builder,
    domain,
    reset,
    reset_signal,
    reset_inactive,
    context,
    packet_valid,
    packet_lanes,
    completion_ready,
    ports,
    rows,
    columns,
    max_reduction,
    host_bytes,
    queue_depth,
    transport_poison=routes.poisoned,
  )
  let ring_ports : RingInputs = {
    config_valid,
    config_base,
    config_origin,
    publish_valid,
    publish_producer,
    descriptor_ready: queue.descriptor_ready,
    request_ready: routes.reader.request_ready,
    response_valid: routes.reader.response_valid,
    response_tag: routes.reader.response_tag,
    response_fault: routes.reader.response_fault,
    response_data: routes.reader.response_data,
  }
  let ring = build_ring_graph(
    builder,
    ring_state,
    reset_inactive,
    ring_ports,
    host_bytes,
    ring_depth,
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
  let core = queue.core
  let engine_request : ArbiterRequest = {
    valid: core.request_valid,
    write: core.request_write,
    address: core.address,
    bytes: core.request_bytes,
    mask: core.request_mask,
    data: core.request_data,
    tag: core.request_tag,
  }
  let response_ready = arbiter_controller(
    builder,
    arbitration,
    reset_inactive,
    bus,
    routes,
    reader_request,
    ring.response_ready,
    engine_request,
    core.response_ready,
  )
  host_ring_outputs(builder, ring, queue, routes, response_ready)
  builder.finish()
}
