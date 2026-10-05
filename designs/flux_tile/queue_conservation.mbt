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
