///|
/// Construct an atomic 32-byte descriptor FIFO and serial FluxTile frontend.
/// Four Bits64 lanes carry draft format 0.1. The queue holds `queue_depth`
/// entries plus one active head; completion backpressure holds that head.
/// A protocol fault stops admission and drains accepted entries as fault 15.
/// Reset is the same joint device/transport flush barrier as portable_tile.
/// See PHASE6_FRONTEND.md; this is not yet a DMA ring or frozen device ABI.
///
/// ```mbt check
/// test {
///   assert_eq(
///     @flux_tile.queued_tile(
///       rows=1,
///       columns=1,
///       max_reduction=4,
///       host_bytes=256UL,
///       queue_depth=3,
///     )
///     .memories()
///     .length(),
///     7,
///   )
/// }
/// ```
pub fn queued_tile(
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
    "FluxTileQueued", rows, columns, max_reduction, host_bytes,
  )
  builder.parameter("queue_depth", Signed(queue_depth.to_int64()))
  let clock = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock)
  let reset_signal = builder.input("reset", @wire.reset())
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let reset_inactive = builder.bit_not(builder.reset_asserted(reset_signal))
  let descriptor_valid = builder.input("descriptor_valid", @wire.bits(1))
  let descriptor_lanes : Array[@wire.Signal] = []
  for index in 0..<4 {
    descriptor_lanes.push(
      builder.input("descriptor_lane_\{index}", @wire.bits(64)),
    )
  }
  let completion_ready = builder.input("completion_ready", @wire.bits(1))
  let state = builder.register_state_in(domain, @wire.uint(3), reset~)
  let halt = builder.register_state_in(domain, @wire.bits(1), reset~)
  let head : Array[@wire.RegisterHandle] = []
  for _ in 0..<4 {
    head.push(builder.register_state_in(domain, @wire.bits(64), reset~))
  }
  let completion = queued_completion(builder, domain, reset)
  // Idle, FIFO response wait, Decode, portable Issue, Active, held Done.
  let states : Array[@wire.Signal] = []
  for index in 0..<6 {
    states.push(
      builder.bit_and(
        builder.equal(state.value(), execute_constant(builder, 3, index)),
        reset_inactive,
      ),
    )
  }
  let descriptor = queued_descriptor(builder, head)
  let issue = builder.bit_and(states[3], builder.bit_not(halt.value()))
  let ports = queued_portable_inputs(builder, descriptor, issue, states[4])
  let core = build_portable_graph(
    builder, domain, reset, reset_inactive, ports, rows, columns, max_reduction,
    host_bytes,
  )
  let link_fault = builder.bit_and(
    core.completion_valid,
    builder.equal(core.completion_fault, execute_constant(builder, 4, 10)),
  )
  builder.connect_next(halt, builder.bit_or(halt.value(), link_fault))
  // The visible core fault closes admission immediately, before the edge
  // that captures its completion. Earlier accepted pushes remain drainable.
  let halted = builder.bit_and(
    builder.bit_or(halt.value(), link_fault),
    reset_inactive,
  )
  let admit = builder.bit_and(reset_inactive, builder.bit_not(halted))
  let push = builder.bit_and(descriptor_valid, admit)
  let fifo : Array[@memory.FifoSignals] = []
  for index in 0..<4 {
    let config = @memory.FifoConfig::new(
      "descriptor_lane_\{index}",
      @wire.bits(64),
      queue_depth,
      GeneralDepth,
    )
    fifo.push(
      @memory.synchronous_fifo(
        builder,
        config,
        domain,
        reset_signal,
        push,
        descriptor_lanes[index],
        states[0],
      ),
    )
  }
  // All lanes have identical reset/control/depth, hence identical transfer
  // decisions. All ready and response pulses participate in the boundary.
  let descriptor_ready = builder.bit_and(
    admit,
    execute_and(builder, fifo.map(lane => lane.push_ready())),
  )
  queued_controller(
    builder, state, states, head, fifo, descriptor, core, halted, completion_ready,
    completion,
  )
  let occupancy = fifo[0].occupancy()
  let occupancy = if occupancy.signal_type().width().bits() < 5 {
    builder.zero_extend(occupancy, 5)
  } else {
    occupancy
  }
  execute_output(builder, "descriptor_ready", descriptor_ready)
  execute_output(builder, "queue_occupancy", occupancy)
  execute_output(builder, "halted", halted)
  execute_output(builder, "completion_valid", states[5])
  execute_output(builder, "completion_id", completion.id.value())
  execute_output(builder, "completion_fault", completion.fault.value())
  execute_output(
    builder,
    "completion_bytes_completed",
    completion.bytes_completed.value(),
  )
  execute_output(
    builder,
    "completion_fault_address",
    completion.fault_address.value(),
  )
  portable_memory_outputs(builder, core)
  builder.finish()
}
