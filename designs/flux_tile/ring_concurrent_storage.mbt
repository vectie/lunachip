///|
/// Existing Store/capture references for the ordinary fetched1x1/K2/host1024/
/// ring4/q2 graph. This adds metadata only, not hardware or a proof result.
///
/// ```mbt check
/// test {
///   let fixture = @flux_tile.ring_concurrent_store_preservation_fixture()
///   assert_eq(fixture.c_memories().length(), 2)
///   assert_eq(fixture.hardware().memories().length(), 10)
/// }
/// ```
pub fn ring_concurrent_store_preservation_fixture() -> StorePreservationFixture raise {
  let observations : Array[StorePreservationObservation] = []
  let hardware = build_ring_concurrent_tile(
    rows=1,
    columns=1,
    max_reduction=2,
    host_bytes=1024UL,
    ring_depth=4,
    queue_depth=2,
    store_observations=observations,
  )
  let c_memories : Array[StorePreservationMemory] = []
  for slot in 0..<2 {
    guard hardware
      .memories()
      .filter(memory => memory.name() == "c_result_slot_\{slot}")
      is [memory] &&
      memory.read_ports() is [read] &&
      observations.filter(observation => observation.role == CReadData(slot))
      is [binding] &&
      binding.node == read.result() else {
      raise StorePreservationError::InvalidReference(
        "fetched C memory/read identity",
      )
    }
    c_memories.push({ slot, read_node: read.result(), memory, })
  }
  {
    hardware,
    observations: ReadOnlyArray::from_array(observations),
    c_memories: ReadOnlyArray::from_array(c_memories),
  }
}
