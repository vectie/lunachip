///|
priv struct ConcurrentLoaderState {
  transfer : ConcurrentTransferState
  operand : @wire.RegisterHandle
  byte : @wire.RegisterHandle
}

///|
priv struct ConcurrentLoaderView {
  states : Array[@wire.Signal]
  active : @wire.Signal
  request : ArbiterRequest
  response_ready : @wire.Signal
  a_valid : @wire.Signal
  b_valid : @wire.Signal
  a_row : @wire.Signal
  a_index : @wire.Signal
  b_column : @wire.Signal
  b_index : @wire.Signal
  data : @wire.Signal
  slot : @wire.Signal
}

///|
fn concurrent_loader_state(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
) -> ConcurrentLoaderState raise {
  {
    transfer: concurrent_transfer_state(builder, domain, reset),
    operand: builder.register_state_in(domain, @wire.uint(1), reset~),
    byte: builder.register_state_in(domain, @wire.bits(32), reset~),
  }
}

///|
fn concurrent_loader_view(
  builder : @wire.ModuleBuilder,
  state : ConcurrentLoaderState,
  reset_inactive : @wire.Signal,
  poison : @wire.Signal,
) -> ConcurrentLoaderView raise {
  let transfer = state.transfer
  let states = concurrent_transfer_states(builder, transfer, reset_inactive)
  let active = builder.bit_or(states[1], builder.bit_or(states[2], states[3]))
  let permitted = builder.bit_not(poison)
  let row = transfer.row.value()
  let column = transfer.column.value()
  let cursor_valid = builder.bit_and(
    builder.less_than(row, transfer.rows.value()),
    builder.less_than(column, transfer.columns.value()),
  )
  let commit_window = execute_and(builder, [states[3], permitted, cursor_valid])
  let is_a = builder.equal(
    state.operand.value(),
    execute_constant(builder, 1, 0),
  )
  let is_b = builder.equal(
    state.operand.value(),
    execute_constant(builder, 1, 1),
  )
  // Keep lane coordinates at their full width until validated. Configured
  // row/column and reduction limits are also enforced by admission/core ready.
  let a_valid = execute_and(builder, [
    commit_window,
    is_a,
    builder.less_than(row, execute_constant(builder, 13, 8)),
  ])
  let b_valid = execute_and(builder, [
    commit_window,
    is_b,
    builder.less_than(column, execute_constant(builder, 13, 8)),
  ])
  let zero13 = execute_constant(builder, 13, 0)
  {
    states,
    active,
    request: {
      valid: builder.bit_and(states[1], permitted),
      write: builder.constant(@wire.bits(1), 0UL),
      address: portable_transfer_address(
        builder,
        transfer.base.value(),
        transfer.stride.value(),
        row,
        column,
        1,
      ),
      bytes: execute_constant(builder, 3, 1),
      mask: builder.constant(@wire.bits(4), 1UL),
      data: builder.constant(@wire.bits(32), 0UL),
      tag: transfer.tag.value(),
    },
    response_ready: states[2],
    a_valid,
    b_valid,
    a_row: builder.truncate(builder.mux(a_valid, row, zero13), 4),
    a_index: builder.mux(a_valid, column, zero13),
    b_column: builder.truncate(builder.mux(b_valid, column, zero13), 4),
    b_index: builder.mux(b_valid, row, zero13),
    data: builder.reinterpret(
      builder.slice(state.byte.value(), 7, 0),
      @wire.sint(8),
    ),
    slot: transfer.slot.value(),
  }
}
