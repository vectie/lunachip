///|
/// Construct independent host load, compute and store engines around two
/// storage slots and one array. The memory port serializes globally tagged
/// transactions while computation advances independently. Operational leases
/// release at terminal processing, not external completion ACK. Store holds
/// its C lease for the entire rectangle. Reset is a joint transport flush.
/// This is a provisional engine interface, not a queued descriptor ABI.
/// See PHASE6_CONCURRENT.md.
///
/// ```mbt check
/// test {
///   assert_eq(
///     @flux_tile.concurrent_engine_tile(
///       rows=1,
///       columns=1,
///       max_reduction=4,
///       host_bytes=1024UL,
///     )
///     .memories()
///     .length(),
///     6,
///   )
/// }
/// ```
pub fn concurrent_engine_tile(
  rows~ : Int,
  columns~ : Int,
  max_reduction~ : Int,
  host_bytes~ : UInt64,
) -> @ir.Module raise {
  let builder = portable_builder(
    "FluxTileConcurrent", rows, columns, max_reduction, host_bytes,
  )
  builder.parameter("slot_count", Signed(2))
  let clock = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock)
  let reset_signal = builder.input("reset", @wire.reset())
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let reset_inactive = builder.bit_not(builder.reset_asserted(reset_signal))
  let load_ports = concurrent_transfer_inputs(builder, "load", true)
  let compute_ports = concurrent_compute_inputs(builder)
  let store_ports = concurrent_transfer_inputs(builder, "store", false)
  let bus : ArbiterBusInputs = {
    request_ready: builder.input("memory_request_ready", @wire.bits(1)),
    response_valid: builder.input("memory_response_valid", @wire.bits(1)),
    response_tag: builder.input("memory_response_tag", @wire.uint(32)),
    response_fault: builder.input("memory_response_fault", @wire.uint(2)),
    response_data: builder.input("memory_response_data", @wire.bits(32)),
  }
  let arbitration = arbiter_registers(builder, domain, reset)
  let routes = arbiter_routes(builder, arbitration, reset_inactive, bus)
  let live = builder.bit_and(reset_inactive, builder.bit_not(routes.poisoned))
  let loader = concurrent_loader_state(builder, domain, reset)
  let store = concurrent_storer_state(builder, domain, reset)
  let compute = concurrent_compute_state(builder, domain, reset)
  let loader_view = concurrent_loader_view(
    builder,
    loader,
    reset_inactive,
    routes.poisoned,
  )
  let store_view = concurrent_storer_view(
    builder,
    store,
    reset_inactive,
    routes.poisoned,
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
    routes.reader,
    graph.stored,
    load_accept,
    load_fault,
    routes.poisoned,
  )
  let store_request = concurrent_storer_connect(
    builder,
    store,
    store_ports,
    store_view,
    routes.engine,
    graph.stored,
    store_accept,
    store_fault,
    routes.poisoned,
  )
  concurrent_compute_connect(
    builder, compute, compute_ports, compute_states, compute_accept, compute_fault,
    graph,
  )
  concurrent_operand_updates(
    builder, a_slots, b_slots, load_ports, loader, legal_load_accept, load_finish,
  )
  let response_ready = arbiter_controller(
    builder,
    arbitration,
    reset_inactive,
    bus,
    routes,
    loader_view.request,
    loader_view.response_ready,
    store_request,
    store_view.response_ready,
  )
  concurrent_transfer_outputs(
    builder,
    "load",
    loader.transfer,
    load_ready,
    loader_view.states[4],
  )
  concurrent_transfer_outputs(
    builder,
    "store",
    store,
    store_ready,
    store_view.states[4],
  )
  for
    (name, signal) in [
      ("compute_command_ready", compute_ready),
      ("compute_completion_valid", compute_states[3]),
      ("compute_completion_id", compute.id.value()),
      ("compute_completion_fault", compute.fault.value()),
    ] {
    execute_output(builder, name, signal)
  }
  concurrent_memory_outputs(builder, routes, response_ready, graph.stored)
  builder.finish()
}

///|
fn concurrent_memory_outputs(
  builder : @wire.ModuleBuilder,
  routes : ArbiterRoutes,
  response_ready : @wire.Signal,
  core : StoredSignals,
) -> Unit raise {
  for
    (name, signal) in [
      ("memory_request_valid", routes.request_valid),
      ("memory_request_write", routes.request_write),
      ("memory_request_address", routes.address),
      ("memory_request_bytes", routes.request_bytes),
      ("memory_request_mask", routes.request_mask),
      ("memory_request_data", routes.request_data),
      ("memory_request_tag", routes.request_tag),
      ("memory_response_ready", response_ready),
      ("transport_halted", routes.poisoned),
      (
        "transport_fault_address",
        builder.mux(
          routes.poisoned,
          routes.address,
          execute_constant(builder, 32, 0),
        ),
      ),
      ("accepted_steps", core.execute.accepted_steps),
      ("elapsed_cycles", core.execute.elapsed_cycles),
      ("active_cycles", core.execute.active_cycles),
      ("stall_cycles", core.execute.stall_cycles),
      ("capture_cycles", core.capture_cycles),
    ] {
    execute_output(builder, name, signal)
  }
}
