///|
priv struct SlottedInputs {
  stored : StoredInputs
  load_a_slot : @wire.Signal
  load_b_slot : @wire.Signal
  command_a_slot : @wire.Signal
  command_b_slot : @wire.Signal
  command_c_slot : @wire.Signal
  read_slot : @wire.Signal
}

///|
priv struct SlottedState {
  state : @wire.RegisterHandle
  capture_row : @wire.RegisterHandle
  capture_column : @wire.RegisterHandle
  pending : @wire.RegisterHandle
  active_a : @wire.RegisterHandle
  active_b : @wire.RegisterHandle
  active_c : @wire.RegisterHandle
  response_slot : @wire.RegisterHandle
}

///|
priv struct SlottedResultSignals {
  read_ready : @wire.Signal
  response_valid : @wire.Signal
  response_id : @wire.Signal
  response_fault : @wire.Signal
  response_data : @wire.Signal
}

///|
fn slotted_inputs(builder : @wire.ModuleBuilder) -> SlottedInputs raise {
  let stored = stored_inputs(builder)
  {
    stored,
    load_a_slot: builder.input("load_a_slot", @wire.uint(1)),
    load_b_slot: builder.input("load_b_slot", @wire.uint(1)),
    command_a_slot: builder.input("command_a_slot", @wire.uint(1)),
    command_b_slot: builder.input("command_b_slot", @wire.uint(1)),
    command_c_slot: builder.input("command_c_slot", @wire.uint(1)),
    read_slot: builder.input("result_read_slot", @wire.uint(1)),
  }
}

///|
fn slotted_state(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
) -> SlottedState raise {
  {
    state: builder.register_state_in(domain, @wire.uint(2), reset~),
    capture_row: builder.register_state_in(domain, @wire.uint(4), reset~),
    capture_column: builder.register_state_in(domain, @wire.uint(4), reset~),
    pending: builder.register_state_in(domain, @wire.bits(1), reset~),
    active_a: builder.register_state_in(domain, @wire.uint(1), reset~),
    active_b: builder.register_state_in(domain, @wire.uint(1), reset~),
    active_c: builder.register_state_in(domain, @wire.uint(1), reset~),
    response_slot: builder.register_state_in(domain, @wire.uint(1), reset~),
  }
}
