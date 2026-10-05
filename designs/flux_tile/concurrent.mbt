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
  let signals = build_concurrent_graph(
    builder,
    domain,
    reset,
    reset_inactive,
    { load: load_ports, compute: compute_ports, store: store_ports, bus, },
    rows,
    columns,
    max_reduction,
    host_bytes,
  )
  concurrent_transfer_outputs(builder, "load", signals.load)
  concurrent_transfer_outputs(builder, "store", signals.store)
  for
    (name, signal) in [
      ("compute_command_ready", signals.compute.command_ready),
      ("compute_completion_valid", signals.compute.completion_valid),
      ("compute_completion_id", signals.compute.completion_id),
      ("compute_completion_fault", signals.compute.completion_fault),
    ] {
    execute_output(builder, name, signal)
  }
  concurrent_memory_outputs(builder, signals)
  builder.finish()
}

///|
fn concurrent_memory_outputs(
  builder : @wire.ModuleBuilder,
  signals : ConcurrentSignals,
) -> Unit raise {
  let memory = signals.memory
  let core = signals.stored
  for
    (name, signal) in [
      ("memory_request_valid", memory.request_valid),
      ("memory_request_write", memory.request_write),
      ("memory_request_address", memory.address),
      ("memory_request_bytes", memory.request_bytes),
      ("memory_request_mask", memory.request_mask),
      ("memory_request_data", memory.request_data),
      ("memory_request_tag", memory.request_tag),
      ("memory_response_ready", memory.response_ready),
      ("transport_halted", memory.halted),
      (
        "transport_fault_address",
        builder.mux(
          memory.halted,
          memory.address,
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
