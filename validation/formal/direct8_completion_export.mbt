///|
/// Generate the isolated direct8 completion input artifacts for an exact ID.
/// Unknown IDs return `None`, allowing existing fixture selection to continue.
/// Generation/registration is not proof, a result receipt or Phase 6 closure.
/// The private bundle and its implementation types are not public contracts.
///
/// ```mbt check
/// test {
///   assert_eq(
///     @formal.direct8_completion_artifacts_from_id("phase6-direct8-unknown"),
///     None,
///   )
/// }
/// ```
pub fn direct8_completion_artifacts_from_id(
  id : String,
) -> ReadOnlyArray[FormalBundleArtifact]? raise {
  match direct8_completion_from_id(id) {
    Some(fixture) => Some(generate_direct8_completion_bundle(fixture).artifacts)
    None => None
  }
}
