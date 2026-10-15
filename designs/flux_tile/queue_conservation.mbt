///|
/// Capture the actual queue/head/retirement/engine construction references
/// in the ordinary fixed direct 1x1/K2/host1024/q3 module. This adds metadata
/// only, not hardware nodes, memory, ports or a proof result.
/// The existing dependency-only view and its 48 references are unchanged.
///
/// ```mbt check
/// test {
///   let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
///   assert_eq(fixture.observations().length(), 115)
///   assert_eq(fixture.hardware().name(), "FluxTileQueuedConcurrent")
/// }
/// ```
pub fn queued_concurrent_queue_formal_fixture() -> QueueConservationFixture raise {
  let observations : Array[QueueConservationObservation] = []
  let hardware = build_queued_concurrent_tile(
    rows=1,
    columns=1,
    max_reduction=2,
    host_bytes=1024UL,
    queue_depth=3,
    queue_observations=observations,
  )
  { hardware, observations: ReadOnlyArray::from_array(observations), }
}

///|
/// Existing-node observations for the unchanged fetched1x1/K2/host1024/ring4/q2
/// graph. This fixed fixture has102 roles and adds no hardware or proof premise.
/// The older direct q3 fixture keeps its115 roles and exact original graph.
///
/// ```mbt check
/// test {
///   let fixture = @flux_tile.ring_concurrent_queue_formal_fixture()
///   assert_eq(fixture.observations().length(), 102)
///   assert_eq(fixture.hardware().name(), "FluxTileHostConcurrent")
/// }
/// ```
pub fn ring_concurrent_queue_formal_fixture() -> QueueConservationFixture raise {
  let observations : Array[QueueConservationObservation] = []
  let hardware = build_ring_concurrent_tile(
    rows=1,
    columns=1,
    max_reduction=2,
    host_bytes=1024UL,
    ring_depth=4,
    queue_depth=2,
    queue_observations=observations,
  )
  { hardware, observations: ReadOnlyArray::from_array(observations), }
}
