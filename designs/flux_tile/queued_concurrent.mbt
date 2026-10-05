///|
/// Queue draft-0.2 slotted packets, dispatch in order to shared concurrent
/// engines, and retire terminal records in packet order. Internal UInt32
/// tickets distinguish duplicate caller IDs. Latest-writer summaries prevent
/// stale-data fallback after a failed intended generation. Fence waits for
/// older terminal work, not external completion acknowledgement.
/// This is a packet prototype, not a fetched ring or frozen device ABI.
/// See PHASE6_QUEUED_CONCURRENT.md.
///
/// ```mbt check
/// test {
///   assert_eq(
///     @flux_tile.queued_concurrent_tile(
///       rows=1,
///       columns=1,
///       max_reduction=4,
///       host_bytes=1024UL,
///       queue_depth=3,
///     )
///     .memories()
///     .length(),
///     10,
///   )
/// }
/// ```
pub fn queued_concurrent_tile(
  rows~ : Int,
  columns~ : Int,
  max_reduction~ : Int,
  host_bytes~ : UInt64,
  queue_depth~ : Int,
) -> @ir.Module raise {
  if queue_depth < 2 || queue_depth > 16 {
    raise QueuedTileError::InvalidQueueDepth(
      value=queue_depth,
      minimum=2,
      maximum=16,
    )
  }
  let builder = portable_builder(
    "FluxTileQueuedConcurrent", rows, columns, max_reduction, host_bytes,
  )
  builder.parameter("slot_count", Signed(2))
  builder.parameter("queue_depth", Signed(queue_depth.to_int64()))
  let clock = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock)
  let reset_signal = builder.input("reset", @wire.reset())
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let reset_inactive = builder.bit_not(builder.reset_asserted(reset_signal))
  let descriptor_valid = builder.input("descriptor_valid", @wire.bits(1))
  let lanes = Array::makei(4, index => {
    builder.input("descriptor_lane_\{index}", @wire.bits(64))
  })
  let completion_ready = builder.input("completion_ready", @wire.bits(1))
  let bus : ArbiterBusInputs = {
    request_ready: builder.input("memory_request_ready", @wire.bits(1)),
    response_valid: builder.input("memory_response_valid", @wire.bits(1)),
    response_tag: builder.input("memory_response_tag", @wire.uint(32)),
    response_fault: builder.input("memory_response_fault", @wire.uint(2)),
    response_data: builder.input("memory_response_data", @wire.bits(32)),
  }
  let context = build_queued_concurrent_context(
    builder, domain, reset, reset_inactive, rows, columns, max_reduction, queue_depth,
  )
  let commands = context.dispatch.inputs
  let engine = build_concurrent_graph(
    builder,
    domain,
    reset,
    reset_inactive,
    { load: commands.load, compute: commands.compute, store: commands.store, bus },
    rows,
    columns,
    max_reduction,
    host_bytes,
  )
  let queue = finish_queued_concurrent_graph(
    builder, domain, reset_signal, reset_inactive, context,
    descriptor_valid, lanes, completion_ready,
    {
      load: engine.load,
      compute: engine.compute,
      store: engine.store,
      halted: engine.memory.halted,
    },
    queue_depth,
  )
  let descriptor_ready = queue.descriptor_ready
  let occupancy = queue.occupancy
  let retirement = queue.retirement
  execute_output(builder, "descriptor_ready", descriptor_ready)
  execute_output(builder, "queue_occupancy", occupancy)
  execute_output(
    builder,
    "halted",
    builder.bit_and(reset_inactive, engine.memory.halted),
  )
  execute_output(builder, "completion_valid", retirement.valid)
  execute_output(builder, "completion_id", retirement.id)
  execute_output(builder, "completion_fault", retirement.fault)
  execute_output(builder, "completion_bytes_completed", retirement.progress)
  execute_output(builder, "completion_fault_address", retirement.address)
  concurrent_memory_outputs(builder, engine)
  builder.finish()
}
