///|
fn portable_bounds_probe(
  element_bytes : Int,
  host_bytes : UInt64,
) -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("PortableBoundsProbe")
  let base = builder.input("base", @wire.uint(32))
  let stride = builder.input("stride", @wire.uint(32))
  let rows = builder.input("rows", @wire.uint(13))
  let columns = builder.input("columns", @wire.uint(13))
  let row = builder.input("row", @wire.uint(13))
  let column = builder.input("column", @wire.uint(13))
  let bounds = portable_transfer_bounds(
    builder, base, stride, rows, columns, element_bytes, host_bytes,
  )
  execute_output(builder, "stride_valid", bounds.stride_valid)
  execute_output(builder, "aligned", bounds.aligned)
  execute_output(builder, "in_aperture", bounds.in_aperture)
  execute_output(
    builder,
    "address",
    portable_transfer_address(builder, base, stride, row, column, element_bytes),
  )
  builder.finish()
}

///|
fn portable_bounds_drive(
  simulator : @sim.Simulator,
  name : String,
  width : Int,
  value : UInt64,
) -> Unit raise {
  simulator.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
}

///|
test "portable bounds widen before validating exclusive aperture endpoints" {
  for
    (bytes, aperture, base, stride, rows, columns, stride_ok, aligned, inside) in [
      (1, 4294967296UL, 4294967295UL, 1UL, 1UL, 1UL, 1UL, 1UL, 1UL),
      (4, 4294967296UL, 4294967292UL, 4UL, 1UL, 1UL, 1UL, 1UL, 1UL),
      (4, 4294967296UL, 4294967292UL, 4UL, 2UL, 1UL, 1UL, 1UL, 0UL),
      (1, 128UL, 120UL, 4UL, 2UL, 4UL, 1UL, 1UL, 1UL),
      (1, 128UL, 120UL, 3UL, 2UL, 4UL, 0UL, 1UL, 1UL),
      (1, 128UL, 120UL, 5UL, 2UL, 4UL, 1UL, 1UL, 0UL),
      (4, 128UL, 1UL, 4UL, 1UL, 1UL, 1UL, 0UL, 1UL),
      (4, 128UL, 4UL, 5UL, 1UL, 1UL, 1UL, 0UL, 1UL),
      (
        1, 4294967296UL, 4294967295UL, 4294967295UL, 8191UL, 8191UL, 1UL, 1UL, 0UL,
      ),
      (4, 4294967296UL, 0UL, 4294967295UL, 8191UL, 8191UL, 1UL, 0UL, 0UL),
      (1, 128UL, 0UL, 0UL, 0UL, 1UL, 0UL, 1UL, 0UL),
      (1, 128UL, 0UL, 0UL, 1UL, 0UL, 1UL, 1UL, 0UL),
    ] {
    let simulator = @sim.Simulator::prepare(
      portable_bounds_probe(bytes, aperture),
    )
    for
      (name, width, value) in [
        ("base", 32, base),
        ("stride", 32, stride),
        ("rows", 13, rows),
        ("columns", 13, columns),
        ("row", 13, 0UL),
        ("column", 13, 0UL),
      ] {
      portable_bounds_drive(simulator, name, width, value)
    }
    simulator.settle()
    assert_eq(simulator.output("stride_valid").to_uint64(), stride_ok)
    assert_eq(simulator.output("aligned").to_uint64(), aligned)
    assert_eq(simulator.output("in_aperture").to_uint64(), inside)
    if stride_ok == 1UL && aligned == 1UL && inside == 1UL {
      assert_eq(simulator.output("address").to_uint64(), base)
    }
  }
}

///|
test "portable checked addresses retain padded row strides and byte units" {
  for
    (bytes, base, stride, rows, columns) in [
      (1, 17UL, 9UL, 3, 5),
      (4, 32UL, 20UL, 3, 2),
    ] {
    let simulator = @sim.Simulator::prepare(portable_bounds_probe(bytes, 256UL))
    for
      (name, width, value) in [
        ("base", 32, base),
        ("stride", 32, stride),
        ("rows", 13, rows.to_uint64()),
        ("columns", 13, columns.to_uint64()),
      ] {
      portable_bounds_drive(simulator, name, width, value)
    }
    for row in 0..<rows {
      for column in 0..<columns {
        portable_bounds_drive(simulator, "row", 13, row.to_uint64())
        portable_bounds_drive(simulator, "column", 13, column.to_uint64())
        simulator.settle()
        assert_eq(simulator.output("stride_valid").to_uint64(), 1UL)
        assert_eq(simulator.output("aligned").to_uint64(), 1UL)
        assert_eq(simulator.output("in_aperture").to_uint64(), 1UL)
        let expected = base +
          row.to_uint64() * stride +
          (column * bytes).to_uint64()
        assert_eq(simulator.output("address").to_uint64(), expected)
      }
    }
  }
}
