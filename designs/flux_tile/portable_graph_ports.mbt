///|
priv struct PortableSignals {
  command_ready : @wire.Signal
  completion_valid : @wire.Signal
  completion_id : @wire.Signal
  completion_fault : @wire.Signal
  bytes_completed : @wire.Signal
  fault_address : @wire.Signal
  request_valid : @wire.Signal
  request_write : @wire.Signal
  address : @wire.Signal
  request_bytes : @wire.Signal
  request_mask : @wire.Signal
  request_data : @wire.Signal
  request_tag : @wire.Signal
  response_ready : @wire.Signal
  accepted_steps : @wire.Signal
  elapsed_cycles : @wire.Signal
  active_cycles : @wire.Signal
  stall_cycles : @wire.Signal
  capture_cycles : @wire.Signal
}

///|
fn portable_builder(
  name : String,
  rows : Int32,
  columns : Int32,
  max_reduction : Int32,
  host_bytes : UInt64,
) -> @wire.ModuleBuilder raise {
  if host_bytes == 0UL || host_bytes > 4294967296UL {
    raise PortableTileError::InvalidHostBytes(
      value=host_bytes,
      maximum=4294967296UL,
    )
  }
  let builder = execute_builder(name, rows, columns, max_reduction)
  builder.parameter("host_bytes", Unsigned(host_bytes))
  builder
}

///|
fn portable_memory_outputs(
  builder : @wire.ModuleBuilder,
  signals : PortableSignals,
) -> Unit raise {
  execute_output(builder, "memory_request_valid", signals.request_valid)
  execute_output(builder, "memory_request_write", signals.request_write)
  execute_output(builder, "memory_request_address", signals.address)
  execute_output(builder, "memory_request_bytes", signals.request_bytes)
  execute_output(builder, "memory_request_mask", signals.request_mask)
  execute_output(builder, "memory_request_data", signals.request_data)
  execute_output(builder, "memory_request_tag", signals.request_tag)
  execute_output(builder, "memory_response_ready", signals.response_ready)
  execute_output(builder, "accepted_steps", signals.accepted_steps)
  execute_output(builder, "elapsed_cycles", signals.elapsed_cycles)
  execute_output(builder, "active_cycles", signals.active_cycles)
  execute_output(builder, "stall_cycles", signals.stall_cycles)
  execute_output(builder, "capture_cycles", signals.capture_cycles)
}

///|
/// Construct the provisional serial host-memory FluxTile command engine.
/// LoadA/LoadB, MatMul, StoreC, and Fence execute in real hardware; the single
/// outstanding memory transaction is acknowledged before reuse. Reset is a
/// joint device/transport flush barrier. See PHASE6_TRANSPORT_DRAFT.md.
///
/// ```mbt check
/// test {
///   assert_eq(
///     @flux_tile.portable_tile(
///       rows=1,
///       columns=1,
///       max_reduction=4,
///       host_bytes=256UL,
///     )
///     .memories()
///     .length(),
///     3,
///   )
/// }
/// ```
pub fn portable_tile(
  rows~ : Int32,
  columns~ : Int32,
  max_reduction~ : Int32,
  host_bytes~ : UInt64,
) -> @ir.Module raise {
  let builder = portable_builder(
    "FluxTilePortable", rows, columns, max_reduction, host_bytes,
  )
  let clock = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock)
  let reset_signal = builder.input("reset", @wire.reset())
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let reset_inactive = builder.bit_not(builder.reset_asserted(reset_signal))
  let ports = portable_inputs(builder)
  let signals = build_portable_graph(
    builder, domain, reset, reset_inactive, ports, rows, columns, max_reduction,
    host_bytes,
  )
  execute_output(builder, "command_ready", signals.command_ready)
  execute_output(builder, "completion_valid", signals.completion_valid)
  execute_output(builder, "completion_id", signals.completion_id)
  execute_output(builder, "completion_fault", signals.completion_fault)
  execute_output(builder, "completion_bytes_completed", signals.bytes_completed)
  execute_output(builder, "completion_fault_address", signals.fault_address)
  portable_memory_outputs(builder, signals)
  builder.finish()
}
