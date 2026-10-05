///|
// Build the shared engines against externally owned memory routes. This seam
// creates neither an arbiter nor output ports; channel views are read-only.
fn build_concurrent_clients(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  reset_inactive : @wire.Signal,
  commands : ConcurrentCommandInputs,
  loader_route : ArbiterClientRoute,
  storer_route : ArbiterClientRoute,
  poisoned : @wire.Signal,
  rows : Int,
  columns : Int,
  max_reduction : Int,
  host_bytes : UInt64,
) -> ConcurrentClientSignals raise {
  let load_ports = commands.load
  let compute_ports = commands.compute
  let store_ports = commands.store
  let live = builder.bit_and(reset_inactive, builder.bit_not(poisoned))
  let loader = concurrent_loader_state(builder, domain, reset)
  let store = concurrent_storer_state(builder, domain, reset)
  let compute = concurrent_compute_state(builder, domain, reset)
  let loader_view = concurrent_loader_view(
    builder, loader, reset_inactive, poisoned,
  )
  let store_view = concurrent_storer_view(
    builder, store, reset_inactive, poisoned,
  )
  let compute_states = concurrent_compute_states(
    builder, compute, reset_inactive,
  )
  let a_slots = Array::makei(2, _ => {
    slotted_portable_host_slot(builder, domain, reset)
  })
  let b_slots = Array::makei(2, _ => {
    slotted_portable_host_slot(builder, domain, reset)
  })
  let compute_fault = concurrent_compute_fault(
    builder, compute_ports, a_slots, b_slots, rows, columns, max_reduction,
  )
  let compute_ready = concurrent_compute_ready(
    builder, compute_ports, compute_states, loader, loader_view, store, store_view,
    live,
  )
  let compute_accept = builder.bit_and(compute_ready, compute_ports.valid)
  let legal_compute_accept = builder.bit_and(
    compute_accept,
    builder.equal(compute_fault, execute_constant(builder, 4, 0)),
  )
  let load_fault = concurrent_transfer_fault(
    builder,
    load_ports,
    rows,
    columns,
    max_reduction,
    host_bytes,
    false,
    builder.constant(@wire.bits(1), 1UL),
  )
  let load_ready = concurrent_load_ready(
    builder, load_ports, loader_view, compute, compute_ports, legal_compute_accept,
    load_fault, live,
  )
  let load_accept = builder.bit_and(load_ready, load_ports.valid)
  let legal_load_accept = builder.bit_and(
    load_accept,
    builder.equal(load_fault, execute_constant(builder, 4, 0)),
  )
  let slotted_state = slotted_state(builder, domain, reset)
  let inputs : SlottedInputs = {
    stored: {
      execute: {
        load_a_valid: loader_view.a_valid,
        load_a_row: loader_view.a_row,
        load_a_index: loader_view.a_index,
        load_a_data: loader_view.data,
        load_b_valid: loader_view.b_valid,
        load_b_column: loader_view.b_column,
        load_b_index: loader_view.b_index,
        load_b_data: loader_view.data,
        command_valid: compute_states[1],
        command_rows: builder.truncate(compute.rows.value(), 4),
        command_columns: builder.truncate(compute.columns.value(), 4),
        command_reduction: compute.reduction.value(),
        command_id: compute.id.value(),
        step_ready: builder.constant(@wire.bits(1), 1UL),
        completion_ready: compute_states[2],
      },
      read_valid: store_view.read_valid,
      read_row: store_view.read_row,
      read_column: store_view.read_column,
      read_id: store_view.read_id,
      response_ready: store_view.core_response_ready,
    },
    load_a_slot: loader_view.slot,
    load_b_slot: loader_view.slot,
    command_a_slot: compute.a.value(),
    command_b_slot: compute.b.value(),
    command_c_slot: compute.c.value(),
    read_slot: store_view.read_slot,
  }
  let graph = build_slotted_graph(
    builder, domain, reset, reset_inactive, inputs, slotted_state, rows, columns,
    max_reduction,
  )
  let result_available = concurrent_result_available(
    builder,
    graph.result_slots,
    store_ports,
  )
  let store_fault = concurrent_transfer_fault(
    builder, store_ports, rows, columns, max_reduction, host_bytes, true, result_available,
  )
  let store_ready = concurrent_store_ready(
    builder, store_ports, store_view, compute, compute_ports, legal_compute_accept,
    store_fault, live,
  )
  let store_accept = builder.bit_and(store_ready, store_ports.valid)
  let load_finish = concurrent_loader_connect(
    builder,
    loader,
    load_ports,
    loader_view,
    loader_route,
    graph.stored,
    load_accept,
    load_fault,
    poisoned,
  )
  let store_request = concurrent_storer_connect(
    builder,
    store,
    store_ports,
    store_view,
    storer_route,
    graph.stored,
    store_accept,
    store_fault,
    poisoned,
  )
  concurrent_compute_connect(
    builder, compute, compute_ports, compute_states, compute_accept, compute_fault,
    graph,
  )
  concurrent_operand_updates(
    builder, a_slots, b_slots, load_ports, loader, legal_load_accept, load_finish,
  )
  {
    engine: {
      load: {
        command_ready: load_ready,
        completion_valid: loader_view.states[4],
        completion_id: loader.transfer.id.value(),
        completion_fault: loader.transfer.fault.value(),
        bytes_completed: loader.transfer.progress.value(),
        fault_address: loader.transfer.fault_address.value(),
      },
      compute: {
        command_ready: compute_ready,
        completion_valid: compute_states[3],
        completion_id: compute.id.value(),
        completion_fault: compute.fault.value(),
      },
      store: {
        command_ready: store_ready,
        completion_valid: store_view.states[4],
        completion_id: store.id.value(),
        completion_fault: store.fault.value(),
        bytes_completed: store.progress.value(),
        fault_address: store.fault_address.value(),
      },
      halted: poisoned,
    },
    load_request: loader_view.request,
    load_response_ready: loader_view.response_ready,
    store_request,
    store_response_ready: store_view.response_ready,
    stored: graph.stored,
  }
}
