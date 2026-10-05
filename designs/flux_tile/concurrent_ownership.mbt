///|
fn concurrent_compute_ready(
  builder : @wire.ModuleBuilder,
  ports : ConcurrentComputePorts,
  states : Array[@wire.Signal],
  loader : ConcurrentLoaderState,
  loader_view : ConcurrentLoaderView,
  store : ConcurrentTransferState,
  store_view : ConcurrentStorerView,
  live : @wire.Signal,
) -> @wire.Signal raise {
  let load_source = builder.mux(
    builder.equal(loader.operand.value(), execute_constant(builder, 1, 0)),
    ports.a,
    ports.b,
  )
  let load_conflict = builder.bit_and(
    loader_view.active,
    builder.equal(load_source, loader.transfer.slot.value()),
  )
  let store_conflict = builder.bit_and(
    store_view.active,
    builder.equal(ports.c, store.slot.value()),
  )
  execute_and(builder, [
    states[0],
    live,
    builder.bit_not(load_conflict),
    builder.bit_not(store_conflict),
  ])
}

///|
fn concurrent_load_ready(
  builder : @wire.ModuleBuilder,
  ports : ConcurrentTransferPorts,
  loader : ConcurrentLoaderView,
  compute : ConcurrentComputeState,
  candidate : ConcurrentComputePorts,
  legal_compute_accept : @wire.Signal,
  preflight : @wire.Signal,
  live : @wire.Signal,
) -> @wire.Signal raise {
  let a = builder.equal(ports.operand, execute_constant(builder, 1, 0))
  let old_source = builder.mux(a, compute.a.value(), compute.b.value())
  let new_source = builder.mux(a, candidate.a, candidate.b)
  let old_conflict = builder.bit_and(
    compute.leased.value(),
    builder.equal(ports.slot, old_source),
  )
  let new_conflict = execute_and(builder, [
    legal_compute_accept,
    builder.equal(preflight, execute_constant(builder, 4, 0)),
    builder.equal(ports.slot, new_source),
  ])
  execute_and(builder, [
    loader.states[0],
    live,
    builder.bit_not(old_conflict),
    builder.bit_not(new_conflict),
  ])
}

///|
fn concurrent_store_ready(
  builder : @wire.ModuleBuilder,
  ports : ConcurrentTransferPorts,
  store : ConcurrentStorerView,
  compute : ConcurrentComputeState,
  candidate : ConcurrentComputePorts,
  legal_compute_accept : @wire.Signal,
  preflight : @wire.Signal,
  live : @wire.Signal,
) -> @wire.Signal raise {
  let old_conflict = builder.bit_and(
    compute.leased.value(),
    builder.equal(ports.slot, compute.c.value()),
  )
  let new_conflict = execute_and(builder, [
    legal_compute_accept,
    builder.equal(preflight, execute_constant(builder, 4, 0)),
    builder.equal(ports.slot, candidate.c),
  ])
  execute_and(builder, [
    store.states[0],
    live,
    builder.bit_not(old_conflict),
    builder.bit_not(new_conflict),
  ])
}

///|
fn concurrent_operand_updates(
  builder : @wire.ModuleBuilder,
  a_slots : Array[SlottedPortableHostSlot],
  b_slots : Array[SlottedPortableHostSlot],
  ports : ConcurrentTransferPorts,
  loader : ConcurrentLoaderState,
  legal_accept : @wire.Signal,
  finish : @wire.Signal,
) -> Unit raise {
  for (operand, slots) in [(0, a_slots), (1, b_slots)] {
    for slot in 0..<2 {
      let invalidate = execute_and(builder, [
        legal_accept,
        builder.equal(ports.operand, execute_constant(builder, 1, operand)),
        builder.equal(ports.slot, execute_constant(builder, 1, slot)),
      ])
      let publish = execute_and(builder, [
        finish,
        builder.equal(
          loader.operand.value(),
          execute_constant(builder, 1, operand),
        ),
        builder.equal(
          loader.transfer.slot.value(),
          execute_constant(builder, 1, slot),
        ),
      ])
      let state = slots[slot]
      builder.connect_next(
        state.valid,
        builder.mux(
          invalidate,
          builder.constant(@wire.bits(1), 0UL),
          builder.mux(
            publish,
            builder.constant(@wire.bits(1), 1UL),
            state.valid.value(),
          ),
        ),
      )
      portable_hold(builder, state.rows, publish, loader.transfer.rows.value())
      portable_hold(
        builder,
        state.columns,
        publish,
        loader.transfer.columns.value(),
      )
    }
  }
}

///|
fn concurrent_result_available(
  builder : @wire.ModuleBuilder,
  slots : Array[SlottedResultFact],
  ports : ConcurrentTransferPorts,
) -> @wire.Signal raise {
  let one = builder.equal(ports.slot, execute_constant(builder, 1, 1))
  let valid = builder.mux(one, slots[1].valid, slots[0].valid)
  let rows = builder.zero_extend(
    builder.mux(one, slots[1].rows, slots[0].rows),
    13,
  )
  let columns = builder.zero_extend(
    builder.mux(one, slots[1].columns, slots[0].columns),
    13,
  )
  execute_and(builder, [
    valid,
    builder.equal(rows, ports.rows),
    builder.equal(columns, ports.columns),
  ])
}
