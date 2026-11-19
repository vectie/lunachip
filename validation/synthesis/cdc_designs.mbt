///|
fn cdc_bit_synchronizer_module(stage_count : Int32) -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new(
    "SynthesisBitSynchronizer\{stage_count}Stage",
  )
  let destination_clock = builder.input("destination_clock", @wire.clock())
  let destination = builder.rising_edge(destination_clock)
  let asynchronous_input = builder.input("asynchronous_input", @wire.bits(1))
  builder.input_timing(asynchronous_input, Asynchronous)
  let synchronized = builder.bit_synchronizer(
    "synchronizer", asynchronous_input, destination, stage_count,
  )
  let output = builder.output("synchronized", @wire.bits(1))
  builder.output_timing(output, ProducedIn(destination.id()))
  builder.connect(output, synchronized)
  builder.finish()
}

///|
fn cdc_bit_synchronizer_design(stage_count : Int32) -> @ir.Design raise {
  @wire.single_design(
    "phase5-synthesis-bit-synchronizer-\{stage_count}",
    cdc_bit_synchronizer_module(stage_count),
  )
}
