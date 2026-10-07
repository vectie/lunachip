///|
/// Capture existing Store, inner capture and C-memory references in the ordinary
/// fixed 2x2/K2/host1024/q3 device. Adds no hardware or proof inputs.
///
/// ```mbt check
/// test {
///   let fixture = @flux_tile.queued_concurrent_store_preservation_fixture()
///   assert_eq(fixture.c_memories().length(), 2)
///   assert_eq(fixture.hardware().name(), "FluxTileQueuedConcurrent")
/// }
/// ```
pub fn queued_concurrent_store_preservation_fixture() -> StorePreservationFixture raise {
  let observations : Array[StorePreservationObservation] = []
  let hardware = build_queued_concurrent_tile(
    rows=2,
    columns=2,
    max_reduction=2,
    host_bytes=1024UL,
    queue_depth=3,
    store_observations=observations,
  )
  let c_memories : Array[StorePreservationMemory] = []
  for slot in 0..<2 {
    let reads = observations.filter(observation => {
      observation.role == CReadData(slot)
    })
    guard reads is [read] else {
      raise StorePreservationError::InvalidReference("missing C read identity")
    }
    guard hardware.nodes()[read.node.ordinal()].kind()
      is MemoryRead(memory~, port~) else {
      raise StorePreservationError::InvalidReference(
        "C data is not memory read",
      )
    }
    let memories = hardware
      .memories()
      .filter(candidate => candidate.id() == memory)
    guard memories is [original] else {
      raise StorePreservationError::InvalidReference(
        "C memory identity missing or duplicated",
      )
    }
    guard original
      .read_ports()
      .any(candidate => {
        candidate.id() == port && candidate.result() == read.node
      }) else {
      raise StorePreservationError::InvalidReference(
        "C memory/read port mismatch",
      )
    }
    c_memories.push({ slot, read_node: read.node, memory: original, })
  }
  {
    hardware,
    observations: ReadOnlyArray::from_array(observations),
    c_memories: ReadOnlyArray::from_array(c_memories),
  }
}
