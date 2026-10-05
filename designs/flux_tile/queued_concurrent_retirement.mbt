///|
priv struct QueuedConcurrentRetirement {
  valid : @wire.Signal
  id : @wire.Signal
  fault : @wire.Signal
  progress : @wire.Signal
  address : @wire.Signal
}

///|
fn queued_concurrent_retirement_connect(
  builder : @wire.ModuleBuilder,
  registers : QueuedConcurrentState,
  descriptor : QueuedConcurrentDescriptor,
  dispatch : QueuedConcurrentDispatch,
  engine : ConcurrentEngineSignals,
  reset_inactive : @wire.Signal,
  completion_ready : @wire.Signal,
  reject : @wire.Signal,
  local_fault : @wire.Signal,
  fence : @wire.Signal,
  depth : Int,
  queue_observations? : Array[QueueConservationObservation],
) -> QueuedConcurrentRetirement raise {
  let oldest_valid = queued_concurrent_select(
    builder,
    registers.read_pointer.value(),
    registers.entries.map(entry => entry.valid.value()),
  )
  let oldest_terminal = queued_concurrent_select(
    builder,
    registers.read_pointer.value(),
    registers.entries.map(entry => entry.terminal.value()),
  )
  let valid = execute_and(builder, [
    reset_inactive, oldest_valid, oldest_terminal,
  ])
  let retire = builder.bit_and(valid, completion_ready)
  let local_terminal = builder.bit_or(reject, fence)
  let zero32 = execute_constant(builder, 32, 0)
  let done = [
    engine.load.completion_valid,
    engine.compute.completion_valid,
    engine.store.completion_valid,
  ]
  let tickets = [
    engine.load.completion_id,
    engine.compute.completion_id,
    engine.store.completion_id,
  ]
  let faults = [
    engine.load.completion_fault,
    engine.compute.completion_fault,
    engine.store.completion_fault,
  ]
  let progresses = [
    engine.load.bytes_completed,
    zero32,
    engine.store.bytes_completed,
  ]
  let addresses = [
    engine.load.fault_address,
    zero32,
    engine.store.fault_address,
  ]
  for index in 0..<depth {
    let entry = registers.entries[index]
    let allocate = builder.bit_and(
      dispatch.reserve,
      builder.equal(
        registers.write_pointer.value(),
        execute_constant(builder, 5, index),
      ),
    )
    let acknowledge = builder.bit_and(
      retire,
      builder.equal(
        registers.read_pointer.value(),
        execute_constant(builder, 5, index),
      ),
    )
    let collect = Array::makei(3, ordinal => {
      execute_and(builder, [
        entry.valid.value(),
        builder.bit_not(entry.terminal.value()),
        done[ordinal],
        builder.equal(entry.ticket.value(), tickets[ordinal]),
      ])
    })
    let local_entry = builder.bit_and(
      local_terminal,
      builder.equal(
        registers.head_entry.value(),
        execute_constant(builder, 5, index),
      ),
    )
    match queue_observations {
      Some(observations) => {
        queue_conservation_reference(
          observations,
          EntryValid(index),
          entry.valid.value(),
        )
        queue_conservation_reference(
          observations,
          EntryTerminal(index),
          entry.terminal.value(),
        )
        queue_conservation_reference(
          observations,
          EntryTicket(index),
          entry.ticket.value(),
        )
        queue_conservation_reference(
          observations,
          EntryId(index),
          entry.id.value(),
        )
        queue_conservation_reference(
          observations,
          EntryFault(index),
          entry.fault.value(),
        )
        queue_conservation_reference(
          observations,
          EntryProgress(index),
          entry.progress.value(),
        )
        queue_conservation_reference(
          observations,
          EntryAddress(index),
          entry.address.value(),
        )
        queue_conservation_reference(
          observations,
          EntryAllocate(index),
          allocate,
        )
        queue_conservation_reference(
          observations,
          EntryAcknowledge(index),
          acknowledge,
        )
        queue_conservation_reference(
          observations,
          EntryLocalTerminal(index),
          local_entry,
        )
        for ordinal in 0..<3 {
          queue_conservation_reference(
            observations,
            EntryCollector(index, ordinal),
            collect[ordinal],
          )
        }
      }
      None => ()
    }
    let terminal = builder.bit_or(
      local_entry,
      builder.bit_or(collect[0], builder.bit_or(collect[1], collect[2])),
    )
    builder.connect_next(
      entry.valid,
      builder.mux(
        allocate,
        builder.constant(@wire.bits(1), 1UL),
        builder.mux(
          acknowledge,
          builder.constant(@wire.bits(1), 0UL),
          entry.valid.value(),
        ),
      ),
    )
    builder.connect_next(
      entry.terminal,
      builder.mux(
        allocate,
        builder.constant(@wire.bits(1), 0UL),
        builder.mux(
          terminal,
          builder.constant(@wire.bits(1), 1UL),
          entry.terminal.value(),
        ),
      ),
    )
    portable_hold(builder, entry.id, allocate, descriptor.command.id)
    portable_hold(
      builder,
      entry.ticket,
      allocate,
      registers.next_ticket.value(),
    )
    let mut fault = builder.mux(local_entry, local_fault, entry.fault.value())
    let mut progress = builder.mux(local_entry, zero32, entry.progress.value())
    let mut address = builder.mux(local_entry, zero32, entry.address.value())
    for ordinal in 0..<3 {
      fault = builder.mux(collect[ordinal], faults[ordinal], fault)
      progress = builder.mux(collect[ordinal], progresses[ordinal], progress)
      address = builder.mux(collect[ordinal], addresses[ordinal], address)
    }
    portable_hold(builder, entry.fault, terminal, fault)
    portable_hold(builder, entry.progress, terminal, progress)
    portable_hold(builder, entry.address, terminal, address)
  }
  queued_concurrent_pointer(builder, registers.read_pointer, retire, depth)
  queued_concurrent_pointer(
    builder,
    registers.write_pointer,
    dispatch.reserve,
    depth,
  )
  builder.connect_next(
    registers.occupancy,
    builder.mux(
      builder.equal(dispatch.reserve, retire),
      registers.occupancy.value(),
      builder.mux(
        dispatch.reserve,
        builder.add(
          registers.occupancy.value(),
          execute_constant(builder, 5, 1),
        ),
        builder.sub(
          registers.occupancy.value(),
          execute_constant(builder, 5, 1),
        ),
      ),
    ),
  )
  let retirement : QueuedConcurrentRetirement = {
    valid,
    id: queued_concurrent_select(
      builder,
      registers.read_pointer.value(),
      registers.entries.map(entry => entry.id.value()),
    ),
    fault: queued_concurrent_select(
      builder,
      registers.read_pointer.value(),
      registers.entries.map(entry => entry.fault.value()),
    ),
    progress: queued_concurrent_select(
      builder,
      registers.read_pointer.value(),
      registers.entries.map(entry => entry.progress.value()),
    ),
    address: queued_concurrent_select(
      builder,
      registers.read_pointer.value(),
      registers.entries.map(entry => entry.address.value()),
    ),
  }
  match queue_observations {
    Some(observations) => {
      queue_conservation_reference(
        observations,
        RetirementReadPointer,
        registers.read_pointer.value(),
      )
      queue_conservation_reference(
        observations,
        RetirementWritePointer,
        registers.write_pointer.value(),
      )
      queue_conservation_reference(
        observations,
        RetirementOccupancy,
        registers.occupancy.value(),
      )
      queue_conservation_reference(observations, RetirementFire, retire)
      queue_conservation_reference(
        observations,
        RetirementValid,
        retirement.valid,
      )
      queue_conservation_reference(observations, RetirementId, retirement.id)
      queue_conservation_reference(
        observations,
        RetirementFault,
        retirement.fault,
      )
      queue_conservation_reference(
        observations,
        RetirementProgress,
        retirement.progress,
      )
      queue_conservation_reference(
        observations,
        RetirementAddress,
        retirement.address,
      )
    }
    None => ()
  }
  retirement
}
