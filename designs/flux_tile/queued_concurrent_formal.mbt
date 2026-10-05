///|
fn queued_concurrent_formal_reference(
  observations : Array[QueuedConcurrentFormalObservation],
  role : QueuedConcurrentFormalRole,
  signal : @wire.Signal,
) -> Unit {
  // Host-side metadata only. Never call a builder or create a derived signal.
  observations.push({
    role,
    node: signal.id(),
    signal_type: signal.signal_type(),
  })
}

///|
fn queued_concurrent_formal_head_references(
  observations : Array[QueuedConcurrentFormalObservation],
  context : QueuedConcurrentContext,
) -> Unit {
  let registers = context.registers
  for index, lane in registers.lanes {
    queued_concurrent_formal_reference(
      observations,
      HeadLane(index),
      lane.value(),
    )
  }
  queued_concurrent_formal_reference(
    observations,
    HeadState,
    registers.head_state.value(),
  )
  queued_concurrent_formal_reference(
    observations,
    HeadReserve,
    context.dispatch.reserve,
  )
  queued_concurrent_formal_reference(
    observations,
    NextTicket,
    registers.next_ticket.value(),
  )
  queued_concurrent_formal_reference(
    observations,
    HeadTicket,
    registers.head_ticket.value(),
  )
  for index, writer in registers.writers {
    queued_concurrent_formal_reference(
      observations,
      WriterStatus(index),
      writer.status.value(),
    )
    queued_concurrent_formal_reference(
      observations,
      WriterTicket(index),
      writer.ticket.value(),
    )
  }
  for index in 0..<2 {
    queued_concurrent_formal_reference(
      observations,
      DependencyStatus(index),
      registers.dependency_status[index].value(),
    )
    queued_concurrent_formal_reference(
      observations,
      DependencyTicket(index),
      registers.dependency_ticket[index].value(),
    )
  }
}

///|
fn queued_concurrent_formal_engine_references(
  observations : Array[QueuedConcurrentFormalObservation],
  load_accept : @wire.Signal,
  compute_accept : @wire.Signal,
  store_accept : @wire.Signal,
  compute_preflight : @wire.Signal,
  loader : ConcurrentLoaderState,
  loader_view : ConcurrentLoaderView,
  compute : ConcurrentComputeState,
  compute_states : Array[@wire.Signal],
  store : ConcurrentTransferState,
  store_view : ConcurrentStorerView,
  graph : SlottedGraphSignals,
) -> Unit {
  queued_concurrent_formal_reference(observations, LoadAccept, load_accept)
  queued_concurrent_formal_reference(
    observations,
    ComputeAccept,
    compute_accept,
  )
  queued_concurrent_formal_reference(observations, StoreAccept, store_accept)
  queued_concurrent_formal_reference(
    observations,
    LoadTerminal,
    loader_view.states[4],
  )
  queued_concurrent_formal_reference(
    observations,
    LoadTerminalTicket,
    loader.transfer.id.value(),
  )
  queued_concurrent_formal_reference(
    observations,
    LoadTerminalFault,
    loader.transfer.fault.value(),
  )
  queued_concurrent_formal_reference(
    observations,
    ComputeTerminal,
    compute_states[3],
  )
  queued_concurrent_formal_reference(
    observations,
    ComputeTerminalTicket,
    compute.id.value(),
  )
  queued_concurrent_formal_reference(
    observations,
    ComputeTerminalFault,
    compute.fault.value(),
  )
  queued_concurrent_formal_reference(
    observations,
    StoreTerminal,
    store_view.states[4],
  )
  queued_concurrent_formal_reference(
    observations,
    StoreTerminalTicket,
    store.id.value(),
  )
  queued_concurrent_formal_reference(
    observations,
    StoreTerminalFault,
    store.fault.value(),
  )
  queued_concurrent_formal_reference(
    observations,
    ComputePreflight,
    compute_preflight,
  )
  // Keep valid and ready separate: constructing an observation-only AND here
  // would change the canonical graph. The clocked monitor derives its event.
  queued_concurrent_formal_reference(
    observations,
    InnerCommandValid,
    compute_states[1],
  )
  queued_concurrent_formal_reference(
    observations,
    InnerCommandReady,
    graph.stored.execute.command_ready,
  )
  queued_concurrent_formal_reference(
    observations,
    ComputeLatchedTicket,
    compute.id.value(),
  )
  queued_concurrent_formal_reference(
    observations,
    ComputeLatchedA,
    compute.a.value(),
  )
  queued_concurrent_formal_reference(
    observations,
    ComputeLatchedB,
    compute.b.value(),
  )
  queued_concurrent_formal_reference(
    observations,
    ComputeLatchedC,
    compute.c.value(),
  )
  queued_concurrent_formal_reference(
    observations,
    ComputeLatchedRows,
    compute.rows.value(),
  )
  queued_concurrent_formal_reference(
    observations,
    ComputeLatchedColumns,
    compute.columns.value(),
  )
  queued_concurrent_formal_reference(
    observations,
    ComputeLatchedReduction,
    compute.reduction.value(),
  )
}

///|
/// Capture typed dependency-pilot references while building the ordinary direct
/// 1x1/K2/host1024/q3 queued module. No additional nodes, memories or ports are
/// allocated. Emission remains byte-identical to the ordinary constructor.
/// Outer compute acceptance establishes authorization; retain it through the
/// registered Issue gap instead of rechecking later latest-writer summaries.
/// This view is not a FIFO/retirement/lease proof and exports no properties.
/// Latched rows/columns/K are provided without claiming inner-shape preservation.
///
/// ```mbt check
/// test {
///   let fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
///   assert_eq(fixture.observations().length(), 48)
///   assert_eq(fixture.hardware().name(), "FluxTileQueuedConcurrent")
/// }
/// ```
pub fn queued_concurrent_dependency_formal_fixture() -> QueuedConcurrentFormalFixture raise {
  let observations : Array[QueuedConcurrentFormalObservation] = []
  let hardware = build_queued_concurrent_tile(
    rows=1,
    columns=1,
    max_reduction=2,
    host_bytes=1024UL,
    queue_depth=3,
    formal_observations=observations,
  )
  { hardware, observations: ReadOnlyArray::from_array(observations), }
}
