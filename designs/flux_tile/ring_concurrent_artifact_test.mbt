///|
test "ring concurrent artifacts preserve dual storage one array and atomic descriptor FIFOs" {
  for
    (rows, columns, capacity, ring_depth, depth) in [
      (1, 1, 1, 2, 2),
      (2, 3, 5, 16, 3),
    ] {
    let first = @wire.single_design(
      "RingConcurrent",
      @flux_tile.ring_concurrent_tile(
        rows~,
        columns~,
        max_reduction=capacity,
        host_bytes=8192UL,
        ring_depth~,
        queue_depth=depth,
      ),
    )
    let second = @wire.single_design(
      "RingConcurrent",
      @flux_tile.ring_concurrent_tile(
        rows~,
        columns~,
        max_reduction=capacity,
        host_bytes=8192UL,
        ring_depth~,
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
    assert_eq(rtl_module.name(), "FluxTileHostConcurrent")
    assert_eq(rtl_module.memories().length(), 2 * (rows + columns) + 6)
    let mut multipliers = 0
    for node in rtl_module.nodes() {
      if node.kind() is MulFull(_, _) {
        multipliers += 1
      }
    }
    assert_eq(multipliers, rows * columns)
    assert_false(
      rtl_module
      .nodes()
      .any(node => {
        match node.kind() {
          Input(name) => name == "descriptor_valid"
          _ => false
        }
      }),
    )
    for lane in 0..<4 {
      assert_false(
        rtl_module
        .nodes()
        .any(node => {
          match node.kind() {
            Input(name) => name == "descriptor_lane_\{lane}"
            _ => false
          }
        }),
      )
    }
  }
}

///|
test "ring concurrent rejects unsupported ring and frontend capacities" {
  for ring_depth in [0, 1, 3, 5, 32] {
    try
      @flux_tile.ring_concurrent_tile(
        rows=1,
        columns=1,
        max_reduction=1,
        host_bytes=1024UL,
        ring_depth~,
        queue_depth=2,
      )
    catch {
      @flux_tile.RingReaderError::InvalidRingDepth(value~) =>
        assert_eq(value, ring_depth)
      error => fail("unexpected ring construction error: \{error}")
    } noraise {
      _ => fail("invalid ring depth accepted")
    }
  }
  for depth in [0, 1, 17] {
    try
      @flux_tile.ring_concurrent_tile(
        rows=1,
        columns=1,
        max_reduction=1,
        host_bytes=1024UL,
        ring_depth=2,
        queue_depth=depth,
      )
    catch {
      @flux_tile.QueuedTileError::InvalidQueueDepth(value~, minimum~, maximum~) => {
        assert_eq(value, depth)
        assert_eq(minimum, 2)
        assert_eq(maximum, 16)
      }
      error => fail("unexpected queue construction error: \{error}")
    } noraise {
      _ => fail("invalid queue depth accepted")
    }
  }
}
