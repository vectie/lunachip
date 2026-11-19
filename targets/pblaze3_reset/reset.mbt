///|
/// Hold active-low reset until the 128th healthy rising edge of `clk`.
/// `reset` asserts asynchronously and must deassert synchronously to `clk`
/// through the board's reset synchronizer. No power-up state is assumed.
/// The board supplies an independent 50 MHz clock, giving a 2.56 us hold
/// after upstream synchronous reset deassertion.
pub fn hardware_module() -> @ir.Module raise {
  let b = @wire.ModuleBuilder::new("Pblaze3ResetHold")
  let domain = b.rising_edge(b.input("clk", @wire.clock()))
  let reset = b.input("reset", @wire.reset())
  b.input_timing(reset, Asynchronous)
  let count = b.register_state_async_in(
    domain,
    @wire.uint(8),
    b.asynchronous_reset(reset, 0UL),
  )
  let complete = b.slice(count.value(), 7, 7)
  b.connect_next(
    count,
    b.mux(
      complete,
      count.value(),
      b.add(count.value(), b.constant(@wire.uint(8), 1UL)),
    ),
  )
  let release_n = b.output("release_n", @wire.bits(1))
  b.output_timing(release_n, ProducedIn(domain.id()))
  b.connect(release_n, complete)
  b.finish()
}
