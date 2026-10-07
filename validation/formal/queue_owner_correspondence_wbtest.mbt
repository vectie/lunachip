///|
// Finite native correspondence only: actual production boundary values drive
// the retained sequential cone. No ownership invariant, reachability premise,
// shadow controller, alternate host model or accepted formal result is added.
priv struct QueueOwnerCorrespondence {
  fixture : @flux_tile.QueueConservationFixture
  sequential : QueueOwnerSequential
  projection : @sim.Simulator
  accepts : Array[Int]
  collections : Array[Int]
  mut pre_pending : Bool
  mut pre_samples : Int
  mut post_samples : Int
  mut unknown_root_samples : Int
  mut reset_edges : Int
  mut later_reset_held : Int
  mut local_terminals : Int
  mut retirements : Int
  mut held_edges : Int
  mut fresh_admissions : Int
  mut fresh_reservations : Int
  mut fresh_local_terminals : Int
  mut fresh_retirements : Int
}

///|
fn queue_owner_correspondence_prepare(
  fixture : @flux_tile.QueueConservationFixture,
) -> QueueOwnerCorrespondence raise {
  let sequential = queue_owner_sequential(fixture)
  assert_eq(sequential.plan.probe.roots.length(), 30)
  assert_eq(sequential.plan.probe.events.length(), 59)
  assert_eq(sequential.plan.cuts.length(), 82)
  {
    fixture,
    sequential,
    projection: @sim.Simulator::prepare(sequential.hardware),
    accepts: [0, 0, 0],
    collections: [0, 0, 0],
    pre_pending: false,
    pre_samples: 0,
    post_samples: 0,
    unknown_root_samples: 0,
    reset_edges: 0,
    later_reset_held: 0,
    local_terminals: 0,
    retirements: 0,
    held_edges: 0,
    fresh_admissions: 0,
    fresh_reservations: 0,
    fresh_local_terminals: 0,
    fresh_retirements: 0,
  }
}

///|
fn queue_owner_correspondence_compare(
  observer : QueueOwnerCorrespondence,
  source : @sim.Simulator,
) -> Unit raise {
  // POST boundaries must be mirrored again after both commits. Foreign
  // registers can have changed on the source edge; the projection keeps its
  // own retained registers and never receives their POST values as inputs.
  for cut in observer.sequential.plan.cuts {
    let value = source.value(cut.node)
    observer.projection.set_input("cut_n\{cut.node.ordinal()}", value)
    let mapped = dependency_generation_mapped(
      observer.sequential.original_to_local,
      cut.node,
    )
    assert_eq(observer.projection.value(mapped), value)
  }
  observer.projection.settle()
  for root in observer.sequential.plan.probe.roots {
    let actual = source.value(root.node)
    let mapped = dependency_generation_mapped(
      observer.sequential.original_to_local,
      root.node,
    )
    // LogicValue equality compares width, value and known masks, including
    // the genuinely unknown pre-startup-reset register state.
    assert_eq(observer.projection.value(mapped), actual)
    if !actual.is_fully_known() {
      observer.unknown_root_samples += 1
    }
  }
  for event in observer.sequential.plan.probe.events {
    let mapped = dependency_generation_mapped(
      observer.sequential.original_to_local,
      event.node,
    )
    assert_eq(observer.projection.value(mapped), source.value(event.node))
  }
}

///|
fn queue_owner_correspondence_pre(
  observer : QueueOwnerCorrespondence,
  source : @sim.Simulator,
) -> Unit raise {
  assert_false(observer.pre_pending)
  source.settle()
  queue_owner_correspondence_compare(observer, source)
  observer.pre_pending = true
  observer.pre_samples += 1
  let reset = source.value(observer.sequential.plan.probe.reset)
  assert_true(reset.is_fully_known())
  if reset.to_uint64() == 1UL {
    observer.reset_edges += 1
    if observer.reset_edges > 1 {
      let first = records_observe(
        observer.fixture,
        source,
        RetirementReadPointer,
      ).to_int()
      assert_eq(
        records_observe(observer.fixture, source, EntryValid(first)),
        1UL,
      )
      assert_eq(
        records_observe(observer.fixture, source, EntryTerminal(first)),
        1UL,
      )
      observer.later_reset_held += 1
    }
    return
  }
  let read = role => records_observe(observer.fixture, source, role)
  for engine in 0..<3 {
    observer.accepts[engine] += read(EngineAccept(engine)).to_int()
    for entry in 0..<3 {
      observer.collections[engine] += read(EntryCollector(entry, engine)).to_int()
    }
  }
  let mut local_terminal_count = 0
  for entry in 0..<3 {
    local_terminal_count += read(EntryLocalTerminal(entry)).to_int()
  }
  observer.local_terminals += local_terminal_count
  observer.retirements += read(RetirementFire).to_int()
  if read(RetirementValid) == 1UL && read(RetirementFire) == 0UL {
    observer.held_edges += 1
  }
  if observer.reset_edges > 1 {
    if read(FifoPushValid(0)) == 1UL && read(FifoPushReady(0)) == 1UL {
      observer.fresh_admissions += 1
    }
    observer.fresh_reservations += read(HeadReserve).to_int()
    observer.fresh_local_terminals += local_terminal_count
    observer.fresh_retirements += read(RetirementFire).to_int()
  }
}

///|
fn queue_owner_correspondence_post(
  observer : QueueOwnerCorrespondence,
  source : @sim.Simulator,
) -> Unit raise {
  assert_true(observer.pre_pending)
  // The source has just committed its existing edge. The projection commits
  // using the saved PRE foreign values, before any POST boundary is copied.
  observer.projection.rising_edge("clock")
  queue_owner_correspondence_compare(observer, source)
  observer.pre_pending = false
  observer.post_samples += 1
}

///|
fn queue_owner_correspondence_finish(
  observer : QueueOwnerCorrespondence,
) -> Unit raise {
  assert_false(observer.pre_pending)
  assert_eq(observer.pre_samples, observer.post_samples)
  assert_true(observer.pre_samples > 16)
  assert_true(observer.unknown_root_samples > 0)
  assert_eq(observer.accepts, [2, 1, 1])
  assert_eq(observer.collections, [2, 1, 1])
  assert_eq(observer.local_terminals, 4)
  assert_eq(observer.retirements, 7)
  assert_true(observer.held_edges >= 16)
  assert_eq(observer.reset_edges, 2)
  assert_eq(observer.later_reset_held, 1)
  assert_eq(observer.fresh_admissions, 1)
  assert_eq(observer.fresh_reservations, 1)
  assert_eq(observer.fresh_local_terminals, 1)
  assert_eq(observer.fresh_retirements, 1)
}
