///|
fn memory_builder_inputs() -> (
  @wire.ModuleBuilder,
  @wire.ClockDomain,
  @wire.Signal,
  @wire.Signal,
  @wire.Signal,
  @wire.Signal,
) raise {
  let builder = @wire.ModuleBuilder::new("MemoryTop")
  let clock_signal = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock_signal)
  let address = builder.input("address", @wire.uint(2))
  let write_data = builder.input("write_data", @wire.uint(8))
  let write_enable = builder.input("write_enable", @wire.bits(1))
  let read_enable = builder.input("read_enable", @wire.bits(1))
  (builder, domain, address, write_data, write_enable, read_enable)
}

///|
test "constructs typed synchronous memory ports without ambient state" {
  let (builder, domain, address, write_data, write_enable, read_enable) = memory_builder_inputs()
  let memory = builder.synchronous_memory(
    "storage",
    @wire.uint(8),
    4,
    domain,
    read_write_policy=ReadNew,
    multi_write_policy=LowerPortIdWins,
    bounds_policy=Fault,
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
    enable_behavior=HoldLast,
  )
  let output = builder.output("result", @wire.uint(8))
  builder.connect(output, result)
  let hardware_module = builder.finish()
  assert_eq(hardware_module.memories().length(), 1)
  let spec = hardware_module.memories()[0]
  assert_eq(spec.id(), memory.id())
  assert_eq(spec.depth().elements(), 4)
  assert_eq(spec.read_ports().length(), 1)
  assert_eq(spec.write_ports().length(), 1)
  assert_eq(spec.read_write_policy(), ReadNew)
  assert_eq(spec.multi_write_policy(), LowerPortIdWins)
  assert_eq(spec.bounds_policy(), Fault)
  assert_eq(
    hardware_module.node(result.id()).unwrap().kind(),
    MemoryRead(memory=memory.id(), port=@ir.MemoryReadPortId::new(0)),
  )
}

///|
test "defaults are explicit canonical memory policies" {
  let (builder, domain, address, write_data, write_enable, _) = memory_builder_inputs()
  let memory = builder.synchronous_memory("storage", @wire.uint(8), 4, domain)
  builder.memory_write(
    memory,
    "write",
    address,
    write_data,
    enable=write_enable,
  )
  let hardware_module = builder.finish()
  let spec = hardware_module.memories()[0]
  assert_eq(spec.read_write_policy(), ReadOld)
  assert_eq(spec.multi_write_policy(), Reject)
  assert_eq(spec.bounds_policy(), Fault)
}

///|
test "masked write checks granularity and exact mask width early" {
  let (builder, domain, address, write_data, write_enable, _) = memory_builder_inputs()
  let memory = builder.synchronous_memory("storage", @wire.uint(8), 4, domain)
  let wrong_mask = builder.input("mask", @wire.bits(1))
  builder.memory_write_masked(
    memory,
    "write",
    address,
    write_data,
    wrong_mask,
    2,
    enable=write_enable,
  ) catch {
    @ir.IrError::MemoryMaskWidth(expected~, actual~, ..) => {
      assert_eq(expected, 4)
      assert_eq(actual, 1)
    }
    _ => fail("expected exact memory mask width failure")
  }
}

///|
test "memory handles cannot cross builder ownership" {
  let (first, first_domain, _, _, _, _) = memory_builder_inputs()
  let memory = first.synchronous_memory(
    "storage",
    @wire.uint(8),
    4,
    first_domain,
  )
  let (second, _, second_address, _, _, second_read_enable) = memory_builder_inputs()
  try
    second.memory_read(
      memory,
      "read",
      second_address,
      enable=second_read_enable,
    )
  catch {
    @wire.WireError::ForeignMemory => ()
    _ => fail("expected foreign memory failure")
  } noraise {
    _ => fail("expected foreign memory failure")
  }
}

///|
test "read-write Reject remains a checked construction failure" {
  let (builder, domain, address, write_data, write_enable, read_enable) = memory_builder_inputs()
  let memory = builder.synchronous_memory(
    "storage",
    @wire.uint(8),
    4,
    domain,
    read_write_policy=Reject,
  )
  builder.memory_write(
    memory,
    "write",
    address,
    write_data,
    enable=write_enable,
  )
  let result = builder.memory_read(memory, "read", address, enable=read_enable)
  let output = builder.output("result", @wire.uint(8))
  builder.connect(output, result)
  try builder.finish() catch {
    @ir.IrError::RejectedMemoryReadWriteCollision(memory=0) => ()
    _ => fail("expected rejected read/write memory construction")
  } noraise {
    _ => fail("expected rejected read/write memory construction")
  }
}
