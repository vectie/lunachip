///|
fn initialize_banked_inputs(
  simulator : @sim.Simulator,
  bank_width : Int,
  row_width : Int,
  data_width : Int,
  mask_width? : Int,
) -> Unit raise {
  memory_test_drive_bit(simulator, "reset", 1UL)
  memory_test_drive_bit(simulator, "read_enable", 1UL)
  memory_test_drive(simulator, "read_bank", bank_width, 0UL)
  memory_test_drive(simulator, "read_row", row_width, 0UL)
  memory_test_drive_bit(simulator, "write_enable", 1UL)
  memory_test_drive(simulator, "write_bank", bank_width, 0UL)
  memory_test_drive(simulator, "write_row", row_width, 0UL)
  memory_test_drive(simulator, "write_data", data_width, 0xdeUL)
  if mask_width is Some(width) {
    memory_test_drive(simulator, "write_mask", width, (1UL << width) - 1UL)
  }
  simulator.rising_edge("clock")
  assert_eq(simulator.output("read_accepted").to_uint64(), 0UL)
  assert_eq(simulator.output("write_accepted").to_uint64(), 0UL)
  assert_eq(simulator.output("response_valid").to_uint64(), 0UL)
  memory_test_drive_bit(simulator, "reset", 0UL)
  memory_test_drive_bit(simulator, "read_enable", 0UL)
  memory_test_drive_bit(simulator, "write_enable", 0UL)
}

///|
test "general bank count isolates banks and rejects invalid selectors" {
  let config = @memory.BankedMemoryConfig::new(
    "three_banks",
    UInt(@ir.Width::new(8)),
    3,
    3,
    GeneralBankCount,
    WholeElement,
    ReadOld,
  )
  let simulator = @sim.Simulator::prepare(@memory.banked_memory_module(config))
  initialize_banked_inputs(simulator, 2, 2, 8)
  memory_test_drive_bit(simulator, "write_enable", 1UL)
  memory_test_drive(simulator, "write_row", 2, 1UL)
  for pair in [(0UL, 10UL), (1UL, 20UL), (2UL, 30UL)] {
    let (bank, value) = pair
    memory_test_drive(simulator, "write_bank", 2, bank)
    memory_test_drive(simulator, "write_data", 8, value)
    simulator.rising_edge("clock")
    assert_eq(simulator.output("write_accepted").to_uint64(), 1UL)
  }
  memory_test_drive_bit(simulator, "write_enable", 0UL)
  memory_test_drive_bit(simulator, "read_enable", 1UL)
  memory_test_drive(simulator, "read_bank", 2, 1UL)
  memory_test_drive(simulator, "read_row", 2, 1UL)
  simulator.rising_edge("clock")
  assert_eq(simulator.output("read_accepted").to_uint64(), 1UL)
  assert_eq(simulator.output("response_valid").to_uint64(), 1UL)
  assert_eq(simulator.output("read_data").to_uint64(), 20UL)

  // Selector 3 is representable but invalid for three banks. It is explicitly
  // rejected rather than wrapped or aliased.
  memory_test_drive(simulator, "read_bank", 2, 3UL)
  memory_test_drive(simulator, "write_bank", 2, 3UL)
  memory_test_drive_bit(simulator, "write_enable", 1UL)
  simulator.rising_edge("clock")
  assert_eq(simulator.output("read_bank_valid").to_uint64(), 0UL)
  assert_eq(simulator.output("write_bank_valid").to_uint64(), 0UL)
  assert_eq(simulator.output("read_accepted").to_uint64(), 0UL)
  assert_eq(simulator.output("write_accepted").to_uint64(), 0UL)
  assert_eq(simulator.output("response_valid").to_uint64(), 0UL)

  memory_test_drive_bit(simulator, "write_enable", 0UL)
  memory_test_drive(simulator, "read_bank", 2, 2UL)
  simulator.rising_edge("clock")
  assert_eq(simulator.output("response_valid").to_uint64(), 1UL)
  assert_eq(simulator.output("read_data").to_uint64(), 30UL)

  // General row depth is not rounded or wrapped: representable row 3 faults
  // against the explicit three-row bank contract.
  memory_test_drive(simulator, "read_bank", 2, 0UL)
  memory_test_drive(simulator, "read_row", 2, 3UL)
  try simulator.rising_edge("clock") catch {
    @sim.SimulatorError::MemoryAddressOutOfRange(
      memory="three_banks.bank.0",
      role=ReadPort,
      port=0,
      address=3UL,
      depth=3
    ) => ()
    error => fail("unexpected bounds error: \{Repr(error)}")
  } noraise {
    _ => fail("expected explicit row bounds fault")
  }
}

///|
test "general contract elaborates power-of-two bank counts" {
  let config = @memory.BankedMemoryConfig::new(
    "general_four_banks",
    UInt(@ir.Width::new(8)),
    4,
    2,
    GeneralBankCount,
    WholeElement,
    ReadOld,
  )
  let simulator = @sim.Simulator::prepare(@memory.banked_memory_module(config))
  initialize_banked_inputs(simulator, 2, 1, 8)
  for selector in 0..<4 {
    memory_test_drive(simulator, "read_bank", 2, selector.to_uint64())
    memory_test_drive(simulator, "write_bank", 2, selector.to_uint64())
    simulator.settle()
    assert_eq(simulator.output("read_bank_valid").to_uint64(), 1UL)
    assert_eq(simulator.output("write_bank_valid").to_uint64(), 1UL)
  }
}

///|
test "granular writes merge lanes without leaking across banks" {
  let config = @memory.BankedMemoryConfig::new(
    "masked_banks",
    UInt(@ir.Width::new(8)),
    2,
    2,
    PowerOfTwoBanks,
    Granular(4),
    ReadNew,
  )
  let simulator = @sim.Simulator::prepare(@memory.banked_memory_module(config))
  initialize_banked_inputs(simulator, 1, 1, 8, mask_width=2)
  memory_test_drive_bit(simulator, "write_enable", 1UL)
  memory_test_drive(simulator, "write_bank", 1, 1UL)
  memory_test_drive(simulator, "write_row", 1, 0UL)
  memory_test_drive(simulator, "write_data", 8, 0xabUL)
  memory_test_drive(simulator, "write_mask", 2, 3UL)
  simulator.rising_edge("clock")
  memory_test_drive(simulator, "write_data", 8, 0x0cUL)
  memory_test_drive(simulator, "write_mask", 2, 1UL)
  simulator.rising_edge("clock")
  memory_test_drive_bit(simulator, "write_enable", 0UL)
  memory_test_drive_bit(simulator, "read_enable", 1UL)
  memory_test_drive(simulator, "read_bank", 1, 1UL)
  memory_test_drive(simulator, "read_row", 1, 0UL)
  simulator.rising_edge("clock")
  assert_eq(simulator.output("read_data").to_uint64(), 0xacUL)

  memory_test_drive(simulator, "read_bank", 1, 0UL)
  simulator.rising_edge("clock")
  inspect(simulator.output("read_data").to_bit_string(), content="xxxxxxxx")
}
