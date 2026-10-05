///|
test "execute tile IR and emitted RTL are deterministic real-memory artifacts" {
  for (rows, columns, max_reduction) in [(1, 1, 1), (2, 3, 5), (8, 8, 3)] {
    let first = @wire.single_design(
      "ExecuteTile",
      @flux_tile.execute_tile(rows~, columns~, max_reduction~),
    )
    let second = @wire.single_design(
      "ExecuteTile",
      @flux_tile.execute_tile(rows~, columns~, max_reduction~),
    )
    assert_eq(@codec.serialize(first), @codec.serialize(second))
    let first_sv = @systemverilog.emit_design(first).source()
    assert_eq(first_sv, @systemverilog.emit_design(second).source())
    assert_true(first_sv.contains("always_ff"))
    assert_eq(first.modules()[0].memories().length(), rows + columns)
  }
}

///|
test "execute tile rejects invalid elaboration parameters before building hardware" {
  for
    (rows, columns, max_reduction, name, value, maximum) in [
      (0, 1, 1, "rows", 0, 8),
      (9, 1, 1, "rows", 9, 8),
      (1, -1, 1, "columns", -1, 8),
      (1, 9, 1, "columns", 9, 8),
      (1, 1, 0, "max_reduction", 0, 4096),
      (1, 1, 4097, "max_reduction", 4097, 4096),
    ] {
    try @flux_tile.execute_tile(rows~, columns~, max_reduction~) catch {
      @flux_tile.ExecuteTileError::InvalidParameter(
        name=actual_name,
        value=actual_value,
        maximum=actual_maximum
      ) => {
        assert_eq(actual_name, name)
        assert_eq(actual_value, value)
        assert_eq(actual_maximum, maximum)
      }
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("invalid parameter accepted")
    }
  }
}
