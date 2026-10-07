///|
test "completion source identity uses existing phase neutral formal registry" {
  for bundle in @formal.standard_direct_completion_formal_bundles() {
    guard bundle
      .artifacts()
      .filter(artifact => artifact.path() == "source-set.lcfs")
      is [source] else {
      fail("one typed completion source set required")
    }
    assert_eq(
      @formal.regenerate_formal_artifacts(source.content()),
      bundle.artifacts(),
    )
    let unknown = source
      .content()
      .replace(
        old=bundle.fixture().id(),
        new="phase6-flux-tile-direct-q3-unknown",
      )
    try @formal.regenerate_formal_artifacts(unknown) catch {
      @formal.InvalidFormalBundleIdentity(_) => ()
      other =>
        fail("unexpected unknown completion fixture rejection: \{Repr(other)}")
    } noraise {
      _ => fail("unknown completion fixture must not regenerate")
    }
  }
}
