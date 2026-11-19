///|
fn cdc_uint(width : Int32) -> @ir.SignalType raise @ir.IrError {
  UInt(@ir.Width::new(width))
}

///|
fn cdc_sint(width : Int32) -> @ir.SignalType raise @ir.IrError {
  SInt(@ir.Width::new(width))
}

///|
fn cdc_bits(width : Int32) -> @ir.SignalType raise @ir.IrError {
  Bits(@ir.Width::new(width))
}

///|
fn cdc_input_timing(
  input : Int32,
  timing : @ir.InputTiming,
) -> @ir.InputTimingBinding raise @ir.IrError {
  @ir.InputTimingBinding::new(@ir.NodeId::new(input), timing)
}

///|
fn cdc_output_timing(
  output : String,
  timing : @ir.OutputTiming,
) -> @ir.OutputTimingBinding raise @ir.IrError {
  @ir.OutputTimingBinding::checked(output, timing)
}

///|
fn cdc_metadata(
  inputs : ArrayView[@ir.InputTimingBinding],
  outputs : ArrayView[@ir.OutputTimingBinding],
) -> @ir.ModuleMetadata raise @ir.IrError {
  @ir.ModuleMetadata::checked_with_timing([], [], inputs, outputs)
}

///|
fn cdc_ordinals(domains : ReadOnlyArray[@ir.ClockDomainId]) -> Array[Int32] {
  let ordinals : Array[Int32] = []
  for domain in domains {
    ordinals.push(domain.ordinal())
  }
  ordinals
}

///|
fn cdc_path_ordinals(witness : @cdc.CdcWitness) -> Array[Int32] {
  let ordinals : Array[Int32] = []
  for node in witness.path() {
    ordinals.push(node.ordinal())
  }
  ordinals
}
