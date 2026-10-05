///|
test "ring reader artifacts are deterministic canonical hardware with no invented storage" {
  for depth in [2, 4, 8, 16] {
    let first = @wire.single_design(
      "RingReader",
      @flux_tile.descriptor_ring_reader(
        host_bytes=4294967296UL,
        ring_depth=depth,
      ),
    )
    let second = @wire.single_design(
      "RingReader",
      @flux_tile.descriptor_ring_reader(
        host_bytes=4294967296UL,
        ring_depth=depth,
      ),
    )
    let serialized = @codec.serialize(first)
    assert_eq(serialized, @codec.serialize(second))
    assert_eq(@codec.serialize(@codec.parse(serialized)), serialized)
    assert_eq(
      @systemverilog.emit_design(first).source(),
      @systemverilog.emit_design(second).source(),
    )
    assert_eq(first.modules()[0].memories().length(), 0)
  }
}

///|
test "ring reader rejects unsupported depths and host apertures before construction" {
  for depth in [-1, 0, 1, 3, 5, 17] {
    try
      @flux_tile.descriptor_ring_reader(host_bytes=4096UL, ring_depth=depth)
    catch {
      @flux_tile.RingReaderError::InvalidRingDepth(value~) =>
        assert_eq(value, depth)
      error => fail("unexpected depth error: \{Repr(error)}")
    } noraise {
      _ => fail("unsupported ring depth accepted")
    }
  }
  for value in [0UL, 4294967297UL] {
    try
      @flux_tile.descriptor_ring_reader(host_bytes=value, ring_depth=2)
    catch {
      @flux_tile.RingReaderError::InvalidHostBytes(value=actual, maximum~) => {
        assert_eq(actual, value)
        assert_eq(maximum, 4294967296UL)
      }
      error => fail("unexpected aperture error: \{Repr(error)}")
    } noraise {
      _ => fail("unsupported aperture accepted")
    }
  }
}
