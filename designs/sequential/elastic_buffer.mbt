///|
/// Construct a one-entry ready/valid elastic buffer.
///
/// A transfer is accepted when `in_valid` and `in_ready` are both known one.
/// The buffer can replace a consumed entry on the same edge. Synchronous reset
/// clears only occupancy; payload storage intentionally begins unknown and is
/// written only on an accepted transfer. While blocked, its register enable is
/// deasserted and the committed payload remains stable.
pub fn elastic_buffer(width : Int) -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("SequentialElasticBuffer")
  let clock = builder.input("clock", @wire.clock())
  let reset_signal = builder.input("reset", @wire.reset())
  let input_valid = builder.input("in_valid", @wire.bits(1))
  let input_data = builder.input("in_data", @wire.uint(width))
  let output_ready = builder.input("out_ready", @wire.bits(1))
  let domain = builder.rising_edge(clock)
  let empty_reset = builder.synchronous_reset(reset_signal, 0UL)
  let full = builder.register_state_in(domain, @wire.bits(1), reset=empty_reset)
  let not_full = builder.bit_not(full.value())
  let input_ready = builder.bit_or(not_full, output_ready)
  let accept = builder.bit_and(input_valid, input_ready)
  let payload = builder.register_in(domain, input_data, enable=accept)
  let retain = builder.bit_and(full.value(), builder.bit_not(output_ready))
  builder.connect_next(full, builder.bit_or(input_valid, retain))
  let ready_output = builder.output("in_ready", @wire.bits(1))
  let valid_output = builder.output("out_valid", @wire.bits(1))
  let data_output = builder.output("out_data", @wire.uint(width))
  builder.connect(ready_output, input_ready)
  builder.connect(valid_output, full.value())
  builder.connect(data_output, payload)
  builder.finish()
}
