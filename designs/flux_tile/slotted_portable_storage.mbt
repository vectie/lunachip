///|
priv struct SlottedPortableHostSlot {
  valid : @wire.RegisterHandle
  rows : @wire.RegisterHandle
  columns : @wire.RegisterHandle
}

///|
fn slotted_portable_host_slot(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
) -> SlottedPortableHostSlot raise {
  {
    valid: builder.register_state_in(domain, @wire.bits(1), reset~),
    rows: builder.register_state_in(domain, @wire.uint(13), reset~),
    columns: builder.register_state_in(domain, @wire.uint(13), reset~),
  }
}

///|
fn slotted_portable_lookup(
  builder : @wire.ModuleBuilder,
  slots : Array[SlottedPortableHostSlot],
  selection : @wire.Signal,
) -> (@wire.Signal, @wire.Signal, @wire.Signal) raise {
  let one = builder.equal(selection, execute_constant(builder, 1, 1))
  (
    builder.mux(one, slots[1].valid.value(), slots[0].valid.value()),
    builder.mux(one, slots[1].rows.value(), slots[0].rows.value()),
    builder.mux(one, slots[1].columns.value(), slots[0].columns.value()),
  )
}

///|
fn slotted_portable_publish(
  builder : @wire.ModuleBuilder,
  slots : Array[SlottedPortableHostSlot],
  selection : @wire.Signal,
  invalidate : @wire.Signal,
  finish : @wire.Signal,
  command : PortableCommand,
) -> Unit raise {
  for slot in 0..<2 {
    let selected = builder.equal(selection, execute_constant(builder, 1, slot))
    portable_slot(
      builder,
      slots[slot].valid,
      slots[slot].rows,
      slots[slot].columns,
      builder.bit_and(invalidate, selected),
      builder.bit_and(finish, selected),
      command,
    )
  }
}

///|
fn slotted_portable_storage(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  registers : PortableRegisters,
  command : PortableCommand,
  op : Array[@wire.Signal],
  selections : SlottedPortableSelections,
) -> PortableStorageControl raise {
  // Preserve the shared graph's original handles as authoritative slot0,
  // avoiding a second metadata driver or dead singular scoreboard.
  let a : Array[SlottedPortableHostSlot] = [
    {
      valid: registers.a_valid,
      rows: registers.a_rows,
      columns: registers.a_columns,
    },
    slotted_portable_host_slot(builder, domain, reset),
  ]
  let b : Array[SlottedPortableHostSlot] = [
    {
      valid: registers.b_valid,
      rows: registers.b_rows,
      columns: registers.b_columns,
    },
    slotted_portable_host_slot(builder, domain, reset),
  ]
  let c : Array[SlottedPortableHostSlot] = [
    {
      valid: registers.c_valid,
      rows: registers.c_rows,
      columns: registers.c_columns,
    },
    slotted_portable_host_slot(builder, domain, reset),
  ]
  let (a_valid, a_rows, a_columns) = slotted_portable_lookup(
    builder,
    a,
    selections.a.value(),
  )
  let (b_valid, b_rows, b_columns) = slotted_portable_lookup(
    builder,
    b,
    selections.b.value(),
  )
  let (c_valid, c_rows, c_columns) = slotted_portable_lookup(
    builder,
    c,
    selections.c.value(),
  )
  let a_zero = builder.equal(
    selections.a.value(),
    execute_constant(builder, 1, 0),
  )
  let b_zero = builder.equal(
    selections.b.value(),
    execute_constant(builder, 1, 0),
  )
  let c_zero = builder.equal(
    selections.c.value(),
    execute_constant(builder, 1, 0),
  )
  let unused_valid = builder.mux(
    op[0],
    builder.bit_and(b_zero, c_zero),
    builder.mux(
      op[1],
      builder.bit_and(a_zero, c_zero),
      builder.mux(
        op[2],
        builder.constant(@wire.bits(1), 1UL),
        builder.mux(
          op[3],
          builder.bit_and(a_zero, b_zero),
          execute_and(builder, [a_zero, b_zero, c_zero]),
        ),
      ),
    ),
  )
  {
    slots: {
      a_valid,
      a_rows,
      a_columns,
      b_valid,
      b_rows,
      b_columns,
      c_valid,
      c_rows,
      c_columns,
    },
    unused_selectors_valid: Some(unused_valid),
    finish: (validate_ok, finish_load, finish_compute) => {
      slotted_portable_publish(
        builder,
        a,
        selections.a.value(),
        builder.bit_and(validate_ok, op[0]),
        builder.bit_and(finish_load, op[0]),
        command,
      )
      slotted_portable_publish(
        builder,
        b,
        selections.b.value(),
        builder.bit_and(validate_ok, op[1]),
        builder.bit_and(finish_load, op[1]),
        command,
      )
      slotted_portable_publish(
        builder,
        c,
        selections.c.value(),
        builder.bit_and(validate_ok, op[2]),
        finish_compute,
        command,
      )
    },
  }
}
