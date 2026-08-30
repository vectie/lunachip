///|
fn source_set_fixture_id(source_set : String) -> String raise FormalGateError {
  let fixtures = source_set
    .split("\n")
    .filter(line => line.has_prefix("FIXTURE "))
    .to_array()
  if fixtures.length() != 1 {
    raise InvalidFormalBundleIdentity(
      "formal source set must declare exactly one fixture",
    )
  }
  fixtures[0]["FIXTURE ".length():].to_owned()
}

///|
/// Regenerate the canonical artifact set selected by a typed source-set
/// identity. This is the single phase-neutral verifier registry used by the
/// locked formal runner; the runner itself has no fixture-family knowledge.
pub fn regenerate_formal_artifacts(
  source_set : String,
) -> ReadOnlyArray[FormalBundleArtifact] raise {
  let fixture_id = source_set_fixture_id(source_set)
  if source_set.has_prefix("LUNACHIP-PHASE4-FORMAL-SOURCE-SET 1\n") {
    guard FifoFormalFixture::from_id(fixture_id) is Some(fixture) else {
      raise InvalidFormalBundleIdentity(
        "unknown FIFO formal fixture: \{fixture_id}",
      )
    }
    return generate_fifo_bundle(fixture).artifacts()
  }
  if source_set.has_prefix("LUNACHIP-PHASE5-FORMAL-SOURCE-SET 1\n") &&
    source_set.split("\n").contains("FAMILY bit-synchronizer") {
    guard SynchronizerFormalFixture::from_id(fixture_id) is Some(fixture) else {
      raise InvalidFormalBundleIdentity(
        "unknown synchronizer formal fixture: \{fixture_id}",
      )
    }
    return generate_synchronizer_bundle(fixture).artifacts()
  }
  if source_set.has_prefix("LUNACHIP-PHASE5-FORMAL-SOURCE-SET 1\n") &&
    source_set.split("\n").contains("FAMILY toggle-handshake") {
    guard ToggleFormalFixture::from_id(fixture_id) is Some(fixture) else {
      raise InvalidFormalBundleIdentity(
        "unknown toggle-handshake formal fixture: \{fixture_id}",
      )
    }
    return generate_toggle_formal_bundle(fixture).artifacts()
  }
  raise InvalidFormalBundleIdentity("unknown formal source-set family")
}
