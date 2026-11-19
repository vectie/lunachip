///|
fn concurrent_loader_connect(
  builder : @wire.ModuleBuilder,
  state : ConcurrentLoaderState,
  ports : ConcurrentTransferPorts,
  view : ConcurrentLoaderView,
  route : ArbiterClientRoute,
  core : StoredSignals,
  accept : @wire.Signal,
  preflight : @wire.Signal,
  poison : @wire.Signal,
) -> @wire.Signal raise {
  let transfer = state.transfer
  concurrent_transfer_latch(builder, transfer, ports, accept)
  portable_hold(builder, state.operand, accept, ports.operand)
  let request_accept = builder.bit_and(view.request.valid, route.request_ready)
  let response = transfer_response(
    builder,
    route,
    transfer.expected_tag.value(),
    view.response_ready,
  )
  let commit = builder.bit_or(
    builder.bit_and(view.a_valid, core.execute.load_a_ready),
    builder.bit_and(view.b_valid, core.execute.load_b_ready),
  )
  let (_, last) = concurrent_cursor(builder, transfer, accept, commit)
  let finish = builder.bit_and(commit, last)
  portable_hold(
    builder,
    transfer.tag,
    request_accept,
    builder.add(transfer.tag.value(), execute_constant(builder, 32, 1)),
  )
  portable_hold(
    builder,
    transfer.expected_tag,
    request_accept,
    transfer.tag.value(),
  )
  match state.remaining {
    None =>
      portable_hold(builder, state.byte, response.good, route.response_data)
    Some(remaining) => {
      // A successful word is committed one signed byte at a time through the
      // existing bank-ready channel. Held commits retain data and cursor.
      builder.connect_next(
        state.byte,
        builder.mux(
          response.good,
          route.response_data,
          builder.mux(
            commit,
            builder.logical_shift_right(
              state.byte.value(),
              execute_constant(builder, 6, 8),
            ),
            state.byte.value(),
          ),
        ),
      )
      builder.connect_next(
        remaining,
        builder.mux(
          accept,
          execute_constant(builder, 2, 0),
          builder.mux(
            request_accept,
            builder.mux(
              builder.equal(view.request.bytes, execute_constant(builder, 3, 4)),
              execute_constant(builder, 2, 3),
              execute_constant(builder, 2, 0),
            ),
            builder.mux(
              builder.bit_and(
                commit,
                builder.greater_than(
                  remaining.value(),
                  execute_constant(builder, 2, 0),
                ),
              ),
              builder.sub(remaining.value(), execute_constant(builder, 2, 1)),
              remaining.value(),
            ),
          ),
        ),
      )
    }
  }
  builder.connect_next(
    transfer.progress,
    builder.mux(
      accept,
      execute_constant(builder, 32, 0),
      builder.mux(
        commit,
        builder.add(transfer.progress.value(), execute_constant(builder, 32, 1)),
        transfer.progress.value(),
      ),
    ),
  )
  let cancel = builder.bit_and(view.active, poison)
  let terminal_response = builder.bit_or(response.protocol, response.remote)
  let failed = builder.bit_or(terminal_response, cancel)
  let failure_fault = builder.mux(
    response.protocol,
    execute_constant(builder, 4, 10),
    builder.mux(
      response.remote,
      execute_constant(builder, 4, 9),
      execute_constant(builder, 4, 15),
    ),
  )
  builder.connect_next(
    transfer.fault,
    builder.mux(
      accept,
      preflight,
      builder.mux(failed, failure_fault, transfer.fault.value()),
    ),
  )
  builder.connect_next(
    transfer.fault_address,
    builder.mux(
      accept,
      execute_constant(builder, 32, 0),
      builder.mux(
        terminal_response,
        view.request.address,
        builder.mux(
          cancel,
          execute_constant(builder, 32, 0),
          transfer.fault_address.value(),
        ),
      ),
    ),
  )
  let idle_value = execute_constant(builder, 3, 0)
  let request_value = execute_constant(builder, 3, 1)
  let wait_value = execute_constant(builder, 3, 2)
  let commit_value = execute_constant(builder, 3, 3)
  let done_value = execute_constant(builder, 3, 4)
  let hold = transfer.state.value()
  let on_request = builder.mux(request_accept, wait_value, hold)
  let on_wait = builder.mux(response.good, commit_value, hold)
  let on_commit = builder.mux(
    commit,
    builder.mux(
      last,
      done_value,
      match state.remaining {
        None => request_value
        Some(remaining) =>
          builder.mux(
            builder.greater_than(
              remaining.value(),
              execute_constant(builder, 2, 0),
            ),
            commit_value,
            request_value,
          )
      },
    ),
    hold,
  )
  let on_done = builder.mux(ports.completion_ready, idle_value, hold)
  let running_next = builder.mux(
    view.states[1],
    on_request,
    builder.mux(
      view.states[2],
      on_wait,
      builder.mux(
        view.states[3],
        on_commit,
        builder.mux(view.states[4], on_done, hold),
      ),
    ),
  )
  builder.connect_next(
    transfer.state,
    builder.mux(
      accept,
      builder.mux(
        builder.equal(preflight, execute_constant(builder, 4, 0)),
        request_value,
        done_value,
      ),
      builder.mux(failed, done_value, running_next),
    ),
  )
  finish
}
