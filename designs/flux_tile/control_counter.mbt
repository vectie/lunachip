///|
/// Construct the first executable FluxTile-0 control-path primitive.
///
/// This deliberately small block proves sequential feedback through LunaWire
/// before the command frontend and systolic datapath are introduced. Each
/// rising edge increments the visible fixed-width counter modulo its width.
pub fn control_cycle_counter(width : Int) -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("FluxTileControlCycleCounter")
  let clock = builder.input("clock", @wire.clock())
  let value_type = @wire.uint(width)
  let state = builder.register_state(clock, value_type, initial=0UL)
  let one = builder.constant(value_type, 1UL)
  let next = builder.add(state.value(), one)
  builder.connect_next(state, next)
  let value = builder.output("value", value_type)
  builder.connect(value, state.value())
  builder.finish()
}
