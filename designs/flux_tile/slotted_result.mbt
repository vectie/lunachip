///|
fn slotted_result_storage(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  reset_inactive : @wire.Signal,
  registers : SlottedState,
  ports : SlottedInputs,
  core : ExecuteSignals,
  legal_accept : @wire.Signal,
  ownership_active : @wire.Signal,
  capture : @wire.Signal,
  final_capture : @wire.Signal,
  rows : Int32,
  columns : Int32,
  store_observations? : Array[StorePreservationObservation],
) -> SlottedResultSignals raise {
  let input = ports.stored
  let active_conflict = builder.bit_and(
    ownership_active,
    builder.equal(ports.read_slot, registers.active_c.value()),
  )
  let new_conflict = builder.bit_and(
    legal_accept,
    builder.equal(ports.read_slot, ports.command_c_slot),
  )
  let read_ready = execute_and(builder, [
    reset_inactive,
    builder.bit_not(registers.pending.value()),
    builder.bit_not(active_conflict),
    builder.bit_not(new_conflict),
  ])
  let read_accept = builder.bit_and(read_ready, input.read_valid)
  portable_hold(builder, registers.response_slot, read_accept, ports.read_slot)
  builder.connect_next(
    registers.pending,
    builder.mux(
      read_accept,
      builder.constant(@wire.bits(1), 1UL),
      builder.bit_and(
        registers.pending.value(),
        builder.bit_not(input.response_ready),
      ),
    ),
  )
  let fault_choices : Array[@wire.Signal] = []
  let data_choices : Array[@wire.Signal] = []
  let slots : Array[SlottedResultFact] = []
  for slot in 0..<2 {
    let slot_value = execute_constant(builder, 1, slot)
    let selected_read = builder.equal(ports.read_slot, slot_value)
    let selected_capture = builder.equal(registers.active_c.value(), slot_value)
    let invalidate = builder.bit_and(
      legal_accept,
      builder.equal(ports.command_c_slot, slot_value),
    )
    let finish = builder.bit_and(final_capture, selected_capture)
    let valid = builder.register_state_in(domain, @wire.bits(1), reset~)
    builder.connect_next(
      valid,
      builder.mux(
        invalidate,
        builder.constant(@wire.bits(1), 0UL),
        builder.mux(finish, builder.constant(@wire.bits(1), 1UL), valid.value()),
      ),
    )
    let stored_rows = execute_latch(
      builder,
      domain,
      reset,
      finish,
      core.active_rows,
    )
    let stored_columns = execute_latch(
      builder,
      domain,
      reset,
      finish,
      core.active_columns,
    )
    match store_observations {
      Some(observations) => {
        store_preservation_reference(
          observations,
          ResultValid(slot),
          valid.value(),
        )
        store_preservation_reference(
          observations,
          ResultRows(slot),
          stored_rows,
        )
        store_preservation_reference(
          observations,
          ResultColumns(slot),
          stored_columns,
        )
      }
      None => ()
    }
    slots.push({
      valid: valid.value(),
      rows: stored_rows,
      columns: stored_columns,
    })
    let in_bounds = builder.bit_and(
      builder.less_than(input.read_row, stored_rows),
      builder.less_than(input.read_column, stored_columns),
    )
    fault_choices.push(
      builder.mux(
        valid.value(),
        builder.mux(
          in_bounds,
          execute_constant(builder, 2, 0),
          execute_constant(builder, 2, 1),
        ),
        execute_constant(builder, 2, 2),
      ),
    )
    data_choices.push(
      stored_result_memory(
        builder,
        domain,
        "c_result_slot_\{slot}",
        rows,
        columns,
        builder.bit_and(capture, selected_capture),
        registers.capture_row.value(),
        registers.capture_column.value(),
        core.accumulators,
        builder.bit_and(read_accept, selected_read),
        valid.value(),
        in_bounds,
        input.read_row,
        input.read_column,
      ),
    )
  }
  let read_one = builder.equal(ports.read_slot, execute_constant(builder, 1, 1))
  let response_fault = execute_latch(
    builder,
    domain,
    reset,
    read_accept,
    builder.mux(read_one, fault_choices[1], fault_choices[0]),
  )
  let response_id = execute_latch(
    builder,
    domain,
    reset,
    read_accept,
    input.read_id,
  )
  let response_valid = builder.bit_and(
    registers.pending.value(),
    reset_inactive,
  )
  let response_one = builder.equal(
    registers.response_slot.value(),
    execute_constant(builder, 1, 1),
  )
  let response_data = builder.mux(
    builder.bit_and(
      response_valid,
      builder.equal(response_fault, execute_constant(builder, 2, 0)),
    ),
    builder.mux(response_one, data_choices[1], data_choices[0]),
    builder.constant(@wire.sint(32), 0UL),
  )
  match store_observations {
    Some(observations) => {
      for slot in 0..<2 {
        store_preservation_reference(
          observations,
          CReadData(slot),
          data_choices[slot],
        )
      }
      store_preservation_reference(observations, ResponseId, response_id)
      store_preservation_reference(observations, ResponseFault, response_fault)
      store_preservation_events(observations, [
        (ReadReady, read_ready),
        (ReadAccept, read_accept),
        (ResponseValid, response_valid),
        (ResponseData, response_data),
      ])
    }
    None => ()
  }
  {
    read_ready,
    response_valid,
    response_id,
    response_fault,
    response_data,
    slots,
  }
}
