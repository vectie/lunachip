///|
fn fifo_node_id(ordinal : Int) -> @ir.NodeId raise @ir.IrError {
  @ir.NodeId::new(ordinal)
}

///|
fn checked_fifo_metadata(
  depth : Int,
  pointer_width : Int,
  stages : Int,
  shape : @aggregate.Aggregate[@ir.SignalType],
) -> @ir.AsyncFifoPrimitive raise @ir.IrError {
  let read_stages : Array[@ir.NodeId] = []
  let write_stages : Array[@ir.NodeId] = []
  for index in 0..<stages {
    read_stages.push(fifo_node_id(24 + index))
    write_stages.push(fifo_node_id(30 + index))
  }
  @ir.AsyncFifoPrimitive::checked(
    @ir.CdcPrimitiveId::new(0),
    "fifo",
    @ir.ClockDomainId::new(0),
    @ir.ClockDomainId::new(1),
    depth,
    pointer_width,
    stages,
    CoordinatedIdle,
    @ir.ResetSpec::new(fifo_node_id(3), 0UL),
    @ir.ResetSpec::new(fifo_node_id(4), 0UL),
    shape,
    fifo_node_id(0),
    fifo_node_id(10),
    fifo_node_id(11),
    [fifo_node_id(1)],
    fifo_node_id(2),
    fifo_node_id(12),
    fifo_node_id(13),
    [fifo_node_id(14)],
    [fifo_node_id(15)],
    fifo_node_id(16),
    fifo_node_id(17),
    fifo_node_id(18),
    fifo_node_id(19),
    fifo_node_id(20),
    fifo_node_id(21),
    fifo_node_id(22),
    fifo_node_id(23),
    read_stages,
    write_stages,
    fifo_node_id(40),
    fifo_node_id(41),
    fifo_node_id(12),
    fifo_node_id(42),
    fifo_node_id(43),
    fifo_node_id(44),
  )
}

///|
test "async FIFO metadata accepts exact depth and stage boundaries" {
  let bit = @aggregate.Aggregate::leaf(@ir.SignalType::Bits(@ir.Width::new(1)))
  for item in [(4, 3), (1048576, 21)] {
    assert_eq(checked_fifo_metadata(item.0, item.1, 2, bit).depth(), item.0)
  }
  assert_eq(checked_fifo_metadata(4, 3, 4, bit).synchronizer_stages(), 4)
}

///|
test "async FIFO metadata rejects aggregate shape and width debt" {
  let bits1 : @ir.SignalType = Bits(@ir.Width::new(1))
  let uint1 : @ir.SignalType = UInt(@ir.Width::new(1))
  let heterogeneous = @aggregate.Aggregate::vector([
    @aggregate.Aggregate::leaf(bits1),
    @aggregate.Aggregate::leaf(uint1),
  ])
  try checked_fifo_metadata(4, 3, 2, heterogeneous) catch {
    HeterogeneousAggregateVector(..) => ()
    error => fail("unexpected heterogeneous FIFO error: \{Repr(error)}")
  } noraise {
    _ => fail("expected heterogeneous FIFO rejection")
  }
  let mut deep = @aggregate.Aggregate::leaf(bits1)
  for index in 0..<65 {
    deep = @aggregate.Aggregate::record([("d\{index}", deep)])
  }
  try checked_fifo_metadata(4, 3, 2, deep) catch {
    AggregateDepthLimitExceeded(..) => ()
    error => fail("unexpected deep FIFO error: \{Repr(error)}")
  } noraise {
    _ => fail("expected deep FIFO rejection")
  }
  let too_many = @aggregate.Aggregate::vector(
    Array::make(65537, @aggregate.Aggregate::leaf(bits1)),
  )
  try checked_fifo_metadata(4, 3, 2, too_many) catch {
    AggregateLeafLimitExceeded(..) => ()
    error => fail("unexpected wide FIFO aggregate error: \{Repr(error)}")
  } noraise {
    _ => fail("expected FIFO leaf-limit rejection")
  }
  for
    invalid in [
      @aggregate.Aggregate::leaf(@ir.SignalType::Clock),
      @aggregate.Aggregate::leaf(Bits(@ir.Width::new(65))),
      @aggregate.Aggregate::leaf(Bits(@ir.Width::new(2147483647))),
    ] {
    try checked_fifo_metadata(4, 3, 2, invalid) catch {
      AsyncFifoNodeTypeMismatch(..) | AsyncFifoPayloadWidth(..) => ()
      error => fail("unexpected FIFO leaf error: \{Repr(error)}")
    } noraise {
      _ => fail("expected FIFO leaf rejection")
    }
  }
}

///|
test "async FIFO metadata rejects depth stage and pointer boundaries" {
  let bit = @aggregate.Aggregate::leaf(@ir.SignalType::Bits(@ir.Width::new(1)))
  for depth in [0, 3, 6, 1048577] {
    try checked_fifo_metadata(depth, 3, 2, bit) catch {
      InvalidAsyncFifoDepth(actual~, ..) => assert_eq(actual, depth)
      error => fail("unexpected FIFO depth error: \{Repr(error)}")
    } noraise {
      _ => fail("expected FIFO depth rejection")
    }
  }
  for stages in [0, 1, 5] {
    try checked_fifo_metadata(4, 3, stages, bit) catch {
      InvalidAsyncFifoStageCount(actual~, ..) => assert_eq(actual, stages)
      error => fail("unexpected FIFO stage error: \{Repr(error)}")
    } noraise {
      _ => fail("expected FIFO stage rejection")
    }
  }
  try checked_fifo_metadata(4, 4, 2, bit) catch {
    AsyncFifoStructureMismatch(role~, ..) => assert_eq(role, "pointer_width")
    error => fail("unexpected FIFO pointer-width error: \{Repr(error)}")
  } noraise {
    _ => fail("expected FIFO pointer-width rejection")
  }
}
