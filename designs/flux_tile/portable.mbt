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
  rows~ : Int,
  columns~ : Int,
  max_reduction~ : Int,
  host_bytes~ : UInt64,
) -> @ir.Module raise {
  if host_bytes == 0UL || host_bytes > 4294967296UL {
    raise PortableTileError::InvalidHostBytes(
      value=host_bytes,
      maximum=4294967296UL,
    )
  }
  let builder = execute_builder(
    "FluxTilePortable", rows, columns, max_reduction,
  )
  builder.parameter("host_bytes", Unsigned(host_bytes))
  let clock = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock)
  let reset_signal = builder.input("reset", @wire.reset())
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let reset_inactive = builder.bit_not(builder.reset_asserted(reset_signal))
  let ports = portable_inputs(builder)
  let registers = portable_registers(builder, domain, reset)
  // State ordinals: Idle, Validate, LoadRequest, LoadWait, LoadCommit,
  // ComputeIssue, ComputeWait, StoreRead, StoreRequest, StoreWait, Done.
  let states : Array[@wire.Signal] = []
  for index in 0..<11 {
    states.push(
      builder.bit_and(
        builder.equal(
          registers.state.value(),
          execute_constant(builder, 4, index),
        ),
        reset_inactive,
      ),
    )
  }
  let command_ready = builder.bit_and(
    states[0],
    builder.bit_not(registers.locked.value()),
  )
  let accept = builder.bit_and(command_ready, ports.command_valid)
  let command = portable_command(builder, domain, reset, accept, ports)
  let op : Array[@wire.Signal] = []
  for index in 0..<5 {
    op.push(builder.equal(command.opcode, execute_constant(builder, 3, index)))
  }
  let preflight = portable_preflight(
    builder, command, op, registers, rows, columns, max_reduction, host_bytes,
  )
  let zero_bit = builder.constant(@wire.bits(1), 0UL)
  let one_bit = builder.constant(@wire.bits(1), 1UL)
  let byte = builder.reinterpret(
    builder.slice(registers.load_byte.value(), 7, 0),
    @wire.sint(8),
  )
  let core_inputs : StoredInputs = {
    execute: {
      load_a_valid: builder.bit_and(states[4], op[0]),
      load_a_row: builder.truncate(registers.row.value(), 4),
      load_a_index: registers.column.value(),
      load_a_data: byte,
      load_b_valid: builder.bit_and(states[4], op[1]),
      load_b_column: builder.truncate(registers.column.value(), 4),
      load_b_index: registers.row.value(),
      load_b_data: byte,
      command_valid: states[5],
      command_rows: builder.truncate(command.rows, 4),
      command_columns: builder.truncate(command.columns, 4),
      command_reduction: command.reduction,
      command_id: command.id,
      step_ready: one_bit,
      completion_ready: states[6],
    },
    read_valid: states[7],
    read_row: builder.truncate(registers.row.value(), 4),
    read_column: builder.truncate(registers.column.value(), 4),
    read_id: command.id,
    response_ready: builder.bit_or(states[9], states[10]),
  }
  let core = build_stored_graph(
    builder, domain, reset, reset_inactive, core_inputs, rows, columns, max_reduction,
  )
  let store_payload = execute_and(builder, [
    states[8],
    core.response_valid,
    builder.equal(core.response_fault, execute_constant(builder, 2, 0)),
    builder.equal(core.response_id, command.id),
  ])
  let request_valid = builder.bit_and(
    builder.bit_or(states[2], store_payload),
    builder.bit_not(registers.locked.value()),
  )
  // Only successfully preflighted operation states assert request-valid.
  // Wide address arithmetic is explicitly narrowed after that validation.
  let byte_address = portable_transfer_address(
    builder,
    command.base,
    command.stride,
    registers.row.value(),
    registers.column.value(),
    1,
  )
  let word_address = portable_transfer_address(
    builder,
    command.base,
    command.stride,
    registers.row.value(),
    registers.column.value(),
    4,
  )
  let address = builder.mux(op[3], word_address, byte_address)
  let events = portable_events(
    builder, ports, command, registers, states, op, core, preflight, request_valid,
  )
  portable_controller(
    builder, registers, ports, command, states, op, accept, preflight, core, events,
    address,
  )
  execute_output(builder, "command_ready", command_ready)
  execute_output(builder, "completion_valid", states[10])
  execute_output(builder, "completion_id", command.id)
  execute_output(builder, "completion_fault", registers.fault.value())
  execute_output(
    builder,
    "completion_bytes_completed",
    registers.bytes_completed.value(),
  )
  execute_output(
    builder,
    "completion_fault_address",
    registers.fault_address.value(),
  )
  execute_output(builder, "memory_request_valid", request_valid)
  execute_output(
    builder,
    "memory_request_write",
    builder.mux(op[3], one_bit, zero_bit),
  )
  execute_output(builder, "memory_request_address", address)
  execute_output(
    builder,
    "memory_request_bytes",
    builder.mux(
      op[3],
      execute_constant(builder, 3, 4),
      execute_constant(builder, 3, 1),
    ),
  )
  execute_output(
    builder,
    "memory_request_mask",
    builder.mux(
      op[3],
      builder.constant(@wire.bits(4), 15UL),
      builder.constant(@wire.bits(4), 1UL),
    ),
  )
  execute_output(
    builder,
    "memory_request_data",
    builder.mux(
      op[3],
      builder.reinterpret(core.response_data, @wire.bits(32)),
      builder.constant(@wire.bits(32), 0UL),
    ),
  )
  execute_output(builder, "memory_request_tag", registers.tag.value())
  execute_output(builder, "memory_response_ready", events.response_ready)
  execute_output(builder, "accepted_steps", core.execute.accepted_steps)
  execute_output(builder, "elapsed_cycles", core.execute.elapsed_cycles)
  execute_output(builder, "active_cycles", core.execute.active_cycles)
  execute_output(builder, "stall_cycles", core.execute.stall_cycles)
  execute_output(builder, "capture_cycles", core.capture_cycles)
  builder.finish()
}
