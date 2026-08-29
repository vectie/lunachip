///|
/// Construct a two-stage enabled pipeline in one explicit rising-edge domain.
///
/// Both stages sample old committed state and commit simultaneously. Reset has
/// priority over enable and clears both stages to zero; a deasserted enable
/// holds both stages.
pub fn two_stage_pipeline(width : Int) -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("SequentialTwoStagePipeline")
  let clock = builder.input("clock", @wire.clock())
  let reset_signal = builder.input("reset", @wire.reset())
  let enable = builder.input("enable", @wire.bits(1))
  let input = builder.input("input", @wire.uint(width))
  let domain = builder.rising_edge(clock)
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let first = builder.register_in(domain, input, reset~, enable~)
  let second = builder.register_in(domain, first, reset~, enable~)
  let first_output = builder.output("first", @wire.uint(width))
  let second_output = builder.output("second", @wire.uint(width))
  builder.connect(first_output, first)
  builder.connect(second_output, second)
  builder.finish()
}
