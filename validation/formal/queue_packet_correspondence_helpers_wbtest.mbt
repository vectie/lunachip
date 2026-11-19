///|
// Finite native correspondence: only the accepted original public/raw foreign
// leaves are mirrored. No retained state, SRAM cell or read result is injected.
priv struct QueuePacketCorrespondence {
  fixture : @flux_tile.QueueConservationFixture
  sequential : QueuePacketCompositionSequential
  projection : @sim.Simulator
  accepts : Array[Int32]
  collections : Array[Int32]
  mut pre_pending : Bool
  mut pre_samples : Int32
  mut post_samples : Int32
  mut unknown_roots : Int32
  mut unknown_cuts : Int32
  mut unknown_reads : Int32
  mut unknown_cells : Int32
  mut reset_edges : Int32
  mut admissions : Int32
  mut id73_admissions : Int32
  mut reservations : Int32
  mut captures : Int32
  mut local_terminals : Int32
  mut retirements : Int32
  mut held_edges : Int32
  mut full_refills : Int32
  mut fresh_admissions : Int32
  mut fresh_reservations : Int32
  mut fresh_retirements : Int32
}

///|
fn queue_packet_correspondence_prepare(
  fixture : @flux_tile.QueueConservationFixture,
) -> QueuePacketCorrespondence raise {
  let sequential = queue_packet_composition_sequential(fixture)
  queue_packet_composition_require_inventory(sequential.probe)
  assert_eq(
    sequential.inventory_digest,
    "01275b9792d9f2bd9bbb9b026a8de861931b0821dc9634f4439fa9f1c391e7b2",
  )
  assert_eq(sequential.probe.roots.length(), 54)
  assert_eq(sequential.probe.observations.length(), 115)
  assert_eq(sequential.probe.lanes.length(), 4)
  assert_eq(sequential.cuts.length(), 101)
  assert_eq(
    sequential.probe.candidates
    .filter(leaf => leaf.original.kind() is Input(_))
    .length(),
    12,
  )
  assert_eq(
    sequential.probe.candidates
    .filter(leaf => leaf.original.kind() is Register(_))
    .length(),
    89,
  )
  {
    fixture,
    sequential,
    projection: @sim.Simulator::prepare(sequential.hardware),
    accepts: [0, 0, 0],
    collections: [0, 0, 0],
    pre_pending: false,
    pre_samples: 0,
    post_samples: 0,
    unknown_roots: 0,
    unknown_cuts: 0,
    unknown_reads: 0,
    unknown_cells: 0,
    reset_edges: 0,
    admissions: 0,
    id73_admissions: 0,
    reservations: 0,
    captures: 0,
    local_terminals: 0,
    retirements: 0,
    held_edges: 0,
    full_refills: 0,
    fresh_admissions: 0,
    fresh_reservations: 0,
    fresh_retirements: 0,
  }
}

///|
fn queue_packet_correspondence_compare(
  observer : QueuePacketCorrespondence,
  source : @sim.Simulator,
) -> Unit raise {
  let sequential = observer.sequential
  // LogicValue includes original width, bits and known mask. There is no
  // UInt64 conversion of unknown startup or foreign register values.
  for cut in sequential.cuts {
    let value = source.value(cut.node)
    observer.projection.set_input("cut_n\{cut.node.ordinal()}", value)
    if !value.is_fully_known() {
      observer.unknown_cuts += 1
    }
  }
  observer.projection.settle()
  for cut in sequential.cuts {
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      cut.node,
    )
    assert_eq(observer.projection.value(mapped), source.value(cut.node))
  }
  for root in sequential.probe.roots {
    let actual = source.value(root.node)
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      root.node,
    )
    assert_eq(observer.projection.value(mapped), actual)
    if !actual.is_fully_known() {
      observer.unknown_roots += 1
    }
  }
  for observation in sequential.probe.observations {
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      observation.node,
    )
    assert_eq(observer.projection.value(mapped), source.value(observation.node))
  }
  for output in sequential.probe.source.outputs() {
    assert_eq(
      observer.projection.output("public_" + output.name()),
      source.output(output.name()),
    )
  }
  for lane in sequential.probe.lanes {
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      lane.result.id(),
    )
    let actual = source.value(lane.result.id())
    assert_eq(observer.projection.value(mapped), actual)
    if !actual.is_fully_known() {
      observer.unknown_reads += 1
    }
    let memory = queue_storage_sequential_mapped_memory(
      sequential.original_to_local_memory,
      lane.memory.id(),
    )
    let copied = sequential.hardware.memories()[memory.ordinal()]
    for address in 0..<3 {
      let cell = source.memory_cell(lane.memory.name(), address)
      assert_eq(observer.projection.memory_cell(copied.name(), address), cell)
      if !cell.is_fully_known() {
        observer.unknown_cells += 1
      }
    }
  }
}

///|
fn queue_packet_correspondence_pre(
  observer : QueuePacketCorrespondence,
  source : @sim.Simulator,
) -> Unit raise {
  assert_false(observer.pre_pending)
  source.settle()
  queue_packet_correspondence_compare(observer, source)
  observer.pre_pending = true
  observer.pre_samples += 1
  queue_packet_correspondence_metrics(observer, source)
}

///|
fn queue_packet_correspondence_post(
  observer : QueuePacketCorrespondence,
  source : @sim.Simulator,
) -> Unit raise {
  assert_true(observer.pre_pending)
  // Source's existing edge has committed exactly once. Commit this projection
  // with its saved PRE inputs BEFORE mirroring any POST foreign state.
  observer.projection.rising_edge("clock")
  queue_packet_correspondence_compare(observer, source)
  observer.pre_pending = false
  observer.post_samples += 1
}
