///|
test "direct8 queue observations preserve the entire ordinary graph and default fixture" {
  let direct8 = @flux_tile.queued_concurrent_queue_formal_fixture(
    rows=8,
    columns=8,
    max_reduction=16,
    host_bytes=4096UL,
  )
  assert_eq(
    direct8.hardware(),
    @flux_tile.queued_concurrent_tile(
      rows=8,
      columns=8,
      max_reduction=16,
      host_bytes=4096UL,
      queue_depth=3,
    ),
  )
  assert_eq(direct8.observations().length(), 115)
  assert_eq(
    @flux_tile.queued_concurrent_queue_formal_fixture().hardware(),
    @flux_tile.queued_concurrent_tile(
      rows=1,
      columns=1,
      max_reduction=2,
      host_bytes=1024UL,
      queue_depth=3,
    ),
  )
  for observation in direct8.observations() {
    guard direct8.hardware().node(observation.node()) is Some(node) else {
      fail("observation must reference an actual production node")
    }
    assert_eq(node.signal_type(), observation.signal_type())
  }
}
