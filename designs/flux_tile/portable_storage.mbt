///|
priv struct PortableSlotSignals {
  a_valid : @wire.Signal
  a_rows : @wire.Signal
  a_columns : @wire.Signal
  b_valid : @wire.Signal
  b_rows : @wire.Signal
  b_columns : @wire.Signal
  c_valid : @wire.Signal
  c_rows : @wire.Signal
  c_columns : @wire.Signal
}

///|
priv struct PortableStorageControl {
  slots : PortableSlotSignals
  unused_selectors_valid : @wire.Signal?
  finish : (@wire.Signal, @wire.Signal, @wire.Signal) -> Unit raise
}

///|
fn portable_default_storage(
  builder : @wire.ModuleBuilder,
  registers : PortableRegisters,
  command : PortableCommand,
  op : Array[@wire.Signal],
) -> PortableStorageControl {
  {
    slots: {
      a_valid: registers.a_valid.value(),
      a_rows: registers.a_rows.value(),
      a_columns: registers.a_columns.value(),
      b_valid: registers.b_valid.value(),
      b_rows: registers.b_rows.value(),
      b_columns: registers.b_columns.value(),
      c_valid: registers.c_valid.value(),
      c_rows: registers.c_rows.value(),
      c_columns: registers.c_columns.value(),
    },
    unused_selectors_valid: None,
    // Defer all metadata-update nodes until the original controller position.
    finish: (validate_ok, finish_load, finish_compute) => {
      portable_slot(
        builder,
        registers.a_valid,
        registers.a_rows,
        registers.a_columns,
        builder.bit_and(validate_ok, op[0]),
        builder.bit_and(finish_load, op[0]),
        command,
      )
      portable_slot(
        builder,
        registers.b_valid,
        registers.b_rows,
        registers.b_columns,
        builder.bit_and(validate_ok, op[1]),
        builder.bit_and(finish_load, op[1]),
        command,
      )
      portable_slot(
        builder,
        registers.c_valid,
        registers.c_rows,
        registers.c_columns,
        builder.bit_and(validate_ok, op[2]),
        finish_compute,
        command,
      )
    },
  }
}
