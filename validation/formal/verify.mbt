///|
pub fn verify_task_property_binding(
  task : @formal_core.ProofTaskManifest,
  manifest : @formal_core.FormalPropertyManifest,
) -> Unit raise FormalGateError {
  let assumptions : Array[String] = []
  let assertions : Array[String] = []
  let covers : Array[String] = []
  for property in manifest.properties() {
    match property.kind() {
      Assumption => assumptions.push(property.stable_name())
      Assertion => assertions.push(property.stable_name())
      Cover => covers.push(property.stable_name())
    }
  }
  let (name, actual_assumptions, actual_properties, cover_task) = match task {
    Bounded(value) =>
      (
        value.name(),
        value.assumptions(),
        value.properties(),
        value.mode() is BoundedCover,
      )
    Unbounded(value) =>
      (value.name(), value.assumptions(), value.properties(), false)
  }
  if !same_names(actual_assumptions, ReadOnlyArray::from_array(assumptions)) {
    raise TaskPropertyBindingMismatch(name)
  }
  let expected = ReadOnlyArray::from_array(
    if cover_task {
      covers
    } else {
      assertions
    },
  )
  if actual_properties.is_empty() ||
    !actual_properties.all(label => expected.contains(label)) {
    raise TaskPropertyBindingMismatch(name)
  }
}
