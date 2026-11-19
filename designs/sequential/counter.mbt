///|
/// Construct an enabled modulo counter in one explicit rising-edge domain.
///
/// The public interface is `clock`, synchronous `reset`, one-bit `enable`, and
/// `count`. State begins unknown and becomes zero only when reset is sampled on
/// a rising edge. A deasserted enable retains the committed count.
pub fn counter(width : Int32) -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("SequentialCounter")
  let clock = builder.input("clock", @wire.clock())
  let reset_signal = builder.input("reset", @wire.reset())
  let enable = builder.input("enable", @wire.bits(1))
  let value_type = @wire.uint(width)
  let domain = builder.rising_edge(clock)
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let state = builder.register_state_in(domain, value_type, reset~, enable~)
  let one = builder.constant(value_type, 1UL)
  builder.connect_next(state, builder.add(state.value(), one))
  let count = builder.output("count", value_type)
  builder.connect(count, state.value())
  builder.finish()
}
