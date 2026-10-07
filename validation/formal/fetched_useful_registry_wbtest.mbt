///|
test "fetched useful registry selects exact directed identity and preserves original family boundaries" {
  let bundle = generate_fetched_useful_bundle()
  let source = fetched_useful_test_artifact(bundle, "source-set.lcfs")
  let id = fetched_useful_id()
  assert_eq(source_set_family(source), "flux-tile-fetched-useful-store")
  assert_eq(source_set_fixture_id(source), id)
  assert_eq(regenerate_formal_artifacts(source), bundle.artifacts)
  assert_eq(fetched_useful_artifacts_from_id(id), Some(bundle.artifacts))
  assert_eq(direct8_completion_artifacts_from_id(id), None)
  assert_eq(DirectCompletionFixture::from_id(id), None)
  for
    changed in [
      source.replace(
        old=id,
        new="phase6-flux-tile-fetched-useful-store-unknown",
      ),
      source.replace(old=id, new="phase6-flux-tile-public-transport"),
      source.replace(
        old="FAMILY flux-tile-fetched-useful-store\n",
        new="FAMILY flux-tile-public-transport\n",
      ),
      source.replace(
        old="FAMILY flux-tile-fetched-useful-store\n",
        new="FAMILY flux-tile-direct8-completion\n",
      ),
      source.replace(
        old="LUNACHIP-PHASE6-FORMAL-SOURCE-SET 1\n",
        new="LUNACHIP-PHASE5-FORMAL-SOURCE-SET 1\n",
      ),
    ] {
    try regenerate_formal_artifacts(changed) catch {
      InvalidFormalBundleIdentity(_) => ()
      other =>
        fail("unexpected fetched useful identity rejection: \{Repr(other)}")
    } noraise {
      _ => fail("wrong phase, family or fixture accepted")
    }
  }
  for
    old_id in [
      "",
      "phase6-flux-tile-public-transport",
      "phase6-queue-conservation",
      "phase6-dependency-latest-writer",
      "phase6-flux-tile-direct8-q3-eventual-r2-h2-c2-d11718",
      "phase6-flux-tile-direct-q3-eventual-r2-h2-c2-d252",
      id + "/extra",
    ] {
    assert_eq(fetched_useful_artifacts_from_id(old_id), None)
  }
}
