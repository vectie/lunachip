///|
/// Construct an enabled eight-bit maximal-length Galois LFSR.
///
/// The recurrence shifts right and conditionally XORs `0xb8` when the old
/// least-significant bit is one. Synchronous reset loads the nonzero seed one;
/// a deasserted enable retains the current state.
pub fn lfsr8() -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("SequentialLfsr8")
  let clock = builder.input("clock", @wire.clock())
  let reset_signal = builder.input("reset", @wire.reset())
  let enable = builder.input("enable", @wire.bits(1))
  let state_type = @wire.uint(8)
  let domain = builder.rising_edge(clock)
  let reset = builder.synchronous_reset(reset_signal, 1UL)
  let state = builder.register_state_in(domain, state_type, reset~, enable~)
  let one = builder.constant(state_type, 1UL)
  let shifted = builder.logical_shift_right(state.value(), one)
  let least_significant = builder.slice(state.value(), 0, 0)
  let tap_mask = builder.constant(state_type, 0xb8UL)
  let zero = builder.constant(state_type, 0UL)
  let selected_taps = builder.mux(least_significant, tap_mask, zero)
  builder.connect_next(state, builder.bit_xor(shifted, selected_taps))
  let value = builder.output("value", state_type)
  builder.connect(value, state.value())
  builder.finish()
}
