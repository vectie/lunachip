///|
test "fetched dependency fixture adds only typed observations to the ordinary q2 graph" {
  let fixture = @flux_tile.ring_concurrent_dependency_formal_fixture()
  assert_eq(
    fixture.hardware(),
    @flux_tile.ring_concurrent_tile(
      rows=1,
      columns=1,
      max_reduction=2,
      host_bytes=1024UL,
      ring_depth=4,
      queue_depth=2,
    ),
  )
  assert_eq(fixture.observations().length(), 48)
  for observation in fixture.observations() {
    guard fixture.hardware().node(observation.node()) is Some(node) else {
      fail("actual observation node")
    }
    assert_eq(node.signal_type(), observation.signal_type())
    assert_eq(
      fixture
      .observations()
      .filter(item => item.role() == observation.role())
      .length(),
      1,
    )
  }
  assert_eq(
    @flux_tile.queued_concurrent_dependency_formal_fixture()
    .observations()
    .length(),
    48,
  )
}
