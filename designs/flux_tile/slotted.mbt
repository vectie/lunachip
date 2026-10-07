///|
/// Construct two real A/B/C storage slots around one shared systolic array.
/// Slot inputs are UInt1. MatMul holds its sources through final C capture;
/// inactive operand loads and independent C reads may overlap computation.
/// Older held C responses block overwrites through their ACK edge. Legal
/// commands win new same-edge conflicts. Reset invalidates, but does not erase,
/// SRAM. This direct indexed prototype does not freeze a descriptor ABI.
/// See PHASE6_SLOTS.md for ownership and timing.
///
/// ```mbt check
/// test {
///   assert_eq(
///     @flux_tile.slotted_execute_tile(rows=1, columns=1, max_reduction=4)
///     .memories()
///     .length(),
///     6,
///   )
/// }
/// ```
pub fn slotted_execute_tile(
  rows~ : Int,
  columns~ : Int,
  max_reduction~ : Int,
) -> @ir.Module raise {
  let builder = execute_builder(
    "FluxTileSlottedExecute", rows, columns, max_reduction,
  )
  builder.parameter("slot_count", Signed(2))
  let clock = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock)
  let reset_signal = builder.input("reset", @wire.reset())
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let reset_inactive = builder.bit_not(builder.reset_asserted(reset_signal))
  let ports = slotted_inputs(builder)
  let registers = slotted_state(builder, domain, reset)
  let signals = build_slotted_graph(
    builder, domain, reset, reset_inactive, ports, registers, rows, columns, max_reduction,
  )
  stored_outputs(builder, signals.stored, rows, columns)
  execute_output(builder, "completion_c_slot", registers.active_c.value())
  execute_output(
    builder,
    "result_response_slot",
    registers.response_slot.value(),
  )
  builder.finish()
}

///|
fn build_slotted_graph(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  reset_inactive : @wire.Signal,
  ports : SlottedInputs,
  registers : SlottedState,
  rows : Int,
  columns : Int,
  max_reduction : Int,
  store_observations? : Array[StorePreservationObservation],
) -> SlottedGraphSignals raise {
  match store_observations {
    Some(observations) =>
      store_preservation_slotted_references(observations, registers)
    None => ()
  }
  let inputs = ports.stored.execute
  let states = Array::makei(4, index => {
    builder.bit_and(
      reset_inactive,
      builder.equal(
        registers.state.value(),
        execute_constant(builder, 2, index),
      ),
    )
  })
  // Idle, Computing, Capturing, held Done. Leases are released only after
  // full capture, independently of the caller's completion acknowledgement.
  let ownership_active = builder.bit_or(states[1], states[2])
  let older_read_conflict = builder.bit_and(
    registers.pending.value(),
    builder.equal(ports.command_c_slot, registers.response_slot.value()),
  )
  let command_window = builder.bit_and(
    states[0],
    builder.bit_not(older_read_conflict),
  )
  let core_inputs = {
    ..inputs,
    command_valid: builder.bit_and(inputs.command_valid, command_window),
  }
  let core = build_execute_graph(
    builder,
    domain,
    reset,
    reset_inactive,
    core_inputs,
    rows,
    columns,
    max_reduction,
    (active_rows, active_columns, fault, core_done) => {
      let success = builder.equal(fault, execute_constant(builder, 2, 0))
      let capture = builder.bit_or(
        states[2],
        execute_and(builder, [states[1], core_done, success]),
      )
      let final_capture = stored_capture_final(
        builder,
        capture,
        registers.capture_row.value(),
        registers.capture_column.value(),
        active_rows,
        active_columns,
      )
      let fault_ack = execute_and(builder, [
        states[3],
        inputs.completion_ready,
        builder.bit_not(success),
      ])
      builder.bit_or(final_capture, fault_ack)
    },
    storage_control=context => {
      slotted_operand_storage(
        builder,
        domain,
        reset,
        reset_inactive,
        core_inputs,
        context,
        rows,
        columns,
        max_reduction,
        ports.load_a_slot,
        ports.load_b_slot,
        ports.command_a_slot,
        ports.command_b_slot,
        registers.active_a.value(),
        registers.active_b.value(),
        ownership_active,
      )
    },
    store_observations?,
  )
  let command_ready = builder.bit_and(command_window, core.command_ready)
  let accept = builder.bit_and(command_ready, inputs.command_valid)
  let legal_accept = builder.bit_and(accept, core.legal)
  for
    (handle, selection) in [
      (registers.active_a, ports.command_a_slot),
      (registers.active_b, ports.command_b_slot),
      (registers.active_c, ports.command_c_slot),
    ] {
    portable_hold(builder, handle, accept, selection)
  }
  let success = builder.equal(
    core.completion_fault,
    execute_constant(builder, 2, 0),
  )
  let capture = builder.bit_or(
    states[2],
    execute_and(builder, [states[1], core.completion_valid, success]),
  )
  let final_capture = stored_capture_final(
    builder,
    capture,
    registers.capture_row.value(),
    registers.capture_column.value(),
    core.active_rows,
    core.active_columns,
  )
  match store_observations {
    Some(observations) =>
      store_preservation_events(observations, [
        (SlottedAccept, accept),
        (SlottedLegalAccept, legal_accept),
        (OwnershipActive, ownership_active),
        (Capture, capture),
        (FinalCapture, final_capture),
      ])
    None => ()
  }
  stored_capture_updates(
    builder,
    registers.state,
    registers.capture_row,
    registers.capture_column,
    accept,
    capture,
    final_capture,
    core.active_columns,
    states[3],
    inputs.completion_ready,
    core.legal,
  )
  let result = slotted_result_storage(
    builder,
    domain,
    reset,
    reset_inactive,
    registers,
    ports,
    core,
    legal_accept,
    ownership_active,
    capture,
    final_capture,
    rows,
    columns,
    store_observations?,
  )
  let execute = { ..core, command_ready, completion_valid: states[3], }
  let stored : StoredSignals = {
    execute,
    capture_cycles: execute_counter(builder, domain, reset, 7, accept, capture),
    read_ready: result.read_ready,
    response_valid: result.response_valid,
    response_id: result.response_id,
    response_fault: result.response_fault,
    response_data: result.response_data,
  }
  { stored, result_slots: result.slots, final_capture, ownership_active, }
}
