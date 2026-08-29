///|
test "FIFO depth contract is explicit and derives exact widths" {
  let element : @ir.SignalType = UInt(@ir.Width::new(8))
  let general = @memory.FifoConfig::new("general", element, 3, GeneralDepth)
  assert_eq(general.depth().elements(), 3)
  assert_eq(general.depth().address_width().bits(), 2)
  assert_eq(general.occupancy_width().bits(), 2)
  let power = @memory.FifoConfig::new("power", element, 4, PowerOfTwo)
  assert_eq(power.occupancy_width().bits(), 3)
  try @memory.FifoConfig::new("bad", element, 3, PowerOfTwo) catch {
    FifoDepthNotPowerOfTwo(depth) => assert_eq(depth, 3)
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected non-power-of-two rejection")
  }
  for depth in [0, -1] {
    try @memory.FifoConfig::new("bad", element, depth, GeneralDepth) catch {
      InvalidFifoDepth(actual) => assert_eq(actual, depth)
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected invalid FIFO depth")
    }
  }
}

///|
test "bank count, rows, masks, and collision policy fail closed" {
  let element : @ir.SignalType = UInt(@ir.Width::new(8))
  let general = @memory.BankedMemoryConfig::new(
    "general_banks",
    element,
    3,
    5,
    GeneralBankCount,
    WholeElement,
    ReadOld,
  )
  assert_eq(general.bank_width().bits(), 2)
  assert_eq(general.row_width().bits(), 3)
  let single = @memory.BankedMemoryConfig::new(
    "single",
    element,
    1,
    1,
    PowerOfTwoBanks,
    Granular(4),
    ReadNew,
  )
  assert_eq(single.bank_width().bits(), 1)
  assert_eq(single.row_width().bits(), 1)
  try
    @memory.BankedMemoryConfig::new(
      "bad",
      element,
      3,
      2,
      PowerOfTwoBanks,
      WholeElement,
      ReadOld,
    )
  catch {
    BankCountNotPowerOfTwo(count) => assert_eq(count, 3)
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected bank-count rejection")
  }
  try
    @memory.BankedMemoryConfig::new(
      "bad",
      element,
      2,
      2,
      PowerOfTwoBanks,
      Granular(3),
      ReadOld,
    )
  catch {
    InvalidMaskGranularity(element_width~, granularity~) => {
      assert_eq(element_width, 8)
      assert_eq(granularity, 3)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected mask rejection")
  }
  try
    @memory.BankedMemoryConfig::new(
      "bad",
      element,
      2,
      2,
      PowerOfTwoBanks,
      WholeElement,
      Reject,
    )
  catch {
    UnsupportedBankedCollisionPolicy(policy) => assert_eq(policy, Reject)
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected collision-policy rejection")
  }
}

///|
test "component configurations reject empty names and non-data elements" {
  let element : @ir.SignalType = UInt(@ir.Width::new(8))
  try @memory.FifoConfig::new("", element, 2, PowerOfTwo) catch {
    EmptyComponentName => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected empty name rejection")
  }
  try @memory.FifoConfig::new("bad", Clock, 2, PowerOfTwo) catch {
    InvalidElementType => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected element rejection")
  }
}

///|
test "standalone modules use deterministic first-class memory names" {
  let fifo = @memory.synchronous_fifo_module(
    @memory.FifoConfig::new("queue", UInt(@ir.Width::new(8)), 3, GeneralDepth),
  )
  assert_eq(fifo.memories().length(), 1)
  assert_eq(fifo.memories()[0].name(), "queue.storage")
  assert_eq(fifo.memories()[0].depth().elements(), 3)
  assert_eq(fifo.memories()[0].read_ports()[0].name(), "pop")
  assert_eq(fifo.memories()[0].write_ports()[0].name(), "push")
  let banked = @memory.banked_memory_module(
    @memory.BankedMemoryConfig::new(
      "scratch",
      UInt(@ir.Width::new(16)),
      3,
      5,
      GeneralBankCount,
      WholeElement,
      ReadOld,
    ),
  )
  assert_eq(banked.memories().map(memory => memory.name()), [
    "scratch.bank.0", "scratch.bank.1", "scratch.bank.2",
  ])
  for memory in banked.memories() {
    assert_eq(memory.depth().elements(), 5)
    assert_eq(memory.read_ports().length(), 1)
    assert_eq(memory.write_ports().length(), 1)
  }
}
