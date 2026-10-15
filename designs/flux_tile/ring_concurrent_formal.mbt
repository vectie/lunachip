///|
/// Existing-node dependency observations on the ordinary fetched1x1/K2/
/// host1024/ring4/q2 graph. The48 roles add no hardware or proof premise.
/// Full source snapshots and compute fields retain their original widths.
///
/// ```mbt check
/// test {
///   let fixture = @flux_tile.ring_concurrent_dependency_formal_fixture()
///   assert_eq(fixture.observations().length(), 48)
///   assert_eq(fixture.hardware().name(), "FluxTileHostConcurrent")
/// }
/// ```
pub fn ring_concurrent_dependency_formal_fixture() -> QueuedConcurrentFormalFixture raise {
  let observations : Array[QueuedConcurrentFormalObservation] = []
  let hardware = build_ring_concurrent_tile(
    rows=1,
    columns=1,
    max_reduction=2,
    host_bytes=1024UL,
    ring_depth=4,
    queue_depth=2,
    formal_observations=observations,
  )
  { hardware, observations: ReadOnlyArray::from_array(observations), }
}
