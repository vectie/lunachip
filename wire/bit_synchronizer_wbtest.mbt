///|
test "bit synchronizer rejects an unregistered same-owner domain" {
  let builder = ModuleBuilder::new("ForgedDomain")
  let destination_clock = builder.input("destination_clock", clock())
  let destination = builder.rising_edge(destination_clock)
  let source = builder.input("source", bits(1))
  let forged_clock = builder.input("forged_clock", clock())
  let forged : ClockDomain = {
    owner: builder.owner,
    clock: forged_clock,
    canonical: @ir.ClockDomain::rising(@ir.NodeId::new(99)),
  }
  try
    builder.bit_synchronizer(
      "forged",
      source,
      destination,
      2,
      source_domain=forged,
    )
  catch {
    @ir.IrError::UnknownClockDomainId(domain) => assert_eq(domain, 99)
    error => fail("unexpected unregistered-domain error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unregistered domain rejection")
  }
}
