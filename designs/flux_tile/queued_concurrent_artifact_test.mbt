///|
test "queued concurrent canonical graph preserves the pre-ring composition" {
  let design = @wire.single_design(
    "QueuedConcurrent",
    @flux_tile.queued_concurrent_tile(
      rows=2,
      columns=3,
      max_reduction=5,
      host_bytes=4096UL,
      queue_depth=3,
    ),
  )
  assert_eq(
    @crypto.bytes_to_hex_string(
      @crypto.sha256(@utf8.encode(@codec.serialize(design))),
    ),
    "88e987b78c960530b23170501c6bc32cc93e0ee1eb3403234d3e7c9842e3b6db",
  )
}

///|
test "queued concurrent artifacts round trip dual slots one array and atomic packet storage" {
  for (rows, columns, capacity, depth) in [(1, 1, 1, 2), (2, 3, 5, 3)] {
    let first = @wire.single_design(
      "QueuedConcurrent",
      @flux_tile.queued_concurrent_tile(
        rows~,
        columns~,
        max_reduction=capacity,
        host_bytes=4096UL,
        queue_depth=depth,
      ),
    )
    let second = @wire.single_design(
      "QueuedConcurrent",
      @flux_tile.queued_concurrent_tile(
        rows~,
        columns~,
        max_reduction=capacity,
        host_bytes=4096UL,
        queue_depth=depth,
      ),
    )
    let canonical = @codec.serialize(first)
    assert_eq(@codec.serialize(second), canonical)
    assert_eq(@codec.serialize(@codec.parse(canonical)), canonical)
    assert_eq(
      @systemverilog.emit_design(first).source(),
      @systemverilog.emit_design(second).source(),
    )
    let rtl_module = first.modules()[0]
    assert_eq(rtl_module.memories().length(), 2 * (rows + columns) + 6)
    let mut multipliers = 0
    for node in rtl_module.nodes() {
      if node.kind() is MulFull(_, _) {
        multipliers += 1
      }
    }
    assert_eq(multipliers, rows * columns)
    assert_eq(rtl_module.name(), "FluxTileQueuedConcurrent")
  }
}

///|
test "queued concurrent rejects retirement and FIFO capacity outside the common bound" {
  for depth in [-1, 0, 1, 17, 32] {
    try
      @flux_tile.queued_concurrent_tile(
        rows=1,
        columns=1,
        max_reduction=1,
        host_bytes=256UL,
        queue_depth=depth,
      )
    catch {
      @flux_tile.QueuedTileError::InvalidQueueDepth(value~, minimum~, maximum~) => {
        assert_eq(value, depth)
        assert_eq(minimum, 2)
        assert_eq(maximum, 16)
      }
      error => fail("unexpected construction error: \{error}")
    } noraise {
      _ => fail("invalid queue depth accepted")
    }
  }
}
