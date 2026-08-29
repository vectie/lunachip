///|
test "rising-edge domains are interned by canonical clock identity" {
  let builder = @wire.ModuleBuilder::new("Domains")
  let clock_a = builder.input("clock_a", @wire.clock())
  let clock_b = builder.input("clock_b", @wire.clock())
  let domain_a_first = builder.rising_edge(clock_a)
  let domain_b = builder.rising_edge(clock_b)
  let domain_a_second = builder.rising_edge(clock_a)
  assert_eq(domain_a_first.id(), domain_a_second.id())
  assert_eq(domain_a_first.id().ordinal(), clock_a.id().ordinal())
  assert_eq(domain_b.id().ordinal(), clock_b.id().ordinal())
  let ty = @wire.uint(8)
  let next_a = builder.input("next_a", ty)
  let next_b = builder.input("next_b", ty)
  let state_a = builder.register_in(domain_a_first, next_a)
  let state_b = builder.register_in(domain_b, next_b)
  let output_a = builder.output("state_a", ty)
  let output_b = builder.output("state_b", ty)
  builder.connect(output_a, state_a)
  builder.connect(output_b, state_b)
  let hardware_module = builder.finish()
  assert_eq(hardware_module.domains().length(), 2)
}

///|
test "active-low builder reset remains fail-closed until execution support" {
  let builder = @wire.ModuleBuilder::new("ActiveLow")
  let clock = builder.input("clock", @wire.clock())
  let reset_signal = builder.input("reset", @wire.reset())
  let next = builder.input("next", @wire.uint(8))
  let domain = builder.rising_edge(clock)
  let reset = builder.synchronous_reset_active_low(reset_signal, 0UL)
  let state = builder.register_in(domain, next, reset~)
  let output = builder.output("state", @wire.uint(8))
  builder.connect(output, state)
  try builder.finish() catch {
    @ir.IrError::UnsupportedResetPolarity(node~) => assert_eq(node, 3)
    error => fail("unexpected polarity error: \{Repr(error)}")
  } noraise {
    _ => fail("expected active-low reset rejection")
  }
}
