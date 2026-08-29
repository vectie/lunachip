///|
fn policy(kind : FixtureKind) -> @ir.MemoryReadWritePolicy {
  match kind {
    WholeReadOld | NonPowerOfTwo | Enables => ReadOld
    WholeReadNew | MaskedWrite | LowerPortIdWins => ReadNew
    NoChange => NoChange
    UndefinedSafe => Undefined
  }
}

///|
fn fixture_module(kind : FixtureKind) -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("Phase4" + kind.id())
  let clock = builder.input("clock", @wire.clock())
  let reset_signal = builder.input("reset", @wire.reset())
  let domain = builder.rising_edge(clock)
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let epoch = builder.register_state_in(domain, @wire.bits(1), reset~)
  builder.connect_next(epoch, builder.bit_not(epoch.value()))
  let depth = if kind == NonPowerOfTwo || kind == UndefinedSafe { 3 } else { 4 }
  let read_address = builder.input("read_address", @wire.uint(2))
  let write_address0 = builder.input("write_address0", @wire.uint(2))
  let data0 = builder.input("data0", @wire.uint(8))
  let write_enable0 = builder.input("write_enable0", @wire.bits(1))
  let read_enable = builder.input("read_enable", @wire.bits(1))
  let memory = builder.synchronous_memory(
    "storage",
    @wire.uint(8),
    depth,
    domain,
    read_write_policy=policy(kind),
    multi_write_policy=LowerPortIdWins,
    bounds_policy=if kind == UndefinedSafe { Undefined } else { Fault },
  )
  if kind == MaskedWrite || kind == LowerPortIdWins {
    let mask0 = builder.input("mask0", @wire.bits(4))
    builder.memory_write_masked(
      memory,
      "write0",
      write_address0,
      data0,
      mask0,
      2,
      enable=write_enable0,
    )
  } else {
    builder.memory_write(
      memory,
      "write0",
      write_address0,
      data0,
      enable=write_enable0,
    )
  }
  if kind == LowerPortIdWins {
    let write_address1 = builder.input("write_address1", @wire.uint(2))
    let data1 = builder.input("data1", @wire.uint(8))
    let write_enable1 = builder.input("write_enable1", @wire.bits(1))
    let mask1 = builder.input("mask1", @wire.bits(4))
    builder.memory_write_masked(
      memory,
      "write1",
      write_address1,
      data1,
      mask1,
      2,
      enable=write_enable1,
    )
  }
  let result = builder.memory_read(
    memory,
    "read",
    read_address,
    enable=read_enable,
    enable_behavior=HoldLast,
  )
  let output = builder.output("result", @wire.uint(8))
  if kind == UndefinedSafe {
    let result_valid = builder.input("result_valid", @wire.bits(1))
    builder.connect(
      output,
      builder.mux(result_valid, result, builder.constant(@wire.uint(8), 0UL)),
    )
  } else {
    builder.connect(output, result)
  }
  let epoch_output = builder.output("epoch", @wire.bits(1))
  builder.connect(epoch_output, epoch.value())
  builder.finish()
}

///|
fn fixture_design(kind : FixtureKind) -> @ir.Design raise {
  @ir.Design::single("phase4-" + kind.id(), fixture_module(kind))
}

///|
pub fn dynamic_reject_module() -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("Phase4DynamicReject")
  let clock = builder.input("clock", @wire.clock())
  let reset_signal = builder.input("reset", @wire.reset())
  let domain = builder.rising_edge(clock)
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let epoch = builder.register_state_in(domain, @wire.bits(1), reset~)
  builder.connect_next(epoch, builder.bit_not(epoch.value()))
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
    multi_write_policy=Reject,
  )
  builder.memory_write(memory, "write0", address0, data0, enable=enable0)
  builder.memory_write(memory, "write1", address1, data1, enable=enable1)
  let passthrough0 = builder.output("passthrough0", @wire.uint(8))
  let passthrough1 = builder.output("passthrough1", @wire.uint(8))
  let address_output0 = builder.output("address_output0", @wire.uint(2))
  let address_output1 = builder.output("address_output1", @wire.uint(2))
  let enable_output0 = builder.output("enable_output0", @wire.bits(1))
  let enable_output1 = builder.output("enable_output1", @wire.bits(1))
  let epoch_output = builder.output("epoch", @wire.bits(1))
  builder.connect(passthrough0, data0)
  builder.connect(passthrough1, data1)
  builder.connect(address_output0, address0)
  builder.connect(address_output1, address1)
  builder.connect(enable_output0, enable0)
  builder.connect(enable_output1, enable1)
  builder.connect(epoch_output, epoch.value())
  builder.finish()
}
