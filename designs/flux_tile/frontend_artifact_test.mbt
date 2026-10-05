///|
test "queued tile artifacts preserve real queue and accelerator memories deterministically" {
  for depth in [2, 3, 16] {
    let first = @wire.single_design(
      "Queued",
      @flux_tile.queued_tile(
        rows=2,
        columns=3,
        max_reduction=5,
        host_bytes=4096UL,
        queue_depth=depth,
      ),
    )
    let second = @wire.single_design(
      "Queued",
      @flux_tile.queued_tile(
        rows=2,
        columns=3,
        max_reduction=5,
        host_bytes=4096UL,
        queue_depth=depth,
      ),
    )
    assert_eq(@codec.serialize(first), @codec.serialize(second))
    assert_eq(
      @codec.serialize(@codec.parse(@codec.serialize(first))),
      @codec.serialize(first),
    )
    assert_eq(
      @systemverilog.emit_design(first).source(),
      @systemverilog.emit_design(second).source(),
    )
    assert_eq(first.modules()[0].memories().length(), 10)
    let mut descriptor_banks = 0
    let mut operands = 0
    let mut result_banks = 0
    for memory in first.modules()[0].memories() {
      match memory.element_type().width().bits() {
        64 => {
          descriptor_banks += 1
          assert_eq(memory.depth().elements(), depth)
          assert_eq(memory.element_type(), Bits(@ir.Width::new(64)))
          assert_eq(memory.read_ports().length(), 1)
          assert_eq(memory.write_ports().length(), 1)
          assert_eq(memory.read_write_policy(), ReadOld)
        }
        8 => {
          operands += 1
          assert_eq(memory.depth().elements(), 5)
        }
        32 => {
          result_banks += 1
          assert_eq(memory.depth().elements(), 6)
        }
        width => fail("unexpected queue design memory width \{width}")
      }
    }
    assert_eq(descriptor_banks, 4)
    assert_eq(operands, 5)
    assert_eq(result_banks, 1)
  }
}

///|
test "queued tile rejects unsupported queue capacities before hardware construction" {
  for depth in [-1, 0, 1, 17] {
    try
      @flux_tile.queued_tile(
        rows=1,
        columns=1,
        max_reduction=1,
        host_bytes=4096UL,
        queue_depth=depth,
      )
    catch {
      @flux_tile.QueuedTileError::InvalidQueueDepth(value~, minimum~, maximum~) => {
        assert_eq(value, depth)
        assert_eq(minimum, 2)
        assert_eq(maximum, 16)
      }
      error => fail("unexpected queue parameter error: \{Repr(error)}")
    } noraise {
      _ => fail("invalid queue capacity accepted")
    }
  }
}
