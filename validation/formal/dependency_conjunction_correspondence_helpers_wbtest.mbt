///|
// Finite original-device correspondence, not acceptance of this fresh union
// boundary or a theorem. Only original public/raw foreign leaves are mirrored.
priv struct DependencyConjunctionCorrespondence {
  slice : DependencyConjunctionSequential
  projection : @sim.Simulator
  accepts : Array[Int32]
  terminals : Array[Int32]
  mut pre_pending : Bool
  mut pre_samples : Int32
  mut post_samples : Int32
  mut unknown_roots : Int32
  mut unknown_cuts : Int32
  mut unknown_reads : Int32
  mut unknown_cells : Int32
  mut reset_edges : Int32
  mut inner_accepts : Int32
  mut nonrising_events : Int32
}

///|
fn dependency_conjunction_correspondence_prepare(
  queue_fixture : @flux_tile.QueueConservationFixture,
  dependency_fixture : @flux_tile.QueuedConcurrentFormalFixture,
) -> DependencyConjunctionCorrespondence raise {
  let slice = dependency_conjunction_sequential(
    queue_fixture, dependency_fixture,
  )
  assert_eq(slice.probe.packet.source, queue_fixture.hardware())
  assert_eq(slice.probe.packet.source, dependency_fixture.hardware())
  assert_eq(slice.probe.bindings.length(), 48)
  assert_eq(slice.probe.observations.length(), 163)
  assert_eq(slice.probe.packet.lanes.length(), 4)
  for lane in slice.probe.packet.lanes {
    assert_eq(lane.memory.depth().elements(), 3)
  }
  {
    slice,
    projection: @sim.Simulator::prepare(slice.hardware),
    accepts: [0, 0, 0],
    terminals: [0, 0, 0],
    pre_pending: false,
    pre_samples: 0,
    post_samples: 0,
    unknown_roots: 0,
    unknown_cuts: 0,
    unknown_reads: 0,
    unknown_cells: 0,
    reset_edges: 0,
    inner_accepts: 0,
    nonrising_events: 0,
  }
}

///|
fn dependency_conjunction_correspondence_compare(
  observer : DependencyConjunctionCorrespondence,
  source : @sim.Simulator,
) -> Unit raise {
  let slice = observer.slice
  for cut in slice.cuts {
    let value = source.value(cut.node)
    observer.projection.set_input("cut_n\{cut.node.ordinal()}", value)
    if !value.is_fully_known() {
      observer.unknown_cuts += 1
    }
  }
  observer.projection.settle()
  // Independently compare EVERY selected original nonclock node: this includes
  // all register next/control cones, not just the named observation aliases.
  for original in slice.probe.packet.source.nodes() {
    if original.id() != slice.probe.packet.clock {
      if slice.original_to_local[original.id().ordinal()] is Some(mapped) {
        assert_eq(
          observer.projection.value(mapped),
          source.value(original.id()),
        )
      }
    }
  }
  for root in slice.probe.roots {
    let actual = source.value(root.node)
    assert_eq(observer.projection.output("current_" + root.name), actual)
    if !actual.is_fully_known() {
      observer.unknown_roots += 1
    }
  }
  for observation in slice.probe.observations {
    assert_eq(
      observer.projection.output(observation.name),
      source.value(observation.node),
    )
  }
  for output in slice.probe.packet.source.outputs() {
    assert_eq(
      observer.projection.output("public_" + output.name()),
      source.output(output.name()),
    )
  }
  for lane in slice.probe.packet.lanes {
    let actual = source.value(lane.result.id())
    let mapped = dependency_generation_mapped(
      slice.original_to_local,
      lane.result.id(),
    )
    assert_eq(observer.projection.value(mapped), actual)
    if !actual.is_fully_known() {
      observer.unknown_reads += 1
    }
    let memory = queue_storage_sequential_mapped_memory(
      slice.original_to_local_memory,
      lane.memory.id(),
    )
    let copied = slice.hardware.memories()[memory.ordinal()]
    for address in 0..<lane.memory.depth().elements() {
      let cell = source.memory_cell(lane.memory.name(), address)
      assert_eq(observer.projection.memory_cell(copied.name(), address), cell)
      if !cell.is_fully_known() {
        observer.unknown_cells += 1
      }
    }
  }
  assert_eq(observer.projection.time(), source.time())
  assert_eq(observer.projection.cycle(), source.cycle())
  assert_eq(observer.projection.event_ordinal(), source.event_ordinal())
  assert_eq(
    observer.projection.domain_edge_count(slice.hardware.domains()[0].id()),
    source.domain_edge_count(slice.probe.packet.source.domains()[0].id()),
  )
}

///|
fn dependency_conjunction_correspondence_read(
  observer : DependencyConjunctionCorrespondence,
  source : @sim.Simulator,
  role : @flux_tile.QueuedConcurrentFormalRole,
) -> UInt64 raise {
  let binding = dependency_generation_binding(
    observer.slice.probe.bindings,
    role,
  )
  let value = source.value(binding.node)
  assert_true(value.is_fully_known())
  value.to_uint64()
}

///|
fn dependency_conjunction_correspondence_tick(
  observer : DependencyConjunctionCorrespondence,
  source : @sim.Simulator,
) -> Unit raise {
  assert_false(observer.pre_pending)
  source.settle()
  dependency_conjunction_correspondence_compare(observer, source)
  observer.pre_pending = true
  observer.pre_samples += 1
  let reset = source.value(observer.slice.probe.packet.reset)
  assert_true(reset.is_fully_known())
  if reset.to_uint64() == 1UL {
    // Never decode unknown startup state to a binary integer.
    observer.reset_edges += 1
  } else {
    for
      engine, role in [
        @flux_tile.QueuedConcurrentFormalRole::LoadAccept,
        ComputeAccept,
        StoreAccept,
      ] {
      if dependency_conjunction_correspondence_read(observer, source, role) ==
        1UL {
        observer.accepts[engine] += 1
      }
    }
    for
      engine, role in [
        @flux_tile.QueuedConcurrentFormalRole::LoadTerminal,
        ComputeTerminal,
        StoreTerminal,
      ] {
      if dependency_conjunction_correspondence_read(observer, source, role) ==
        1UL {
        observer.terminals[engine] += 1
      }
    }
    if dependency_conjunction_correspondence_read(
        observer,
        source,
        InnerCommandValid,
      ) ==
      1UL &&
      dependency_conjunction_correspondence_read(
        observer,
        source,
        InnerCommandReady,
      ) ==
      1UL {
      observer.inner_accepts += 1
    }
  }
  source.rising_edge("clock")
  // Do not remirror POST foreign producer state before the projection commits
  // the PRE inputs saved by compare. Each DUT commits exactly once.
  observer.projection.rising_edge("clock")
  observer.post_samples += 1
  observer.pre_pending = false
  dependency_conjunction_correspondence_compare(observer, source)
}

///|
fn dependency_conjunction_correspondence_storage(
  observer : DependencyConjunctionCorrespondence,
  source : @sim.Simulator,
) -> Array[@wave.LogicValue] raise {
  let values : Array[@wave.LogicValue] = []
  for lane in observer.slice.probe.packet.lanes {
    values.push(source.value(lane.result.id()))
    for address in 0..<lane.memory.depth().elements() {
      values.push(source.memory_cell(lane.memory.name(), address))
    }
  }
  values
}

///|
// Actual drive-only timestamp events while the original Load is awaiting its
// delayed response. Clock levels do not infer edges; raw peer cuts may change.
fn dependency_conjunction_correspondence_nonrising(
  observer : DependencyConjunctionCorrespondence,
  source : @sim.Simulator,
) -> Unit raise {
  assert_false(observer.pre_pending)
  source.settle()
  dependency_conjunction_correspondence_compare(observer, source)
  let saved_roots = observer.slice.probe.roots.map(root => {
    source.value(root.node)
  })
  let saved_storage = dependency_conjunction_correspondence_storage(
    observer, source,
  )
  let saved_cycle = source.cycle()
  let saved_edges = source.domain_edge_count(
    observer.slice.probe.packet.source.domains()[0].id(),
  )
  let names = ["clock", "memory_request_ready", "memory_response_data"]
  let saved_drives : Array[@sim.InputDrive] = []
  for name in names {
    let node = observer.slice.probe.packet.source
      .nodes()
      .filter(node => node.kind() == Input(name))
    assert_eq(node.length(), 1)
    saved_drives.push(
      @sim.InputDrive::checked(name, source.value(node[0].id())),
    )
  }
  for level in [0UL, 1UL] {
    let before = observer.slice.cuts.map(cut => source.value(cut.node))
    let drives = [
      @sim.InputDrive::checked(
        "clock",
        @wave.LogicValue::from_uint64(width=1, value=level),
      ),
      @sim.InputDrive::checked(
        "memory_request_ready",
        @wave.LogicValue::from_uint64(width=1, value=level),
      ),
      @sim.InputDrive::checked(
        "memory_response_data",
        @wave.LogicValue::from_uint64(width=32, value=0x55555555UL + level),
      ),
    ]
    source.apply_event(
      @sim.TimestampEvent::drives_only(source.time().next(), drives),
    )
    observer.projection.apply_event(
      @sim.TimestampEvent::drives_only(observer.projection.time().next(), [
        drives[0],
      ]),
    )
    dependency_conjunction_correspondence_compare(observer, source)
    let mut changed = 0
    for index, cut in observer.slice.cuts {
      if source.value(cut.node) != before[index] {
        changed += 1
      }
    }
    assert_true(changed > 0)
    for index, root in observer.slice.probe.roots {
      assert_eq(source.value(root.node), saved_roots[index])
    }
    assert_eq(
      dependency_conjunction_correspondence_storage(observer, source),
      saved_storage,
    )
    assert_eq(source.cycle(), saved_cycle)
    assert_eq(
      source.domain_edge_count(
        observer.slice.probe.packet.source.domains()[0].id(),
      ),
      saved_edges,
    )
    observer.nonrising_events += 1
  }
  source.apply_event(
    @sim.TimestampEvent::drives_only(source.time().next(), saved_drives),
  )
  observer.projection.apply_event(
    @sim.TimestampEvent::drives_only(observer.projection.time().next(), [
      saved_drives[0],
    ]),
  )
  dependency_conjunction_correspondence_compare(observer, source)
  for index, root in observer.slice.probe.roots {
    assert_eq(source.value(root.node), saved_roots[index])
  }
  assert_eq(
    dependency_conjunction_correspondence_storage(observer, source),
    saved_storage,
  )
  assert_eq(source.cycle(), saved_cycle)
  assert_eq(
    source.domain_edge_count(
      observer.slice.probe.packet.source.domains()[0].id(),
    ),
    saved_edges,
  )
  observer.nonrising_events += 1
}
