///|
// Finite native comparison of the original FIFO-to-head prefix only. Foreign
// PRE LogicValues are inputs; retained registers, read state and SRAM cells
// are never injected. This is not an ownership or full-p12 proof.
priv struct QueueStorageCorrespondence {
  fixture : @flux_tile.QueueConservationFixture
  sequential : QueueStorageSequential
  projection : @sim.Simulator
  read_wraps : Array[Int]
  write_wraps : Array[Int]
  mut pre_samples : Int
  mut post_samples : Int
  mut unknown_roots : Int
  mut unknown_cuts : Int
  mut unknown_reads : Int
  mut unknown_cells : Int
  mut captures : Int
  mut full_refills : Int
  mut changed_full_refills : Int
  mut reset_edges : Int
  mut later_reset_held_cells : Int
}

///|
fn queue_storage_correspondence_prepare(
  fixture : @flux_tile.QueueConservationFixture,
) -> QueueStorageCorrespondence raise {
  let sequential = queue_storage_sequential(fixture)
  assert_eq(sequential.probe.roots.length(), 28)
  assert_eq(sequential.probe.events.length(), 46)
  assert_eq(sequential.cuts.length(), 59)
  assert_eq(sequential.probe.lanes.length(), 4)
  {
    fixture,
    sequential,
    projection: @sim.Simulator::prepare(sequential.hardware),
    read_wraps: [0, 0, 0, 0],
    write_wraps: [0, 0, 0, 0],
    pre_samples: 0,
    post_samples: 0,
    unknown_roots: 0,
    unknown_cuts: 0,
    unknown_reads: 0,
    unknown_cells: 0,
    captures: 0,
    full_refills: 0,
    changed_full_refills: 0,
    reset_edges: 0,
    later_reset_held_cells: 0,
  }
}

///|
fn queue_storage_correspondence_compare(
  observer : QueueStorageCorrespondence,
  source : @sim.Simulator,
) -> Unit raise {
  let sequential = observer.sequential
  // Full LogicValue equality includes width, bits and known masks. No
  // conversion to UInt64 occurs while copying unknown foreign records.
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
  for event in sequential.probe.events {
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      event.node,
    )
    assert_eq(observer.projection.value(mapped), source.value(event.node))
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
    let memory_id = queue_storage_sequential_mapped_memory(
      sequential.original_to_local_memory,
      lane.memory.id(),
    )
    let memories = sequential.hardware
      .memories()
      .filter(memory => memory.id() == memory_id)
    assert_eq(memories.length(), 1)
    for cell in 0..<3 {
      let actual = source.memory_cell(lane.memory.name(), cell)
      assert_eq(
        observer.projection.memory_cell(memories[0].name(), cell),
        actual,
      )
      if !actual.is_fully_known() {
        observer.unknown_cells += 1
      }
    }
  }
}

///|
fn queue_storage_correspondence_bit(
  source : @sim.Simulator,
  node : @ir.NodeId,
) -> Bool raise {
  let value = source.value(node)
  assert_true(value.is_fully_known())
  value.to_uint64() == 1UL
}

///|
// Snapshot actual PRE port inputs and storage, not predicted controller
// transitions. The second edge uses saved PRE cuts before POST re-mirroring.
fn queue_storage_correspondence_tick(
  observer : QueueStorageCorrespondence,
  source : @sim.Simulator,
) -> Unit raise {
  source.settle()
  queue_storage_correspondence_compare(observer, source)
  observer.pre_samples += 1
  let reset = queue_storage_correspondence_bit(
    source,
    observer.sequential.probe.reset,
  )
  let capture = !reset &&
    records_observe(observer.fixture, source, HeadCapture) == 1UL
  let reads : Array[@wave.LogicValue] = []
  let cells : Array[@wave.LogicValue] = []
  let writes : Array[@wave.LogicValue] = []
  let read_fire : Array[Bool] = []
  let write_fire : Array[Bool] = []
  let read_indices : Array[Int] = []
  let write_indices : Array[Int] = []
  let mut full_refill = !reset
  let mut replaced_different_word = false
  for lane in observer.sequential.probe.lanes {
    guard lane.read.enable() is Some(read_node) else {
      fail("retained original read must be enabled")
    }
    guard lane.write.enable() is Some(write_node) else {
      fail("retained original write must be enabled")
    }
    let read = queue_storage_correspondence_bit(source, read_node)
    let write = queue_storage_correspondence_bit(source, write_node)
    let read_index = if read {
      source.value(lane.read.address()).to_uint64().to_int()
    } else {
      0
    }
    let write_index = if write {
      source.value(lane.write.address()).to_uint64().to_int()
    } else {
      0
    }
    if read {
      assert_true(read_index >= 0 && read_index < 3)
    }
    if write {
      assert_true(write_index >= 0 && write_index < 3)
    }
    read_fire.push(read)
    write_fire.push(write)
    read_indices.push(read_index)
    write_indices.push(write_index)
    reads.push(source.value(lane.result.id()))
    writes.push(source.value(lane.write.data()))
    for cell in 0..<3 {
      cells.push(source.memory_cell(lane.memory.name(), cell))
    }
    if !reset {
      full_refill = full_refill &&
        read &&
        write &&
        records_observe(observer.fixture, source, FifoOccupancy(lane.lane)) ==
        3UL
      if read &&
        write &&
        read_index == write_index &&
        source.memory_cell(lane.memory.name(), read_index) != writes[lane.lane] {
        replaced_different_word = true
      }
    }
  }
  if reset {
    observer.reset_edges += 1
    if observer.reset_edges > 1 {
      assert_eq(records_observe(observer.fixture, source, HeadState), 2UL)
      assert_eq(
        records_observe(observer.fixture, source, FifoOccupancy(0)),
        3UL,
      )
      for value in cells {
        assert_true(value.is_fully_known())
        observer.later_reset_held_cells += 1
      }
      for value in reads {
        assert_true(value.is_fully_known())
      }
    }
  }
  source.rising_edge("clock")
  // No POST input is copied between these two commits.
  observer.projection.rising_edge("clock")
  queue_storage_correspondence_compare(observer, source)
  observer.post_samples += 1
  for lane in observer.sequential.probe.lanes {
    let index = lane.lane
    assert_eq(
      source.value(lane.result.id()),
      if read_fire[index] {
        cells[index * 3 + read_indices[index]]
      } else {
        reads[index]
      },
    )
    for cell in 0..<3 {
      assert_eq(
        source.memory_cell(lane.memory.name(), cell),
        if write_fire[index] && write_indices[index] == cell {
          writes[index]
        } else {
          cells[index * 3 + cell]
        },
      )
    }
    if read_fire[index] && read_indices[index] == 2 {
      assert_eq(source.value(lane.read_pointer.node).to_uint64(), 0UL)
      observer.read_wraps[index] += 1
    }
    if write_fire[index] && write_indices[index] == 2 {
      assert_eq(source.value(lane.write_pointer.node).to_uint64(), 0UL)
      observer.write_wraps[index] += 1
    }
    if capture {
      let head = queue_control_binding(observer.fixture, HeadLane(index))
      assert_eq(source.value(head.node), reads[index])
    }
    if reset {
      assert_false(read_fire[index])
      assert_false(write_fire[index])
    }
  }
  if capture {
    observer.captures += 1
  }
  if full_refill {
    observer.full_refills += 1
    for lane in 0..<4 {
      assert_eq(read_indices[lane], write_indices[lane])
    }
    if replaced_different_word {
      observer.changed_full_refills += 1
    }
  }
}
