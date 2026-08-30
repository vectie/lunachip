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

///|
/// Construct a one-entry elastic buffer for an unpacked aggregate payload.
///
/// Forward `valid`/payload and reverse `ready` are represented by distinct
/// LunaWire handles. Every payload leaf receives an ordinary enabled register;
/// no packed aggregate node or hidden simulator behavior is introduced.
pub fn aggregate_elastic_buffer(
  payload_shape : @aggregate.Aggregate[@ir.SignalType],
) -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("SequentialAggregateElasticBuffer")
  let clock = builder.input("clock", @wire.clock())
  let reset_signal = builder.input("reset", @wire.reset())
  let input_valid = builder.input("in_valid", @wire.bits(1))
  let domain = builder.rising_edge(clock)
  builder.parameter("capacity", Unsigned(1UL))
  builder.parameter(
    "payload_leaves",
    Unsigned(payload_shape.leaf_count().to_uint64()),
  )
  builder.input_timing(reset_signal, SampledIn(domain.id()))
  builder.input_timing(input_valid, SampledIn(domain.id()))
  let input_payload = builder.aggregate_input(
    "in_payload",
    payload_shape,
    timing=SampledIn(domain.id()),
  )
  let output_ready = builder.input("out_ready", @wire.bits(1))
  builder.input_timing(output_ready, SampledIn(domain.id()))
  let incoming = builder.ready_valid_forward(input_valid, input_payload)
  let downstream = builder.ready_valid_backward(output_ready)

  let empty_reset = builder.synchronous_reset(reset_signal, 0UL)
  let full = builder.register_state_in(domain, @wire.bits(1), reset=empty_reset)
  let not_full = builder.bit_not(full.value())
  let input_ready = builder.bit_or(not_full, downstream.ready())
  let accept = builder.bit_and(incoming.valid(), input_ready)
  let stored_leaves : Array[@wire.Signal] = []
  for leaf in incoming.payload().flatten() {
    stored_leaves.push(builder.register_in(domain, leaf.value(), enable=accept))
  }
  let stored_payload = payload_shape.reconstruct_like(stored_leaves)
  builder.bind_internal_aggregate("buffer_storage", stored_payload)
  let retain = builder.bit_and(
    full.value(),
    builder.bit_not(downstream.ready()),
  )
  builder.connect_next(full, builder.bit_or(incoming.valid(), retain))

  let ready_output = builder.output("in_ready", @wire.bits(1))
  let valid_output = builder.output("out_valid", @wire.bits(1))
  builder.output_timing(ready_output, ProducedIn(domain.id()))
  builder.output_timing(valid_output, ProducedIn(domain.id()))
  builder.connect(ready_output, input_ready)
  builder.connect(valid_output, full.value())
  let output_payload = builder.aggregate_output(
    "out_payload",
    payload_shape,
    timing=ProducedIn(domain.id()),
  )
  builder.connect_aggregate(output_payload, stored_payload)
  builder.finish()
}
