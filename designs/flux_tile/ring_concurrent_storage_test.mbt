///|
test "fetched storage fixture is observation only and preserves direct fixture" {
  let fixture = @flux_tile.ring_concurrent_store_preservation_fixture()
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
  assert_eq(fixture.observations().length(), 83)
  assert_eq(
    @flux_tile.queued_concurrent_store_preservation_fixture()
    .observations()
    .length(),
    83,
  )
  for index, binding in fixture.observations() {
    assert_false(
      fixture.observations()[:index].any(prior => prior.role() == binding.role()),
    )
    assert_eq(
      fixture.hardware().nodes()[binding.node().ordinal()].signal_type(),
      binding.signal_type(),
    )
  }
}
