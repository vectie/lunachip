///|
// Finite comparison against real production arithmetic values, not a proof
// of Store preservation, arbitrary-input equivalence or numerical MatMul.
priv struct StoreStorageCorrespondence {
  fixture : @flux_tile.StorePreservationFixture
  slice : StoreStorageProjection
  projected : @sim.Simulator
  mut pre_samples : Int32
  mut post_samples : Int32
  mut unknown_registers : Int32
  mut unknown_arithmetic : Int32
  mut unknown_reads : Int32
  mut unknown_cells : Int32
  mut reset_edges : Int32
  mut store_accepts : Int32
  mut compute_accepts : Int32
  captures : Array[Int32]
  final_captures : Array[Int32]
}

///|
fn store_correspondence_prepare(
  fixture : @flux_tile.StorePreservationFixture,
) -> StoreStorageCorrespondence raise {
  let slice = store_storage_projection(fixture)
  assert_eq(slice.plan.observations.length(), 83)
  assert_eq(slice.plan.arithmetic.length(), 4)
  assert_eq(slice.plan.arbiter_roots.length(), 11)
  {
    fixture,
    slice,
    projected: @sim.Simulator::prepare(slice.hardware),
    pre_samples: 0,
    post_samples: 0,
    unknown_registers: 0,
    unknown_arithmetic: 0,
    unknown_reads: 0,
    unknown_cells: 0,
    reset_edges: 0,
    store_accepts: 0,
    compute_accepts: 0,
    captures: [0, 0],
    final_captures: [0, 0],
  }
}

///|
fn store_correspondence_observe(
  observer : StoreStorageCorrespondence,
  source : @sim.Simulator,
  role : @flux_tile.StorePreservationRole,
) -> UInt64 raise {
  guard observer.fixture.observations().filter(item => item.role() == role)
    is [reference] else {
    fail("missing unique Store correspondence observation")
  }
  let value = source.value(reference.node())
  assert_true(value.is_fully_known())
  value.to_uint64()
}

///|
fn store_correspondence_arbiter(
  observer : StoreStorageCorrespondence,
  source : @sim.Simulator,
  name : String,
) -> UInt64 raise {
  guard observer.slice.plan.arbiter_roots.filter(root => root.name == name)
    is [root] else {
    fail("missing unique actual arbiter root")
  }
  let value = source.value(root.node)
  assert_true(value.is_fully_known())
  value.to_uint64()
}

///|
fn store_correspondence_compare(
  observer : StoreStorageCorrespondence,
  source : @sim.Simulator,
) -> Unit raise {
  let slice = observer.slice
  // The ONLY source values injected are ordinary selected public inputs and
  // the four originally identified raw accumulator values. Keep masks intact.
  for node in slice.plan.selected {
    if node.kind() is Input(name) {
      observer.projected.set_input(name, source.value(node.id()))
    }
  }
  for cut in slice.plan.arithmetic {
    let actual = source.value(cut.id())
    observer.projected.set_input("arithmetic_n\{cut.id().ordinal()}", actual)
    if !actual.is_fully_known() {
      observer.unknown_arithmetic += 1
    }
  }
  observer.projected.settle()
  for node in slice.plan.selected {
    if node.kind() is Input(_) ||
      slice.plan.arithmetic.any(cut => cut.id() == node.id()) {
      assert_eq(
        observer.projected.value(
          dependency_generation_mapped(slice.original_to_local, node.id()),
        ),
        source.value(node.id()),
      )
    } else if node.kind() is Register(_) {
      let actual = source.value(node.id())
      assert_eq(
        observer.projected.value(
          dependency_generation_mapped(slice.original_to_local, node.id()),
        ),
        actual,
      )
      if !actual.is_fully_known() {
        observer.unknown_registers += 1
      }
    } else if node.kind() is MemoryRead(..) {
      let actual = source.value(node.id())
      assert_eq(
        observer.projected.value(
          dependency_generation_mapped(slice.original_to_local, node.id()),
        ),
        actual,
      )
      if !actual.is_fully_known() {
        observer.unknown_reads += 1
      }
    }
  }
  // Includes all original 48 essential roots, 33 event expressions and both
  // actual synchronous C read-result states; no observer prediction replaces it.
  for index, observation in slice.plan.observations {
    assert_eq(
      observer.projected.output("store_observation_\{index}"),
      source.value(observation.node()),
    )
  }
  for output in observer.fixture.hardware().outputs() {
    assert_eq(
      observer.projected.output(output.name()),
      source.output(output.name()),
    )
  }
  for memory in slice.plan.memories {
    let mapped = queue_storage_sequential_mapped_memory(
      slice.original_to_local_memory,
      memory.id(),
    )
    let copied = slice.hardware.memories()[mapped.ordinal()]
    for index in 0..<memory.depth().elements() {
      let actual = source.memory_cell(memory.name(), index)
      assert_eq(observer.projected.memory_cell(copied.name(), index), actual)
      if !actual.is_fully_known() {
        observer.unknown_cells += 1
      }
    }
  }
  assert_eq(observer.projected.time(), source.time())
  assert_eq(observer.projected.cycle(), source.cycle())
  assert_eq(observer.projected.event_ordinal(), source.event_ordinal())
  assert_eq(
    observer.projected.domain_edge_count(slice.hardware.domains()[0].id()),
    source.domain_edge_count(observer.fixture.hardware().domains()[0].id()),
  )
}

///|
fn store_correspondence_tick(
  observer : StoreStorageCorrespondence,
  source : @sim.Simulator,
) -> Unit raise {
  source.settle()
  store_correspondence_compare(observer, source)
  observer.pre_samples += 1
  let reset = source.value(observer.slice.plan.probe.reset)
  assert_true(reset.is_fully_known())
  if reset.to_uint64() == 1UL {
    observer.reset_edges += 1
  } else {
    observer.store_accepts += store_correspondence_observe(
      observer,
      source,
      Event(StoreAccept),
    ).to_int()
    observer.compute_accepts += store_correspondence_observe(
      observer,
      source,
      Event(ComputeAccept),
    ).to_int()
    if store_correspondence_observe(observer, source, Event(Capture)) == 1UL {
      let slot = store_correspondence_observe(
        observer,
        source,
        SlottedRegister(ActiveC),
      ).to_int()
      assert_true(slot >= 0 && slot < 2)
      observer.captures[slot] += 1
      if store_correspondence_observe(observer, source, Event(FinalCapture)) ==
        1UL {
        observer.final_captures[slot] += 1
      }
    }
  }
  source.rising_edge("clock")
  // Deliberately no POST mirroring between these commits: projection inputs
  // still contain the exact saved PRE public inputs and raw arithmetic values.
  observer.projected.rising_edge("clock")
  store_correspondence_compare(observer, source)
  observer.post_samples += 1
}

///|
fn store_correspondence_cells(
  observer : StoreStorageCorrespondence,
  source : @sim.Simulator,
) -> Array[@wave.LogicValue] raise {
  let values : Array[@wave.LogicValue] = []
  for memory in observer.slice.plan.memories {
    for index in 0..<memory.depth().elements() {
      values.push(source.memory_cell(memory.name(), index))
    }
  }
  values
}

///|
fn store_correspondence_reads(
  observer : StoreStorageCorrespondence,
  source : @sim.Simulator,
) -> Array[@wave.LogicValue] raise {
  let values : Array[@wave.LogicValue] = []
  for node in observer.slice.plan.selected {
    if node.kind() is MemoryRead(..) {
      values.push(source.value(node.id()))
    }
  }
  values
}

///|
fn store_correspondence_c_words(
  observer : StoreStorageCorrespondence,
  source : @sim.Simulator,
  slot : Int32,
  expected : Array[Int32],
) -> Unit raise {
  guard observer.fixture.c_memories().filter(binding => binding.slot() == slot)
    is [binding] else {
    fail("missing original C slot memory")
  }
  assert_eq(expected.length(), 4)
  for index in 0..<4 {
    let actual = source.memory_cell(binding.memory().name(), index)
    assert_true(actual.is_fully_known())
    assert_eq(
      actual.to_uint64(),
      expected[index].to_int64().reinterpret_as_uint64() & 0xffffffffUL,
    )
  }
}
