///|
test "direct8 artifact wrapper and phase neutral registry regenerate all exact isolated IDs" {
  for fixture in [Eventual, UsefulStore, NegativeDeadline] {
    let id = direct8_completion_id(fixture)
    let bundle = generate_direct8_completion_bundle(fixture)
    guard direct8_completion_artifacts_from_id(id) is Some(artifacts) else {
      fail("exact direct8 ID did not generate artifacts")
    }
    assert_eq(artifacts, bundle.artifacts)
    let source = direct8_completion_test_artifact(bundle, "source-set.lcfs")
    assert_eq(regenerate_formal_artifacts(source), artifacts)
    assert_eq(source_set_family(source), "flux-tile-direct8-completion")
    assert_eq(source_set_fixture_id(source), id)
    assert_eq(DirectCompletionFixture::from_id(id), None)
    assert_eq(
      artifacts.filter(item => item.path().has_suffix(".lcft")).length(),
      direct8_completion_test_tasks(bundle).length(),
    )
    for
      changed in [
        source.replace(old=id, new="phase6-flux-tile-direct8-q3-unknown"),
        source.replace(old=id, new=fixture.id()),
        source.replace(
          old="FAMILY flux-tile-direct8-completion\n",
          new="FAMILY flux-tile-direct-completion\n",
        ),
        source.replace(
          old="FAMILY flux-tile-direct8-completion\n",
          new="FAMILY unknown-direct8-completion\n",
        ),
        source.replace(
          old="LUNACHIP-PHASE6-FORMAL-SOURCE-SET 1\n",
          new="LUNACHIP-PHASE5-FORMAL-SOURCE-SET 1\n",
        ),
      ] {
      try regenerate_formal_artifacts(changed) catch {
        InvalidFormalBundleIdentity(_) => ()
        other => fail("unexpected direct8 identity rejection: \{Repr(other)}")
      } noraise {
        _ => fail("wrong family, phase or unknown direct8 identity regenerated")
      }
    }
  }
}

///|
test "direct8 optional wrapper leaves all original identities and unknown IDs to existing selection" {
  for fixture in [Eventual, UsefulStore, NegativeDeadline] {
    assert_eq(direct8_completion_artifacts_from_id(fixture.id()), None)
    let original = generate_direct_completion_formal_bundle(fixture)
    guard original.artifacts().filter(item => item.path() == "source-set.lcfs")
      is [source] else {
      fail("original direct1 source set missing")
    }
    assert_eq(
      regenerate_formal_artifacts(source.content()),
      original.artifacts(),
    )
    try
      regenerate_formal_artifacts(
        source
        .content()
        .replace(
          old="FAMILY flux-tile-direct-completion\n",
          new="FAMILY flux-tile-direct8-completion\n",
        ),
      )
    catch {
      InvalidFormalBundleIdentity(_) => ()
      other =>
        fail(
          "unexpected direct1/wrong-direct8-family rejection: \{Repr(other)}",
        )
    } noraise {
      _ => fail("original ID accepted by direct8 family")
    }
  }
  for
    id in [
      "", "phase6-flux-tile-public-transport", "phase6-queue-conservation", "phase6-dependency-latest-writer",
      "phase6-flux-tile-direct8-q3-unknown", "phase6-flux-tile-direct8-q3-eventual-r2-h2-c2-d11718/extra",
    ] {
    assert_eq(direct8_completion_artifacts_from_id(id), None)
  }
}
