///|
fn combinational_logic_module() -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("Phase3CombinationalLogic")
  let clock = builder.input("clock", @wire.clock())
  let reset_signal = builder.input("reset", @wire.reset())
  let lhs = builder.input("lhs", @wire.bits(16))
  let rhs = builder.input("rhs", @wire.bits(16))
  let select = builder.input("select", @wire.bits(1))
  let domain = builder.rising_edge(clock)
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let epoch = builder.register_state_in(domain, @wire.bits(1), reset~)
  builder.connect_next(epoch, builder.bit_not(epoch.value()))
  let mixed = builder.mux(
    select,
    builder.bit_xor(lhs, rhs),
    builder.bit_or(builder.bit_and(lhs, rhs), builder.bit_not(lhs)),
  )
  let result = builder.output("result", @wire.bits(16))
  let epoch_output = builder.output("epoch", @wire.bits(1))
  builder.connect(result, mixed)
  builder.connect(epoch_output, epoch.value())
  builder.finish()
}

///|
fn arithmetic_module() -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("Phase3Arithmetic")
  let clock = builder.input("clock", @wire.clock())
  let reset_signal = builder.input("reset", @wire.reset())
  let lhs = builder.input("lhs", @wire.uint(16))
  let rhs = builder.input("rhs", @wire.uint(16))
  let select = builder.input("select", @wire.bits(1))
  let domain = builder.rising_edge(clock)
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let epoch = builder.register_state_in(domain, @wire.uint(16), reset~)
  let one = builder.constant(@wire.uint(16), 1UL)
  builder.connect_next(epoch, builder.add(epoch.value(), one))
  let added = builder.add(lhs, rhs)
  let multiplied = builder.mul_low(lhs, rhs)
  let selected = builder.mux(select, added, multiplied)
  let result = builder.output("result", @wire.uint(16))
  let less = builder.output("less", @wire.bits(1))
  let epoch_output = builder.output("epoch", @wire.uint(16))
  builder.connect(result, selected)
  builder.connect(less, builder.less_than(lhs, rhs))
  builder.connect(epoch_output, epoch.value())
  builder.finish()
}

///|
fn fixture_module(kind : FixtureKind) -> @ir.Module raise {
  match kind {
    CombinationalLogic => combinational_logic_module()
    Arithmetic => arithmetic_module()
    ControlledCounter => @sequential.counter(16)
    Pipeline => @sequential.two_stage_pipeline(16)
    Lfsr => @sequential.lfsr8()
    ReadyValid => @sequential.elastic_buffer(16)
  }
}

///|
fn fixture_design(kind : FixtureKind) -> @ir.Design raise {
  let hardware_module = fixture_module(kind)
  @ir.Design::single("phase3-" + kind.id(), hardware_module)
}
