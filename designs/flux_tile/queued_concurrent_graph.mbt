///|
// Allocate the head and decode before building engines. No FIFO or output
// allocation occurs here, so the legacy generator keeps its exact IR order.
priv struct QueuedConcurrentContext {
  registers : QueuedConcurrentState
  descriptor : QueuedConcurrentDescriptor
  dispatch : QueuedConcurrentDispatch
}

///|
priv struct QueuedConcurrentSignals {
  descriptor_ready : @wire.Signal
  occupancy : @wire.Signal
  retirement : QueuedConcurrentRetirement
}

///|
fn build_queued_concurrent_context(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  reset_inactive : @wire.Signal,
  rows : Int,
  columns : Int,
  max_reduction : Int,
  queue_depth : Int,
) -> QueuedConcurrentContext raise {
  let registers = queued_concurrent_state(builder, domain, reset, queue_depth)
  let descriptor = queued_concurrent_descriptor(
    builder,
    registers.lanes,
    rows,
    columns,
    max_reduction,
  )
  let dispatch = queued_concurrent_dispatch(
    builder, registers, descriptor, reset_inactive, queue_depth,
  )
  { registers, descriptor, dispatch, }
}

///|
// Connect the queue once engine channel views exist. This owns packet FIFO,
// dependency, head and retirement updates, but builds no engines or outputs.
fn finish_queued_concurrent_graph(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset_signal : @wire.Signal,
  reset_inactive : @wire.Signal,
  context : QueuedConcurrentContext,
  descriptor_valid : @wire.Signal,
  lanes : Array[@wire.Signal],
  completion_ready : @wire.Signal,
  engine : ConcurrentEngineSignals,
  queue_depth : Int,
  formal_observations? : Array[QueuedConcurrentFormalObservation],
  queue_observations? : Array[QueueConservationObservation],
) -> QueuedConcurrentSignals raise {
  let registers = context.registers
  let descriptor = context.descriptor
  let dispatch = context.dispatch
  let admit = builder.bit_and(reset_inactive, builder.bit_not(engine.halted))
  let fifo = Array::makei(4, index => {
    let config = @memory.FifoConfig::new(
      "descriptor_lane_\{index}",
      @wire.bits(64),
      queue_depth,
      GeneralDepth,
    )
    let push_valid = builder.bit_and(descriptor_valid, admit)
    let lane = @memory.synchronous_fifo(
      builder,
      config,
      domain,
      reset_signal,
      push_valid,
      lanes[index],
      dispatch.states[0],
    )
    match queue_observations {
      Some(observations) => {
        queue_conservation_reference(
          observations,
          FifoPushValid(index),
          push_valid,
        )
        queue_conservation_reference(
          observations,
          FifoPushReady(index),
          lane.push_ready(),
        )
        queue_conservation_reference(
          observations,
          FifoPopRequest(index),
          dispatch.states[0],
        )
        queue_conservation_reference(
          observations,
          FifoPopReady(index),
          lane.pop_ready(),
        )
        queue_conservation_reference(
          observations,
          FifoResponseValid(index),
          lane.response_valid(),
        )
        queue_conservation_reference(
          observations,
          FifoResponseData(index),
          lane.response_data(),
        )
        queue_conservation_reference(
          observations,
          FifoOccupancy(index),
          lane.occupancy(),
        )
        queue_conservation_reference(observations, FifoFull(index), lane.full())
        queue_conservation_reference(
          observations,
          FifoEmpty(index),
          lane.empty(),
        )
      }
      None => ()
    }
    lane
  })
  let descriptor_ready = builder.bit_and(
    admit,
    execute_and(builder, fifo.map(lane => lane.push_ready())),
  )
  let local_fault = builder.mux(
    engine.halted,
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
    builder,
    registers,
    dispatch,
    fifo,
    engine,
    reject,
    fence,
    queue_observations?,
  )
  match queue_observations {
    Some(observations) =>
      queue_conservation_reference(observations, HeadLocalFault, local_fault)
    None => ()
  }
  queued_concurrent_dependencies_connect(
    builder, registers, descriptor, dispatch, engine, reject,
  )
  let retirement = queued_concurrent_retirement_connect(
    builder,
    registers,
    descriptor,
    dispatch,
    engine,
    reset_inactive,
    completion_ready,
    reject,
    local_fault,
    fence,
    queue_depth,
    queue_observations?,
  )
  match formal_observations {
    Some(observations) => {
      queued_concurrent_formal_reference(observations, LocalReject, reject)
      queued_concurrent_formal_reference(observations, LocalFault, local_fault)
    }
    None => ()
  }
  let occupancy = fifo[0].occupancy()
  let occupancy = if occupancy.signal_type().width().bits() < 5 {
    builder.zero_extend(occupancy, 5)
  } else {
    occupancy
  }
  { descriptor_ready, occupancy, retirement, }
}
