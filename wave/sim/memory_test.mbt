///|
fn known(width : Int, value : UInt64) -> @wave.LogicValue raise {
  @wave.LogicValue::from_uint64(width~, value~)
}

///|
fn drive(
  simulator : @sim.Simulator,
  name : String,
  width : Int,
  value : UInt64,
) -> Unit raise {
  simulator.set_input(name, known(width, value))
}

///|
fn single_port_memory(
  policy : @ir.MemoryReadWritePolicy,
  enable_behavior : @ir.MemoryReadEnableBehavior,
  bounds_policy : @ir.MemoryBoundsPolicy,
) -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("MemoryModel")
  let clock = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock)
  let address = builder.input("address", @wire.uint(2))
  let write_data = builder.input("write_data", @wire.uint(8))
  let write_enable = builder.input("write_enable", @wire.bits(1))
  let read_enable = builder.input("read_enable", @wire.bits(1))
  let memory = builder.synchronous_memory(
    "storage",
    @wire.uint(8),
    4,
    domain,
    read_write_policy=policy,
    multi_write_policy=LowerPortIdWins,
    bounds_policy~,
  )
  builder.memory_write(
    memory,
    "write",
    address,
    write_data,
    enable=write_enable,
  )
  let result = builder.memory_read(
    memory,
    "read",
    address,
    enable=read_enable,
    enable_behavior~,
  )
  let output = builder.output("result", @wire.uint(8))
  builder.connect(output, result)
  builder.finish()
}

///|
fn prepare_single_port(
  policy : @ir.MemoryReadWritePolicy,
) -> @sim.Simulator raise {
  let simulator = @sim.Simulator::prepare(
    single_port_memory(policy, HoldLast, Fault),
  )
  drive(simulator, "address", 2, 0UL)
  drive(simulator, "write_data", 8, 0xa5UL)
  drive(simulator, "write_enable", 1, 0UL)
  drive(simulator, "read_enable", 1, 1UL)
  simulator
}

///|
test "ReadOld and one-cycle latency use pre-edge cell state" {
  let simulator = prepare_single_port(ReadOld)
  drive(simulator, "write_enable", 1, 1UL)
  simulator.rising_edge("clock")
  inspect(simulator.output("result").to_bit_string(), content="xxxxxxxx")
  inspect(
    simulator.memory_cell("storage", 0).to_bit_string(),
    content="10100101",
  )
  drive(simulator, "write_enable", 1, 0UL)
  simulator.rising_edge("clock")
  inspect(simulator.output("result").to_bit_string(), content="10100101")
}

///|
test "ReadNew observes resolved same-edge write state" {
  let simulator = prepare_single_port(ReadNew)
  drive(simulator, "write_enable", 1, 1UL)
  simulator.rising_edge("clock")
  inspect(simulator.output("result").to_bit_string(), content="10100101")
}

///|
test "NoChange holds the previous read result on a collision" {
  let simulator = prepare_single_port(NoChange)
  drive(simulator, "write_enable", 1, 1UL)
  simulator.rising_edge("clock")
  drive(simulator, "write_enable", 1, 0UL)
  simulator.rising_edge("clock")
  inspect(simulator.output("result").to_bit_string(), content="10100101")
  drive(simulator, "write_data", 8, 0x5aUL)
  drive(simulator, "write_enable", 1, 1UL)
  simulator.rising_edge("clock")
  inspect(simulator.output("result").to_bit_string(), content="10100101")
  drive(simulator, "write_enable", 1, 0UL)
  simulator.rising_edge("clock")
  inspect(simulator.output("result").to_bit_string(), content="01011010")
}

///|
test "Undefined collision and disabled-read policy produce X" {
  let simulator = @sim.Simulator::prepare(
    single_port_memory(Undefined, Undefined, Fault),
  )
  drive(simulator, "address", 2, 0UL)
  drive(simulator, "write_data", 8, 0xa5UL)
  drive(simulator, "write_enable", 1, 1UL)
  drive(simulator, "read_enable", 1, 1UL)
  simulator.rising_edge("clock")
  inspect(simulator.output("result").to_bit_string(), content="xxxxxxxx")
  drive(simulator, "write_enable", 1, 0UL)
  simulator.rising_edge("clock")
  inspect(simulator.output("result").to_bit_string(), content="10100101")
  drive(simulator, "read_enable", 1, 0UL)
  simulator.rising_edge("clock")
  inspect(simulator.output("result").to_bit_string(), content="xxxxxxxx")
}

///|
fn masked_memory() -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("MaskedMemory")
  let clock = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock)
  let address = builder.input("address", @wire.uint(2))
  let data = builder.input("data", @wire.uint(8))
  let mask = builder.input("mask", @wire.bits(4))
  let write_enable = builder.input("write_enable", @wire.bits(1))
  let read_enable = builder.input("read_enable", @wire.bits(1))
  let memory = builder.synchronous_memory(
    "storage",
    @wire.uint(8),
    4,
    domain,
    read_write_policy=ReadNew,
  )
  builder.memory_write_masked(
    memory,
    "write",
    address,
    data,
    mask,
    2,
    enable=write_enable,
  )
  let result = builder.memory_read(memory, "read", address, enable=read_enable)
  let output = builder.output("result", @wire.uint(8))
  builder.connect(output, result)
  builder.finish()
}

///|
test "granular masks update exact low-to-high slices" {
  let simulator = @sim.Simulator::prepare(masked_memory())
  drive(simulator, "address", 2, 0UL)
  drive(simulator, "read_enable", 1, 1UL)
  drive(simulator, "write_enable", 1, 1UL)
  drive(simulator, "data", 8, 0xa5UL)
  drive(simulator, "mask", 4, 0xfUL)
  simulator.rising_edge("clock")
  drive(simulator, "data", 8, 0x5aUL)
  drive(simulator, "mask", 4, 0x5UL)
  simulator.rising_edge("clock")
  inspect(simulator.output("result").to_bit_string(), content="10010110")
}

///|
test "unknown mask bits merge only their selected granules" {
  let simulator = @sim.Simulator::prepare(masked_memory())
  drive(simulator, "address", 2, 0UL)
  drive(simulator, "read_enable", 1, 1UL)
  drive(simulator, "write_enable", 1, 1UL)
  drive(simulator, "data", 8, 0xa5UL)
  drive(simulator, "mask", 4, 0xfUL)
  simulator.rising_edge("clock")
  drive(simulator, "data", 8, 0x5aUL)
  simulator.set_input(
    "mask",
    @wave.LogicValue::from_masks(width=4, value_bits=0UL, known_mask=0xeUL),
  )
  simulator.rising_edge("clock")
  inspect(simulator.output("result").to_bit_string(), content="101001xx")
}

///|
fn dual_write_memory(policy : @ir.MemoryMultiWritePolicy) -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("DualWriteMemory")
  let clock = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock)
  let read_address = builder.input("read_address", @wire.uint(2))
  let address0 = builder.input("address0", @wire.uint(2))
  let address1 = builder.input("address1", @wire.uint(2))
  let data0 = builder.input("data0", @wire.uint(8))
  let data1 = builder.input("data1", @wire.uint(8))
  let enable0 = builder.input("enable0", @wire.bits(1))
  let enable1 = builder.input("enable1", @wire.bits(1))
  let memory = builder.synchronous_memory(
    "storage",
    @wire.uint(8),
    4,
    domain,
    read_write_policy=ReadNew,
    multi_write_policy=policy,
  )
  builder.memory_write(memory, "write0", address0, data0, enable=enable0)
  builder.memory_write(memory, "write1", address1, data1, enable=enable1)
  let result = builder.memory_read(memory, "read", read_address)
  let output = builder.output("result", @wire.uint(8))
  builder.connect(output, result)
  builder.finish()
}

///|
fn drive_dual_write(simulator : @sim.Simulator) -> Unit raise {
  drive(simulator, "read_address", 2, 1UL)
  drive(simulator, "address0", 2, 1UL)
  drive(simulator, "address1", 2, 1UL)
  drive(simulator, "data0", 8, 0xa5UL)
  drive(simulator, "data1", 8, 0x5aUL)
  drive(simulator, "enable0", 1, 1UL)
  drive(simulator, "enable1", 1, 1UL)
}

///|
test "lower write-port ID wins a dynamic same-address collision" {
  let simulator = @sim.Simulator::prepare(dual_write_memory(LowerPortIdWins))
  drive_dual_write(simulator)
  simulator.rising_edge("clock")
  inspect(simulator.output("result").to_bit_string(), content="10100101")
  inspect(
    simulator.memory_cell("storage", 1).to_bit_string(),
    content="10100101",
  )
}

///|
test "multi-write Reject faults on a dynamic collision before commit" {
  let simulator = @sim.Simulator::prepare(dual_write_memory(Reject))
  drive_dual_write(simulator)
  try simulator.rising_edge("clock") catch {
    @sim.SimulatorError::MemoryWriteCollision(
      memory="storage",
      address=1UL,
      first_port=0,
      second_port=1
    ) => ()
    error => fail("unexpected collision error: \{Repr(error)}")
  } noraise {
    _ => fail("expected dynamic multi-write collision")
  }
  inspect(simulator.cycle().value(), content="0")
  inspect(
    simulator.memory_cell("storage", 1).to_bit_string(),
    content="xxxxxxxx",
  )
}

///|
test "multi-write masks merge unknown controls and commit distinct addresses" {
  let builder = @wire.ModuleBuilder::new("DualMaskedMemory")
  let clock = builder.input("clock", @wire.clock())
  let read_address = builder.input("read_address", @wire.uint(2))
  let address0 = builder.input("address0", @wire.uint(2))
  let address1 = builder.input("address1", @wire.uint(2))
  let data0 = builder.input("data0", @wire.uint(8))
  let data1 = builder.input("data1", @wire.uint(8))
  let mask0 = builder.input("mask0", @wire.bits(4))
  let mask1 = builder.input("mask1", @wire.bits(4))
  let enable0 = builder.input("enable0", @wire.bits(1))
  let enable1 = builder.input("enable1", @wire.bits(1))
  let memory = builder.synchronous_memory(
    "storage",
    @wire.uint(8),
    4,
    builder.rising_edge(clock),
    read_write_policy=ReadNew,
    multi_write_policy=LowerPortIdWins,
  )
  builder.memory_write_masked(
    memory,
    "write0",
    address0,
    data0,
    mask0,
    2,
    enable=enable0,
  )
  builder.memory_write_masked(
    memory,
    "write1",
    address1,
    data1,
    mask1,
    2,
    enable=enable1,
  )
  let result = builder.memory_read(memory, "read", read_address)
  let output = builder.output("result", @wire.uint(8))
  builder.connect(output, result)
  let simulator = @sim.Simulator::prepare(builder.finish())
  drive(simulator, "read_address", 2, 1UL)
  drive(simulator, "address0", 2, 1UL)
  drive(simulator, "address1", 2, 1UL)
  drive(simulator, "data0", 8, 0UL)
  drive(simulator, "data1", 8, 0UL)
  drive(simulator, "mask0", 4, 0xfUL)
  drive(simulator, "mask1", 4, 0UL)
  drive(simulator, "enable0", 1, 1UL)
  drive(simulator, "enable1", 1, 0UL)
  simulator.rising_edge("clock")

  drive(simulator, "data0", 8, 0x03UL)
  drive(simulator, "data1", 8, 0x02UL)
  drive(simulator, "mask0", 4, 0x1UL)
  drive(simulator, "mask1", 4, 0x1UL)
  simulator.set_input("enable0", @wave.LogicValue::unknown(width=1))
  drive(simulator, "enable1", 1, 1UL)
  simulator.rising_edge("clock")
  inspect(simulator.output("result").to_bit_string(), content="0000001x")

  drive(simulator, "data0", 8, 0UL)
  drive(simulator, "mask0", 4, 0xfUL)
  drive(simulator, "enable0", 1, 1UL)
  drive(simulator, "enable1", 1, 0UL)
  simulator.rising_edge("clock")
  drive(simulator, "data0", 8, 0x03UL)
  drive(simulator, "data1", 8, 0x02UL)
  simulator.set_input(
    "mask0",
    @wave.LogicValue::from_masks(width=4, value_bits=0UL, known_mask=0xeUL),
  )
  drive(simulator, "mask1", 4, 0x1UL)
  drive(simulator, "enable1", 1, 1UL)
  simulator.rising_edge("clock")
  inspect(simulator.output("result").to_bit_string(), content="0000001x")

  drive(simulator, "address0", 2, 1UL)
  drive(simulator, "address1", 2, 2UL)
  drive(simulator, "data0", 8, 0xaaUL)
  drive(simulator, "data1", 8, 0x55UL)
  drive(simulator, "mask0", 4, 0xfUL)
  drive(simulator, "mask1", 4, 0xfUL)
  simulator.rising_edge("clock")
  inspect(simulator.output("result").to_bit_string(), content="10101010")
  drive(simulator, "read_address", 2, 2UL)
  drive(simulator, "enable0", 1, 0UL)
  drive(simulator, "enable1", 1, 0UL)
  simulator.rising_edge("clock")
  inspect(simulator.output("result").to_bit_string(), content="01010101")
}

///|
test "unknown write enable merges old and new cell bits" {
  let simulator = prepare_single_port(ReadNew)
  drive(simulator, "write_enable", 1, 1UL)
  simulator.rising_edge("clock")
  drive(simulator, "write_data", 8, 0xa7UL)
  simulator.set_input("write_enable", @wave.LogicValue::unknown(width=1))
  simulator.rising_edge("clock")
  inspect(
    simulator.memory_cell("storage", 0).to_bit_string(),
    content="101001x1",
  )
  inspect(simulator.output("result").to_bit_string(), content="101001x1")
}

///|
test "disabled accesses do not fault and enabled out-of-range accesses do" {
  let builder = @wire.ModuleBuilder::new("NonPowerOfTwo")
  let clock = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock)
  let address = builder.input("address", @wire.uint(2))
  let enable = builder.input("enable", @wire.bits(1))
  let memory = builder.synchronous_memory(
    "storage",
    @wire.uint(8),
    3,
    domain,
    bounds_policy=Fault,
  )
  let result = builder.memory_read(memory, "read", address, enable~)
  let output = builder.output("result", @wire.uint(8))
  builder.connect(output, result)
  let simulator = @sim.Simulator::prepare(builder.finish())
  drive(simulator, "address", 2, 3UL)
  drive(simulator, "enable", 1, 0UL)
  simulator.rising_edge("clock")
  try {
    drive(simulator, "enable", 1, 1UL)
    simulator.rising_edge("clock")
  } catch {
    @sim.SimulatorError::MemoryAddressOutOfRange(
      memory="storage",
      role=ReadPort,
      port=0,
      address=3UL,
      depth=3
    ) => ()
    error => fail("unexpected bounds error: \{Repr(error)}")
  } noraise {
    _ => fail("expected out-of-range memory fault")
  }
}

///|
test "simulator rejects memory allocations above its explicit resource limit" {
  let builder = @wire.ModuleBuilder::new("OversizedMemory")
  let clock = builder.input("clock", @wire.clock())
  let address = builder.input("address", @wire.uint(21))
  let memory = builder.synchronous_memory(
    "oversized",
    @wire.uint(8),
    1048577,
    builder.rising_edge(clock),
  )
  ignore(builder.memory_read(memory, "read", address))
  let hardware_module = builder.finish()
  try @sim.Simulator::prepare(hardware_module) catch {
    @sim.SimulatorError::UnsupportedMemoryDepth(
      memory="oversized",
      depth=1048577,
      maximum=1048576
    ) => ()
    error => fail("unexpected memory resource error: \{Repr(error)}")
  } noraise {
    _ => fail("expected explicit memory resource rejection")
  }
}

///|
test "snapshots deep-copy memory state and restore it exactly" {
  let simulator = prepare_single_port(ReadNew)
  drive(simulator, "write_enable", 1, 1UL)
  simulator.rising_edge("clock")
  let snapshot = simulator.snapshot()
  drive(simulator, "write_data", 8, 0x5aUL)
  simulator.rising_edge("clock")
  inspect(
    simulator.memory_cell("storage", 0).to_bit_string(),
    content="01011010",
  )
  simulator.restore(snapshot)
  inspect(
    simulator.memory_cell("storage", 0).to_bit_string(),
    content="10100101",
  )
  inspect(simulator.output("result").to_bit_string(), content="10100101")
}
