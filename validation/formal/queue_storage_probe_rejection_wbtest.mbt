///|
fn queue_storage_test_reject(action : () -> Unit raise) -> Unit raise {
  try action() catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("storage discovery raised an unrelated error")
  } noraise {
    _ => fail("storage discovery accepted an invalid original inventory")
  }
}

///|
test "queue storage discovery rejects same size root drift and omitted or aliased storage" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let probe = queue_storage_probe(fixture)
  let seeds = queue_storage_test_seeds(probe)
  queue_storage_test_reject(() => {
    ignore(
      queue_storage_probe_walk(
        fixture,
        probe.roots[1:],
        probe.lanes,
        probe.events,
        seeds,
        probe.reset,
      ),
    )
  })
  queue_storage_test_reject(() => {
    ignore(
      queue_storage_probe_walk(
        fixture,
        probe.roots,
        probe.lanes[1:],
        probe.events,
        seeds,
        probe.reset,
      ),
    )
  })
  queue_storage_test_reject(() => {
    ignore(
      queue_storage_probe_walk(
        fixture,
        probe.roots,
        probe.lanes,
        probe.events[1:],
        seeds,
        probe.reset,
      ),
    )
  })
  let wrong_event = probe.events.iter().to_array()
  wrong_event[0] = { ..wrong_event[0], name: "fabricated_public_admission", }
  queue_storage_test_reject(() => {
    ignore(
      queue_storage_probe_walk(
        fixture,
        probe.roots,
        probe.lanes,
        wrong_event,
        seeds,
        probe.reset,
      ),
    )
  })
  let renamed = probe.roots.iter().to_array()
  renamed[18] = { ..renamed[18], name: "unrelated_saved_payload", }
  queue_storage_test_reject(() => {
    ignore(
      queue_storage_probe_walk(
        fixture,
        renamed,
        probe.lanes,
        probe.events,
        seeds,
        probe.reset,
      ),
    )
  })
  let substituted = probe.roots.iter().to_array()
  let unrelated_state = queue_control_root(
    fixture.hardware(),
    queue_control_binding(fixture, EngineState(1)),
    probe.clock,
    probe.reset,
  )
  assert_eq(substituted[8].signal_type, unrelated_state.signal_type)
  assert_false(probe.roots.any(root => root.node == unrelated_state.node))
  substituted[8] = unrelated_state
  queue_storage_test_reject(() => {
    ignore(
      queue_storage_probe_walk(
        fixture,
        substituted,
        probe.lanes,
        probe.events,
        seeds,
        probe.reset,
      ),
    )
  })
  let reordered = probe.roots.iter().to_array()
  let first_head = reordered[18]
  reordered[18] = reordered[21]
  reordered[21] = first_head
  queue_storage_test_reject(() => {
    ignore(
      queue_storage_probe_walk(
        fixture,
        reordered,
        probe.lanes,
        probe.events,
        seeds,
        probe.reset,
      ),
    )
  })
  let aliased = probe.lanes.iter().to_array()
  aliased[1] = { ..aliased[0], lane: 1, }
  queue_storage_test_reject(() => {
    ignore(
      queue_storage_probe_walk(
        fixture,
        probe.roots,
        aliased,
        probe.events,
        seeds,
        probe.reset,
      ),
    )
  })
  for omitted in 0..<seeds.length() {
    let incomplete : Array[QueueStorageProbeSeed] = []
    for index, seed in seeds {
      if index != omitted {
        incomplete.push(seed)
      }
    }
    queue_storage_test_reject(() => {
      ignore(
        queue_storage_probe_walk(
          fixture,
          probe.roots,
          probe.lanes,
          probe.events,
          incomplete,
          probe.reset,
        ),
      )
    })
    let changed = seeds.iter().to_array()
    changed[omitted] = { ..changed[omitted], node: probe.clock, }
    queue_storage_test_reject(() => {
      ignore(
        queue_storage_probe_walk(
          fixture,
          probe.roots,
          probe.lanes,
          probe.events,
          changed,
          probe.reset,
        ),
      )
    })
  }
  let wrong_origin = seeds.iter().to_array()
  wrong_origin[0] = { ..wrong_origin[0], origin: WriteData(0), }
  queue_storage_test_reject(() => {
    ignore(
      queue_storage_probe_walk(
        fixture,
        probe.roots,
        probe.lanes,
        probe.events,
        wrong_origin,
        probe.reset,
      ),
    )
  })
  queue_storage_test_reject(() => {
    ignore(
      queue_storage_probe_walk(
        fixture,
        probe.roots,
        probe.lanes,
        probe.events,
        [{ origin: Event("unexpected_clock"), node: probe.clock, }],
        probe.reset,
      ),
    )
  })
  let foreign_reads = fixture
    .hardware()
    .nodes()
    .filter(node => {
      node.kind() is MemoryRead(..) &&
      !probe.lanes.any(lane => lane.result.id() == node.id())
    })
  assert_false(foreign_reads.is_empty())
  for node in foreign_reads {
    queue_storage_test_reject(() => {
      ignore(
        queue_storage_probe_walk(
          fixture,
          probe.roots,
          probe.lanes,
          probe.events,
          [{ origin: ReadResult(0), node: node.id(), }],
          probe.reset,
        ),
      )
    })
  }
}

///|
test "queue storage lane validation rejects original policy port address and pointer drift" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let source = fixture.hardware()
  let probe = queue_storage_probe(fixture)
  let lane = probe.lanes[0]
  let memory = lane.memory
  let policy_drift = @ir.MemorySpec::new(
    memory.id(),
    memory.name(),
    memory.element_type(),
    memory.depth(),
    memory.domain(),
    memory.read_ports(),
    memory.write_ports(),
    NoChange,
    memory.multi_write_policy(),
    memory.bounds_policy(),
  )
  let enable = lane.read.enable()
  let undefined_read = @ir.MemoryReadPort::new(
    lane.read.id(),
    lane.read.name(),
    lane.read.domain(),
    lane.read.address(),
    enable?,
    OneCycle,
    Undefined,
    lane.read.result(),
  )
  let read_drift = @ir.MemorySpec::new(
    memory.id(),
    memory.name(),
    memory.element_type(),
    memory.depth(),
    memory.domain(),
    [undefined_read],
    memory.write_ports(),
    memory.read_write_policy(),
    memory.multi_write_policy(),
    memory.bounds_policy(),
  )
  for changed in [policy_drift, read_drift] {
    let memories = source.memories().iter().to_array()
    for index, original in memories {
      if original.id() == memory.id() {
        memories[index] = changed
      }
    }
    let changed_source = @ir.Module::checked_with_metadata(
      source.name(),
      source.domains(),
      source.nodes(),
      memories,
      source.outputs(),
      source.metadata(),
    )
    let changed_lane = {
      ..lane,
      memory: changed,
      read: changed.read_ports()[0],
    }
    queue_storage_test_reject(() => {
      queue_storage_validate_lane(
        changed_source,
        changed_lane,
        probe.clock,
        probe.reset,
      )
    })
  }
  let pointer = lane.read_pointer
  let reset = pointer.spec.reset()
  let enable = pointer.spec.enable()
  let initialized = @ir.RegisterSpec::new(
    pointer.spec.domain(),
    pointer.spec.next(),
    reset?,
    enable?,
    initial=0UL,
  )
  for
    changed in [
      { ..lane, lane: 4, },
      { ..lane, public_data: probe.lanes[1].public_data, },
      { ..lane, read_pointer: lane.write_pointer, },
      { ..lane, result: probe.lanes[1].result, },
      { ..lane, read_pointer: { ..pointer, spec: initialized, }, },
    ] {
    queue_storage_test_reject(() => {
      queue_storage_validate_lane(source, changed, probe.clock, probe.reset)
    })
  }
}
