///|
/// Record one checked generator parameter without creating a hardware node.
/// Canonical UTF-8 ordering and duplicate-name rejection occur at `finish`.
pub fn ModuleBuilder::parameter(
  self : ModuleBuilder,
  name : String,
  value : @ir.ParameterValue,
) -> Unit raise {
  self.require_open()
  self.parameters.push(@ir.ModuleParameter::checked(name, value))
}

///|
/// Declare the timing contract for one existing non-clock input.
///
/// No timing is inferred for inputs declared through the legacy scalar API.
pub fn ModuleBuilder::input_timing(
  self : ModuleBuilder,
  input : Signal,
  timing : @ir.InputTiming,
) -> Unit raise {
  self.require_open()
  self.require_signal(input)
  for existing in self.input_timings {
    if existing.input() == input.id {
      raise @ir.IrError::DuplicateInputTiming(input=input.id.ordinal())
    }
  }
  self.input_timings.push(@ir.InputTimingBinding::new(input.id, timing))
}

///|
/// Declare the timing contract for one existing non-clock output.
///
/// No timing is inferred for outputs declared through the legacy scalar API.
pub fn ModuleBuilder::output_timing(
  self : ModuleBuilder,
  output : Output,
  timing : @ir.OutputTiming,
) -> Unit raise {
  self.require_open()
  if !physical_equal(self.owner, output.owner) {
    raise ForeignOutput
  }
  let owned = self.outputs.get(output.index)
  guard owned is Some(owned) && owned.name == output.name else {
    raise ForeignOutput
  }
  for existing in self.output_timings {
    if existing.output() == output.name {
      raise @ir.IrError::DuplicateOutputTiming(output.name)
    }
  }
  self.output_timings.push(
    @ir.OutputTimingBinding::checked(output.name, timing),
  )
}
