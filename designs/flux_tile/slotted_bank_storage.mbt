///|
priv struct SlottedOperandBanks {
  data : Array[@wire.Signal]
  valid : Array[@wire.Signal]
  prefixes : Array[@wire.Signal]
  finish : (@wire.Signal) -> @wire.Signal raise
}

///|
fn slotted_operand_banks(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  reset_inactive : @wire.Signal,
  name : String,
  bank_count : Int,
  capacity : Int,
  load_valid : @wire.Signal,
  load_bank : @wire.Signal,
  load_index : @wire.Signal,
  load_data : @wire.Signal,
  load_slot : @wire.Signal,
  command_slot : @wire.Signal,
  active_slot : @wire.Signal,
  accept : @wire.Signal,
  read_launch : @wire.Signal,
  read_step : @wire.Signal,
  active_banks : @wire.Signal,
  reduction : @wire.Signal,
  ownership_active : @wire.Signal,
) -> SlottedOperandBanks raise {
  let address_width = @ir.MemoryDepth::new(capacity).address_width().bits()
  let write_address = builder.truncate(load_index, address_width)
  let memories : Array[@wire.Memory] = []
  let prefix_registers : Array[@wire.RegisterHandle] = []
  let data : Array[@wire.Signal] = []
  let valid : Array[@wire.Signal] = []
  let prefixes : Array[@wire.Signal] = []
  let active_one = builder.equal(active_slot, execute_constant(builder, 1, 1))
  let command_one = builder.equal(command_slot, execute_constant(builder, 1, 1))
  for ordinal in 0..<bank_count {
    let offset = execute_constant(builder, 13, ordinal)
    let index = builder.sub(read_step, offset)
    let in_window = execute_and(builder, [
      builder.less_than(execute_constant(builder, 4, ordinal), active_banks),
      builder.greater_equal(read_step, offset),
      builder.less_than(index, reduction),
    ])
    let safe_index = builder.mux(
      in_window,
      index,
      execute_constant(builder, 13, 0),
    )
    let read_address = builder.truncate(safe_index, address_width)
    let read_enable = execute_and(builder, [
      reset_inactive, read_launch, in_window,
    ])
    let bank_data : Array[@wire.Signal] = []
    let bank_prefixes : Array[@wire.Signal] = []
    for slot in 0..<2 {
      let prefix = builder.register_state_in(domain, @wire.uint(13), reset~)
      prefix_registers.push(prefix)
      bank_prefixes.push(prefix.value())
      let selected = builder.equal(
        active_slot,
        execute_constant(builder, 1, slot),
      )
      let memory = builder.synchronous_memory(
        "\{name}_slot_\{slot}_bank_\{ordinal}",
        @wire.sint(8),
        capacity,
        domain,
        read_write_policy=ReadOld,
        multi_write_policy=Reject,
        bounds_policy=Fault,
      )
      memories.push(memory)
      bank_data.push(
        builder.memory_read(
          memory,
          "read",
          read_address,
          enable=builder.bit_and(read_enable, selected),
          enable_behavior=HoldLast,
        ),
      )
    }
    data.push(builder.mux(active_one, bank_data[1], bank_data[0]))
    prefixes.push(builder.mux(command_one, bank_prefixes[1], bank_prefixes[0]))
    // The wrapper latches the active selector on command acceptance and
    // holds it through Run/capture. The qualifier advances with the same
    // read-launch schedule and holds with synchronous data during a pause.
    valid.push(
      builder.register_in(domain, in_window, reset~, enable=read_launch),
    )
  }
  {
    data,
    valid,
    prefixes,
    finish: legal => {
      let old_conflict = builder.bit_and(
        ownership_active,
        builder.equal(load_slot, active_slot),
      )
      let new_conflict = execute_and(builder, [
        accept,
        legal,
        builder.equal(load_slot, command_slot),
      ])
      let permit = execute_and(builder, [
        reset_inactive,
        builder.bit_not(old_conflict),
        builder.bit_not(new_conflict),
      ])
      let mut load_ready = builder.constant(@wire.bits(1), 0UL)
      for ordinal in 0..<bank_count {
        for slot in 0..<2 {
          let index = ordinal * 2 + slot
          let prefix = prefix_registers[index]
          let ready = execute_and(builder, [
            permit,
            builder.equal(load_slot, execute_constant(builder, 1, slot)),
            builder.equal(load_bank, execute_constant(builder, 4, ordinal)),
            builder.less_than(
              load_index,
              execute_constant(builder, 13, capacity),
            ),
            builder.less_equal(load_index, prefix.value()),
          ])
          load_ready = builder.bit_or(load_ready, ready)
          let write = builder.bit_and(ready, load_valid)
          let extend_prefix = builder.bit_and(
            write,
            builder.equal(load_index, prefix.value()),
          )
          builder.connect_next(
            prefix,
            builder.mux(
              extend_prefix,
              builder.add(prefix.value(), execute_constant(builder, 13, 1)),
              prefix.value(),
            ),
          )
          builder.memory_write(
            memories[index],
            "write",
            write_address,
            load_data,
            enable=write,
          )
        }
      }
      load_ready
    },
  }
}
