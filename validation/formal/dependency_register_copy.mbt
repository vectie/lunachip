///|
// Exact register lowering shared by the two purpose-specific sequential
// slices. Discovery checks their rising domain before this copy; no default
// reset, enable, initial value or replacement next expression is introduced.
fn dependency_sequential_register_kind(
  spec : @ir.RegisterSpec,
  mapping : ArrayView[@ir.NodeId?],
) -> @ir.NodeKind raise {
  let domain = @ir.ClockDomain::rising(
    dependency_generation_mapped(mapping, spec.domain().clock()),
  )
  let reset = match spec.reset() {
    None => None
    Some(control) =>
      Some(
        @ir.ResetSpec::explicit(
          dependency_generation_mapped(mapping, control.signal()),
          control.value(),
          control.mode(),
          control.polarity(),
        ),
      )
  }
  let enable = spec
    .enable()
    .map(control => dependency_generation_mapped(mapping, control))
  let initial = spec.initial()
  Register(
    @ir.RegisterSpec::new(
      domain,
      dependency_generation_mapped(mapping, spec.next()),
      reset?,
      enable?,
      initial?,
    ),
  )
}
