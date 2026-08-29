///|
fn single_policy_module(
  name : String,
  policy : @ir.MemoryReadWritePolicy,
  masked : Bool,
) -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new(name)
  let clock = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock)
  let read_address = builder.input("read_address", @wire.uint(6))
  let write_address = builder.input("write_address", @wire.uint(6))
  let write_data = builder.input("write_data", @wire.uint(32))
  let write_enable = builder.input("write_enable", @wire.bits(1))
  let read_enable = builder.input("read_enable", @wire.bits(1))
  let memory = builder.synchronous_memory(
    "storage",
    @wire.uint(32),
    64,
    domain,
    read_write_policy=policy,
    multi_write_policy=Reject,
    bounds_policy=Fault,
  )
  if masked {
    let write_mask = builder.input("write_mask", @wire.bits(4))
    builder.memory_write_masked(
      memory,
      "write",
      write_address,
      write_data,
      write_mask,
      8,
      enable=write_enable,
    )
  } else {
    builder.memory_write(
      memory,
      "write",
      write_address,
      write_data,
      enable=write_enable,
    )
  }
  let read_data = builder.memory_read(
    memory,
    "read",
    read_address,
    enable=read_enable,
    enable_behavior=HoldLast,
  )
  let output = builder.output("read_data", @wire.uint(32))
  builder.connect(output, read_data)
  builder.finish()
}

///|
fn lower_port_wins_module() -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("SynthesisMultiwriteLowerPortIdWins")
  let clock = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock)
  let read_address = builder.input("read_address", @wire.uint(6))
  let address0 = builder.input("address0", @wire.uint(6))
  let address1 = builder.input("address1", @wire.uint(6))
  let data0 = builder.input("data0", @wire.uint(32))
  let data1 = builder.input("data1", @wire.uint(32))
  let mask0 = builder.input("mask0", @wire.bits(4))
  let mask1 = builder.input("mask1", @wire.bits(4))
  let enable0 = builder.input("enable0", @wire.bits(1))
  let enable1 = builder.input("enable1", @wire.bits(1))
  let memory = builder.synchronous_memory(
    "storage",
    @wire.uint(32),
    64,
    domain,
    read_write_policy=ReadNew,
    multi_write_policy=LowerPortIdWins,
    bounds_policy=Fault,
  )
  builder.memory_write_masked(
    memory,
    "write0",
    address0,
    data0,
    mask0,
    8,
    enable=enable0,
  )
  builder.memory_write_masked(
    memory,
    "write1",
    address1,
    data1,
    mask1,
    8,
    enable=enable1,
  )
  let read = builder.memory_read(memory, "read", read_address)
  let output = builder.output("read_data", @wire.uint(32))
  builder.connect(output, read)
  builder.finish()
}

///|
fn multiwrite_reject_module() -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("SynthesisMultiwriteReject")
  let clock = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock)
  let address0 = builder.input("address0", @wire.uint(6))
  let address1 = builder.input("address1", @wire.uint(6))
  let data0 = builder.input("data0", @wire.uint(32))
  let data1 = builder.input("data1", @wire.uint(32))
  let enable0 = builder.input("enable0", @wire.bits(1))
  let enable1 = builder.input("enable1", @wire.bits(1))
  let memory = builder.synchronous_memory(
    "storage",
    @wire.uint(32),
    64,
    domain,
    multi_write_policy=Reject,
    bounds_policy=Fault,
  )
  builder.memory_write(memory, "write0", address0, data0, enable=enable0)
  builder.memory_write(memory, "write1", address1, data1, enable=enable1)
  let address0_out = builder.output("address0_out", @wire.uint(6))
  let address1_out = builder.output("address1_out", @wire.uint(6))
  let data0_out = builder.output("data0_out", @wire.uint(32))
  let data1_out = builder.output("data1_out", @wire.uint(32))
  let enable0_out = builder.output("enable0_out", @wire.bits(1))
  let enable1_out = builder.output("enable1_out", @wire.bits(1))
  builder.connect(address0_out, address0)
  builder.connect(address1_out, address1)
  builder.connect(data0_out, data0)
  builder.connect(data1_out, data1)
  builder.connect(enable0_out, enable0)
  builder.connect(enable1_out, enable1)
  builder.finish()
}

///|
fn synthesis_module(kind : SynthesisKind) -> @ir.Module raise {
  match kind {
    SingleReadOld =>
      single_policy_module("SynthesisSingleReadOld", ReadOld, false)
    SingleReadNew =>
      single_policy_module("SynthesisSingleReadNew", ReadNew, false)
    SingleNoChange =>
      single_policy_module("SynthesisSingleNoChange", NoChange, false)
    SingleUndefined =>
      single_policy_module("SynthesisSingleUndefined", Undefined, false)
    SingleMasked => single_policy_module("SynthesisSingleMasked", ReadOld, true)
    MultiwriteLowerPortIdWins => lower_port_wins_module()
    MultiwriteReject => multiwrite_reject_module()
    Fifo =>
      @memory.synchronous_fifo_module(
        @memory.FifoConfig::new("SynthesisFifo", @wire.uint(32), 16, PowerOfTwo),
      )
    BankedMemory =>
      @memory.banked_memory_module(
        @memory.BankedMemoryConfig::new(
          "SynthesisBankedMemory",
          @wire.uint(32),
          4,
          64,
          PowerOfTwoBanks,
          WholeElement,
          ReadOld,
        ),
      )
  }
}

///|
fn synthesis_design(kind : SynthesisKind) -> @ir.Design raise {
  @ir.Design::single("phase4-synthesis-" + kind.id(), synthesis_module(kind))
}
