///|
priv struct ConcurrentComputePorts {
  valid : @wire.Signal
  id : @wire.Signal
  a : @wire.Signal
  b : @wire.Signal
  c : @wire.Signal
  rows : @wire.Signal
  columns : @wire.Signal
  reduction : @wire.Signal
  completion_ready : @wire.Signal
}

///|
priv struct ConcurrentComputeState {
  state : @wire.RegisterHandle
  leased : @wire.RegisterHandle
  id : @wire.RegisterHandle
  a : @wire.RegisterHandle
  b : @wire.RegisterHandle
  c : @wire.RegisterHandle
  rows : @wire.RegisterHandle
  columns : @wire.RegisterHandle
  reduction : @wire.RegisterHandle
  fault : @wire.RegisterHandle
}

///|
fn concurrent_compute_inputs(
  builder : @wire.ModuleBuilder,
) -> ConcurrentComputePorts raise {
  {
    valid: builder.input("compute_command_valid", @wire.bits(1)),
    id: builder.input("compute_command_id", @wire.uint(32)),
    a: builder.input("compute_command_a_slot", @wire.uint(1)),
    b: builder.input("compute_command_b_slot", @wire.uint(1)),
    c: builder.input("compute_command_c_slot", @wire.uint(1)),
    rows: builder.input("compute_command_rows", @wire.uint(13)),
    columns: builder.input("compute_command_columns", @wire.uint(13)),
    reduction: builder.input("compute_command_reduction", @wire.uint(13)),
    completion_ready: builder.input("compute_completion_ready", @wire.bits(1)),
  }
}

///|
fn concurrent_compute_state(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
) -> ConcurrentComputeState raise {
  {
    state: builder.register_state_in(domain, @wire.uint(2), reset~),
    leased: builder.register_state_in(domain, @wire.bits(1), reset~),
    id: builder.register_state_in(domain, @wire.uint(32), reset~),
    a: builder.register_state_in(domain, @wire.uint(1), reset~),
    b: builder.register_state_in(domain, @wire.uint(1), reset~),
    c: builder.register_state_in(domain, @wire.uint(1), reset~),
    rows: builder.register_state_in(domain, @wire.uint(13), reset~),
    columns: builder.register_state_in(domain, @wire.uint(13), reset~),
    reduction: builder.register_state_in(domain, @wire.uint(13), reset~),
    fault: builder.register_state_in(domain, @wire.uint(4), reset~),
  }
}

///|
fn concurrent_compute_states(
  builder : @wire.ModuleBuilder,
  state : ConcurrentComputeState,
  reset_inactive : @wire.Signal,
) -> Array[@wire.Signal] raise {
  Array::makei(4, index => {
    builder.bit_and(
      reset_inactive,
      builder.equal(state.state.value(), execute_constant(builder, 2, index)),
    )
  })
}

///|
fn concurrent_compute_fault(
  builder : @wire.ModuleBuilder,
  ports : ConcurrentComputePorts,
  a_slots : Array[SlottedPortableHostSlot],
  b_slots : Array[SlottedPortableHostSlot],
  rows : Int,
  columns : Int,
  capacity : Int,
) -> @wire.Signal raise {
  let (a_valid, a_rows, a_columns) = slotted_portable_lookup(
    builder,
    a_slots,
    ports.a,
  )
  let (b_valid, b_rows, b_columns) = slotted_portable_lookup(
    builder,
    b_slots,
    ports.b,
  )
  let available = execute_and(builder, [
    a_valid,
    b_valid,
    builder.equal(a_rows, ports.rows),
    builder.equal(a_columns, ports.reduction),
    builder.equal(b_rows, ports.reduction),
    builder.equal(b_columns, ports.columns),
  ])
  let dimensions = execute_and(builder, [
    portable_positive(builder, ports.rows, rows),
    portable_positive(builder, ports.columns, columns),
    portable_positive(builder, ports.reduction, capacity),
  ])
  builder.mux(
    dimensions,
    builder.mux(
      available,
      execute_constant(builder, 4, 0),
      execute_constant(builder, 4, 4),
    ),
    execute_constant(builder, 4, 3),
  )
}

///|
fn concurrent_compute_connect(
  builder : @wire.ModuleBuilder,
  registers : ConcurrentComputeState,
  ports : ConcurrentComputePorts,
  states : Array[@wire.Signal],
  accept : @wire.Signal,
  preflight : @wire.Signal,
  graph : SlottedGraphSignals,
  store_observations? : Array[StorePreservationObservation],
) -> Unit raise {
  let core = graph.stored.execute
  let legal = builder.equal(preflight, execute_constant(builder, 4, 0))
  let legal_accept = builder.bit_and(accept, legal)
  let terminal = builder.bit_and(states[2], core.completion_valid)
  let release = builder.bit_or(
    graph.final_capture,
    builder.bit_and(terminal, builder.bit_not(graph.ownership_active)),
  )
  match store_observations {
    Some(observations) =>
      store_preservation_events(observations, [
        (ComputeAccept, accept),
        (ComputePreflight, preflight),
        (ComputeLegalAccept, legal_accept),
        (ComputeTerminal, terminal),
        (ComputeRelease, release),
      ])
    None => ()
  }
  builder.connect_next(
    registers.leased,
    builder.mux(
      legal_accept,
      builder.constant(@wire.bits(1), 1UL),
      builder.mux(
        release,
        builder.constant(@wire.bits(1), 0UL),
        registers.leased.value(),
      ),
    ),
  )
  for
    (handle, value) in [
      (registers.id, ports.id),
      (registers.a, ports.a),
      (registers.b, ports.b),
      (registers.c, ports.c),
      (registers.rows, ports.rows),
      (registers.columns, ports.columns),
      (registers.reduction, ports.reduction),
    ] {
    portable_hold(builder, handle, accept, value)
  }
  let internal_good = builder.bit_and(
    builder.equal(core.completion_fault, execute_constant(builder, 2, 0)),
    builder.equal(core.completion_id, registers.id.value()),
  )
  builder.connect_next(
    registers.fault,
    builder.mux(
      accept,
      preflight,
      builder.mux(
        terminal,
        builder.mux(
          internal_good,
          execute_constant(builder, 4, 0),
          execute_constant(builder, 4, 11),
        ),
        registers.fault.value(),
      ),
    ),
  )
  let idle = execute_constant(builder, 2, 0)
  let issue = execute_constant(builder, 2, 1)
  let run = execute_constant(builder, 2, 2)
  let done = execute_constant(builder, 2, 3)
  let hold = registers.state.value()
  builder.connect_next(
    registers.state,
    builder.mux(
      accept,
      builder.mux(legal, issue, done),
      builder.mux(
        builder.bit_and(states[1], core.command_ready),
        run,
        builder.mux(
          terminal,
          done,
          builder.mux(
            builder.bit_and(states[3], ports.completion_ready),
            idle,
            hold,
          ),
        ),
      ),
    ),
  )
}
