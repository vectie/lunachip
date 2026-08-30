///|
/// Inspect one committed generic-memory cell by canonical memory name.
pub fn Simulator::memory_cell(
  self : Simulator,
  name : String,
  index : Int,
) -> @wave.LogicValue raise SimulatorError {
  for memory in self.hardware_module.memories() {
    if memory.name() == name {
      let depth = memory.depth().elements()
      if index < 0 || index >= depth {
        raise MemoryCellOutOfRange(memory=name, index~, depth~)
      }
      return self.memory_cells[memory.id().ordinal()][index]
    }
  }
  raise UnknownMemory(name)
}

///|
/// Capture all mutable state without sharing storage with the simulator.
pub fn Simulator::snapshot(self : Simulator) -> SimulatorSnapshot {
  {
    hardware_module: self.hardware_module,
    values: ReadOnlyArray::from_array(self.values.copy()),
    memory_cells: ReadOnlyArray::from_array(
      self.memory_cells.map(cells => ReadOnlyArray::from_array(cells.copy())),
    ),
    async_fifo_cells: ReadOnlyArray::from_array(
      self.async_fifos.map(fifo => {
        ReadOnlyArray::from_array(
          fifo.lanes.map(cells => ReadOnlyArray::from_array(cells.copy())),
        )
      }),
    ),
    cycle: self.cycle,
    time: self.time,
    event_ordinal: self.event_ordinal,
    domain_edge_counts: ReadOnlyArray::from_array(
      self.domain_edge_counts.copy(),
    ),
  }
}

///|
/// Restore a snapshot made from the exact same validated module.
pub fn Simulator::restore(
  self : Simulator,
  snapshot : SimulatorSnapshot,
) -> Unit raise SimulatorError {
  if self.hardware_module != snapshot.hardware_module {
    raise SnapshotDesignMismatch
  }
  for index, value in snapshot.values {
    self.values[index] = value
    self.pending_state[index] = None
  }
  for index, cells in snapshot.memory_cells {
    self.memory_cells[index] = cells.iter().to_array()
    self.pending_memories[index] = None
  }
  for fifo_index, lanes in snapshot.async_fifo_cells {
    for leaf, cells in lanes {
      self.async_fifos[fifo_index].lanes[leaf] = cells.iter().to_array()
    }
    self.pending_async_fifos[fifo_index] = None
  }
  self.cycle = snapshot.cycle
  self.time = snapshot.time
  self.event_ordinal = snapshot.event_ordinal
  for index, count in snapshot.domain_edge_counts {
    self.domain_edge_counts[index] = count
  }
}
