///|
priv struct ConcurrentTransferPorts {
  valid : @wire.Signal
  operand : @wire.Signal
  slot : @wire.Signal
  id : @wire.Signal
  rows : @wire.Signal
  columns : @wire.Signal
  base : @wire.Signal
  stride : @wire.Signal
  completion_ready : @wire.Signal
}

///|
priv struct ConcurrentTransferState {
  state : @wire.RegisterHandle
  slot : @wire.RegisterHandle
  id : @wire.RegisterHandle
  rows : @wire.RegisterHandle
  columns : @wire.RegisterHandle
  base : @wire.RegisterHandle
  stride : @wire.RegisterHandle
  row : @wire.RegisterHandle
  column : @wire.RegisterHandle
  tag : @wire.RegisterHandle
  expected_tag : @wire.RegisterHandle
  progress : @wire.RegisterHandle
  fault : @wire.RegisterHandle
  fault_address : @wire.RegisterHandle
}

///|
fn concurrent_transfer_state(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
) -> ConcurrentTransferState raise {
  {
    state: builder.register_state_in(domain, @wire.uint(3), reset~),
    slot: builder.register_state_in(domain, @wire.uint(1), reset~),
    id: builder.register_state_in(domain, @wire.uint(32), reset~),
    rows: builder.register_state_in(domain, @wire.uint(13), reset~),
    columns: builder.register_state_in(domain, @wire.uint(13), reset~),
    base: builder.register_state_in(domain, @wire.uint(32), reset~),
    stride: builder.register_state_in(domain, @wire.uint(32), reset~),
    row: builder.register_state_in(domain, @wire.uint(13), reset~),
    column: builder.register_state_in(domain, @wire.uint(13), reset~),
    tag: builder.register_state_in(domain, @wire.uint(32), reset~),
    expected_tag: builder.register_state_in(domain, @wire.uint(32), reset~),
    progress: builder.register_state_in(domain, @wire.uint(32), reset~),
    fault: builder.register_state_in(domain, @wire.uint(4), reset~),
    fault_address: builder.register_state_in(domain, @wire.uint(32), reset~),
  }
}

///|
fn concurrent_transfer_inputs(
  builder : @wire.ModuleBuilder,
  prefix : String,
  load : Bool,
) -> ConcurrentTransferPorts raise {
  let valid = builder.input(prefix + "_command_valid", @wire.bits(1))
  let slot = builder.input(prefix + "_command_slot", @wire.uint(1))
  {
    valid,
    operand: if load {
      builder.input(prefix + "_command_operand", @wire.uint(1))
    } else {
      // Store has no operand input. Reuse an existing UInt1 reference for
      // this ignored construction field, without an unreachable constant.
      slot
    },
    slot,
    id: builder.input(prefix + "_command_id", @wire.uint(32)),
    rows: builder.input(prefix + "_command_rows", @wire.uint(13)),
    columns: builder.input(prefix + "_command_columns", @wire.uint(13)),
    base: builder.input(prefix + "_command_base", @wire.uint(32)),
    stride: builder.input(prefix + "_command_stride", @wire.uint(32)),
    completion_ready: builder.input(prefix + "_completion_ready", @wire.bits(1)),
  }
}

///|
fn concurrent_transfer_latch(
  builder : @wire.ModuleBuilder,
  registers : ConcurrentTransferState,
  ports : ConcurrentTransferPorts,
  accept : @wire.Signal,
) -> Unit raise {
  for
    (handle, value) in [
      (registers.slot, ports.slot),
      (registers.id, ports.id),
      (registers.rows, ports.rows),
      (registers.columns, ports.columns),
      (registers.base, ports.base),
      (registers.stride, ports.stride),
    ] {
    portable_hold(builder, handle, accept, value)
  }
}

///|
fn concurrent_transfer_states(
  builder : @wire.ModuleBuilder,
  registers : ConcurrentTransferState,
  reset_inactive : @wire.Signal,
) -> Array[@wire.Signal] raise {
  Array::makei(5, index => {
    builder.bit_and(
      reset_inactive,
      builder.equal(
        registers.state.value(),
        execute_constant(builder, 3, index),
      ),
    )
  })
}

///|
fn concurrent_transfer_outputs(
  builder : @wire.ModuleBuilder,
  prefix : String,
  signals : ConcurrentTransferSignals,
) -> Unit raise {
  for
    (name, signal) in [
      ("command_ready", signals.command_ready),
      ("completion_valid", signals.completion_valid),
      ("completion_id", signals.completion_id),
      ("completion_fault", signals.completion_fault),
      ("completion_bytes_completed", signals.bytes_completed),
      ("completion_fault_address", signals.fault_address),
    ] {
    execute_output(builder, prefix + "_" + name, signal)
  }
}
