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
  let registers = queued_concurrent_state(builder, domain, reset, queue_depth)
  let descriptor = queued_concurrent_descriptor(
    builder,
    registers.lanes,
    rows,
    columns,
    max_reduction,
  )
  let dispatch = queued_concurrent_dispatch(
    builder, registers, descriptor, reset_inactive, bus, queue_depth,
  )
  let engine = build_concurrent_graph(
    builder,
    domain,
    reset,
    reset_inactive,
    dispatch.inputs,
    rows,
    columns,
    max_reduction,
    host_bytes,
  )
  let admit = builder.bit_and(
    reset_inactive,
    builder.bit_not(engine.memory.halted),
  )
  let fifo = Array::makei(4, index => {
    @memory.synchronous_fifo(
      builder,
      @memory.FifoConfig::new(
        "descriptor_lane_\{index}",
        @wire.bits(64),
        queue_depth,
        GeneralDepth,
      ),
      domain,
      reset_signal,
      builder.bit_and(descriptor_valid, admit),
      lanes[index],
      dispatch.states[0],
    )
  })
  let descriptor_ready = builder.bit_and(
    admit,
    execute_and(builder, fifo.map(lane => lane.push_ready())),
  )
  let local_fault = builder.mux(
    engine.memory.halted,
    execute_constant(builder, 4, 15),
    dispatch.local_fault,
  )
  let reject = builder.bit_and(
    dispatch.states[3],
    builder.bit_not(builder.equal(local_fault, execute_constant(builder, 4, 0))),
  )
  let fence = execute_and(builder, [
    dispatch.states[3],
    descriptor.op[4],
    dispatch.fence_ready,
    builder.equal(local_fault, execute_constant(builder, 4, 0)),
  ])
  queued_concurrent_head_connect(
    builder, registers, dispatch, fifo, engine, reject, fence,
  )
  queued_concurrent_dependencies_connect(
    builder, registers, descriptor, dispatch, engine, reject,
  )
  let retirement = queued_concurrent_retirement_connect(
    builder, registers, descriptor, dispatch, engine, reset_inactive, completion_ready,
    reject, local_fault, fence, queue_depth,
  )
  let occupancy = fifo[0].occupancy()
  let occupancy = if occupancy.signal_type().width().bits() < 5 {
    builder.zero_extend(occupancy, 5)
  } else {
    occupancy
  }
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
