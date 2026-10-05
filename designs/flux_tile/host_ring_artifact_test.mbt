///|
test "host ring emits deterministic canonical hardware through private composition" {
  for
    (rows, columns, reduction, ring_depth, queue_depth) in [
      (1, 1, 2, 2, 2),
      (2, 3, 5, 8, 3),
    ] {
    let first = @wire.single_design(
      "HostRing",
      @flux_tile.ring_tile(
        rows~,
        columns~,
        max_reduction=reduction,
        host_bytes=4096UL,
        ring_depth~,
        queue_depth~,
      ),
    )
    let second = @wire.single_design(
      "HostRing",
      @flux_tile.ring_tile(
        rows~,
        columns~,
        max_reduction=reduction,
        host_bytes=4096UL,
        ring_depth~,
        queue_depth~,
      ),
    )
    let canonical = @codec.serialize(first)
    assert_eq(canonical, @codec.serialize(second))
    assert_eq(@codec.serialize(@codec.parse(canonical)), canonical)
    assert_eq(
      @systemverilog.emit_design(first).source(),
      @systemverilog.emit_design(second).source(),
    )
    assert_eq(first.modules()[0].memories().length(), rows + columns + 5)
  }
}
