///|
test "concurrent engine canonical graph preserves the pre-queue composition" {
  let design = @wire.single_design(
    "Concurrent",
    @flux_tile.concurrent_engine_tile(
      rows=2,
      columns=3,
      max_reduction=5,
      host_bytes=4096UL,
    ),
  )
  assert_eq(
    @crypto.bytes_to_hex_string(
      @crypto.sha256(@utf8.encode(@codec.serialize(design))),
    ),
    "dcbede432892bd5f7731e60bf0fda95e4cbe601ae61dfefc6dc5591ac29b5aba",
  )
}

///|
test "concurrent engines elaborate deterministic dual storage and one shared multiply array" {
  for (rows, columns, capacity) in [(1, 1, 1), (2, 3, 5), (8, 8, 4096)] {
    let first = @wire.single_design(
      "Concurrent",
      @flux_tile.concurrent_engine_tile(
        rows~,
        columns~,
        max_reduction=capacity,
        host_bytes=4096UL,
      ),
    )
    let second = @wire.single_design(
      "Concurrent",
      @flux_tile.concurrent_engine_tile(
        rows~,
        columns~,
        max_reduction=capacity,
        host_bytes=4096UL,
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
    assert_eq(rtl_module.memories().length(), 2 * (rows + columns) + 2)
    let mut multipliers = 0
    for node in rtl_module.nodes() {
      if node.kind() is MulFull(_, _) {
        multipliers += 1
      }
    }
    assert_eq(multipliers, rows * columns)
    for slot in 0..<2 {
      for (side, banks) in [("a", rows), ("b", columns)] {
        for bank in 0..<banks {
          assert_true(
            rtl_module
            .memories()
            .any(memory => memory.name() == "\{side}_slot_\{slot}_bank_\{bank}"),
          )
        }
      }
      assert_true(
        rtl_module
        .memories()
        .any(memory => memory.name() == "c_result_slot_\{slot}"),
      )
    }
  }
}
