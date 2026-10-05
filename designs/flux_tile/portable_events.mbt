///|
priv struct PortableEvents {
  request_accept : @wire.Signal
  response_ready : @wire.Signal
  response_good : @wire.Signal
  response_remote : @wire.Signal
  response_protocol : @wire.Signal
  load_commit : @wire.Signal
  compute_done : @wire.Signal
  internal_fault : @wire.Signal
  last_column : @wire.Signal
  last : @wire.Signal
  validate_ok : @wire.Signal
}

///|
fn portable_events(
  builder : @wire.ModuleBuilder,
  ports : PortablePorts,
  command : PortableCommand,
  registers : PortableRegisters,
  states : Array[@wire.Signal],
  op : Array[@wire.Signal],
  core : StoredSignals,
  preflight : @wire.Signal,
  request_valid : @wire.Signal,
) -> PortableEvents raise {
  let request_accept = builder.bit_and(request_valid, ports.request_ready)
  let response_ready = builder.bit_or(states[3], states[9])
  let response = transfer_response(
    builder,
    {
      request_ready: ports.request_ready,
      response_valid: ports.response_valid,
      response_tag: ports.response_tag,
      response_fault: ports.response_fault,
      response_data: ports.response_data,
    },
    registers.expected_tag.value(),
    response_ready,
  )
  let response_protocol = response.protocol
  let response_good = response.good
  let response_remote = response.remote
  let load_commit = builder.bit_and(
    states[4],
    builder.mux(op[0], core.execute.load_a_ready, core.execute.load_b_ready),
  )
  let compute_done = builder.bit_and(states[6], core.execute.completion_valid)
  // Preserve nested identities as functional checks, not unobserved state.
  // A mismatched internal response must never publish success or issue data.
  let compute_fault = builder.bit_and(
    compute_done,
    builder.bit_or(
      builder.bit_not(
        builder.equal(
          core.execute.completion_fault,
          execute_constant(builder, 2, 0),
        ),
      ),
      builder.bit_not(builder.equal(core.execute.completion_id, command.id)),
    ),
  )
  let read_fault = execute_and(builder, [
    states[8],
    core.response_valid,
    builder.bit_or(
      builder.bit_not(
        builder.equal(core.response_fault, execute_constant(builder, 2, 0)),
      ),
      builder.bit_not(builder.equal(core.response_id, command.id)),
    ),
  ])
  let (last_column, last) = transfer_cursor_limits(
    builder,
    registers.row.value(),
    registers.column.value(),
    command.rows,
    command.columns,
  )
  let validate_ok = builder.bit_and(
    states[1],
    builder.equal(preflight, execute_constant(builder, 4, 0)),
  )
  {
    request_accept,
    response_ready,
    response_good,
    response_remote,
    response_protocol,
    load_commit,
    compute_done,
    internal_fault: builder.bit_or(compute_fault, read_fault),
    last_column,
    last,
    validate_ok,
  }
}
