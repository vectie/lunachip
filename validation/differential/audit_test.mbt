///|
fn audit_design(
  semantic_version~ : String = "phase3-v1",
  digest~ : String = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
) -> @differential.DesignIdentity raise {
  @differential.DesignIdentity::checked(semantic_version, digest)
}

///|
fn audit_result_identity(
  semantic_version~ : String = "phase3-v1",
  design_digest~ : String = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  stimulus_digest~ : String = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
) -> @differential.ResultIdentity raise {
  @differential.ResultIdentity::checked(
    audit_design(semantic_version~, digest=design_digest),
    stimulus_digest,
  )
}

///|
fn audit_value(text : String) -> @differential.NormalizedValue raise {
  @differential.NormalizedValue::parse(text)
}

///|
fn audit_observation(
  event : UInt64,
  cycle : UInt64,
  tap : String,
  bits : String,
) -> @differential.Observation raise {
  @differential.Observation::checked(
    event,
    cycle,
    Settled,
    tap,
    audit_value(bits),
  )
}

///|
fn audit_set(
  observations : Array[@differential.Observation],
  identity? : @differential.ResultIdentity,
) -> @differential.ObservationSet raise {
  let identity = match identity {
    Some(value) => value
    None => audit_result_identity()
  }
  @differential.ObservationSet::checked(identity, observations)
}

///|
fn audit_sequence(
  stimuli : Array[@differential.Stimulus],
  seed~ : UInt64 = 17,
) -> @differential.StimulusSequence raise {
  @differential.StimulusSequence::checked(audit_design(), seed, stimuli)
}

///|
test "identities require fixed lowercase SHA-256 and survive accessors" {
  let design = audit_design(semantic_version="semantics/1")
  assert_eq(design.semantic_version(), "semantics/1")
  assert_eq(
    design.design_sha256(),
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  )
  let result = audit_result_identity()
  assert_eq(result.design(), audit_design())
  assert_eq(
    result.stimulus_sha256(),
    "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  )
  try audit_design(semantic_version="") catch {
    @differential.DifferentialError::EmptySemanticVersion => ()
    error => fail("unexpected identity error: \{Repr(error)}")
  } noraise {
    _ => fail("expected empty semantic version rejection")
  }
  try audit_design(digest="abcd") catch {
    @differential.DifferentialError::InvalidDigestLength(kind~, length~) => {
      assert_eq(kind, DesignArtifactSha256)
      assert_eq(length, 4)
    }
    _ => fail("expected digest length rejection")
  } noraise {
    _ => fail("expected digest length rejection")
  }
  try
    audit_design(
      digest="Aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    )
  catch {
    @differential.DifferentialError::InvalidDigestSymbol(kind~, index~, symbol~) => {
      assert_eq(kind, DesignArtifactSha256)
      assert_eq(index, 0)
      assert_eq(symbol, 'A')
    }
    _ => fail("expected lowercase digest rejection")
  } noraise {
    _ => fail("expected lowercase digest rejection")
  }
}

///|
test "comparison rejects identity differences before value differences" {
  let expected = audit_set([audit_observation(0, 0, "top/a", "0")])
  let actual = audit_set(
    [audit_observation(0, 0, "top/a", "1")],
    identity=audit_result_identity(semantic_version="phase3-v2"),
  )
  match @differential.compare(expected, actual) {
    Mismatch(mismatch) => {
      assert_eq(mismatch.expected_index(), None)
      assert_eq(mismatch.actual_index(), None)
      assert_eq(
        mismatch.identity(),
        Identity(
          field=SemanticVersion,
          expected="phase3-v1",
          actual="phase3-v2",
        ),
      )
    }
    Equal => fail("expected identity mismatch")
  }

  let wrong_design = audit_set(
    [],
    identity=audit_result_identity(
      design_digest="cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
    ),
  )
  match @differential.compare(audit_set([]), wrong_design) {
    Mismatch(mismatch) =>
      match mismatch.kind() {
        IdentityMismatch(field=DesignSha256, ..) => ()
        _ => fail("expected design sha256 mismatch")
      }
    Equal => fail("expected design sha256 mismatch")
  }

  let wrong_stimulus = audit_set(
    [],
    identity=audit_result_identity(
      stimulus_digest="dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
    ),
  )
  match @differential.compare(audit_set([]), wrong_stimulus) {
    Mismatch(mismatch) =>
      match mismatch.kind() {
        IdentityMismatch(field=StimulusSha256, ..) => ()
        _ => fail("expected stimulus sha256 mismatch")
      }
    Equal => fail("expected stimulus sha256 mismatch")
  }
}

///|
test "normalized planes erase unknown payload and validate every symbol" {
  let normalized = @differential.NormalizedValue::from_planes("0110", "0101")
  assert_eq(normalized.to_text(), "X1X0")
  assert_eq(normalized.width(), 4)
  assert_eq(normalized.value_bits(), "0100")
  assert_eq(normalized.known_mask(), "0101")
  assert_eq(
    audit_value("10").difference(audit_value("1")),
    Some(Width(expected=2, actual=1)),
  )
  assert_eq(audit_value("1X").bit_from_msb(-1), None)
  assert_eq(audit_value("1X").bit_from_msb(2), None)
  try @differential.NormalizedValue::from_planes("0X", "11") catch {
    InvalidPlaneSymbol(plane~, index~, ..) => {
      assert_eq(plane, "bits")
      assert_eq(index, 1)
    }
    _ => fail("expected invalid bit-plane symbol")
  } noraise {
    _ => fail("expected invalid bit-plane symbol")
  }
  try @differential.NormalizedValue::from_planes("01", "12") catch {
    InvalidPlaneSymbol(plane~, index~, ..) => {
      assert_eq(plane, "known")
      assert_eq(index, 1)
    }
    _ => fail("expected invalid known-plane symbol")
  } noraise {
    _ => fail("expected invalid known-plane symbol")
  }
}

///|
test "observation duplicate identity is rejected after UTF-8 sorting" {
  let duplicate = audit_observation(2, 3, "top/δ", "0")
  try audit_set([duplicate, duplicate]) catch {
    @differential.DifferentialError::DuplicateObservation(
      event~,
      cycle~,
      phase~,
      tap~
    ) => {
      assert_eq(event, 2)
      assert_eq(cycle, 3)
      assert_eq(phase, Settled)
      assert_eq(tap, "top/δ")
    }
    _ => fail("expected duplicate observation rejection")
  } noraise {
    _ => fail("expected duplicate observation rejection")
  }
}

///|
test "observation events map to one monotonic cycle" {
  try
    audit_set([
      audit_observation(0, 0, "top/a", "0"),
      audit_observation(0, 1, "top/b", "0"),
    ])
  catch {
    @differential.DifferentialError::InconsistentObservationEventCycle(
      event~,
      first_cycle~,
      actual_cycle~
    ) => {
      assert_eq(event, 0)
      assert_eq(first_cycle, 0)
      assert_eq(actual_cycle, 1)
    }
    error => fail("unexpected event/cycle error: \{Repr(error)}")
  } noraise {
    _ => fail("expected event/cycle rejection")
  }
  try
    audit_set([
      audit_observation(0, 2, "top/a", "0"),
      audit_observation(1, 1, "top/b", "0"),
    ])
  catch {
    @differential.DifferentialError::NonMonotonicObservationCycle(index~) =>
      assert_eq(index, 1)
    error => fail("unexpected cycle ordering error: \{Repr(error)}")
  } noraise {
    _ => fail("expected observation cycle regression rejection")
  }
}

///|
test "merge comparison reports the first canonical missing or extra key" {
  let a = audit_observation(0, 0, "top/a", "0")
  let b = audit_observation(0, 0, "top/b", "0")
  let c = audit_observation(0, 0, "top/c", "0")
  match @differential.compare(audit_set([b, c]), audit_set([a, c])) {
    Mismatch(mismatch) => {
      assert_eq(mismatch.expected_index(), Some(0))
      assert_eq(mismatch.actual_index(), Some(0))
      match mismatch.kind() {
        ExtraActual(observation) => assert_eq(observation.tap(), "top/a")
        _ => fail("expected leading extra key")
      }
    }
    Equal => fail("expected leading extra key")
  }
}

///|
test "stimulus validation makes simultaneous drive groups canonical" {
  let drive_a = @differential.Stimulus::drive(0, 0, "top/a", audit_value("0"))
  let drive_b = @differential.Stimulus::drive(0, 0, "top/b", audit_value("1"))
  let edge = @differential.Stimulus::rising_edge(0, 0, "core")
  ignore(audit_sequence([drive_a, drive_b, edge]))

  try audit_sequence([drive_b, drive_a, edge]) catch {
    @differential.DifferentialError::NonCanonicalDriveOrder(index~) =>
      assert_eq(index, 1)
    _ => fail("expected canonical UTF-8 drive order")
  } noraise {
    _ => fail("expected canonical UTF-8 drive order")
  }
  try audit_sequence([drive_a, drive_a, edge]) catch {
    @differential.DifferentialError::DuplicateDrive(event~, cycle~, tap~) => {
      assert_eq(event, 0)
      assert_eq(cycle, 0)
      assert_eq(tap, "top/a")
    }
    _ => fail("expected duplicate drive rejection")
  } noraise {
    _ => fail("expected duplicate drive rejection")
  }
  try audit_sequence([drive_a, edge, drive_b]) catch {
    @differential.DifferentialError::DriveAfterBoundary(index~) =>
      assert_eq(index, 2)
    _ => fail("expected drive-after-boundary rejection")
  } noraise {
    _ => fail("expected drive-after-boundary rejection")
  }
  try audit_sequence([drive_a, edge, edge]) catch {
    @differential.DifferentialError::DuplicateEdge(event~, cycle~, domain~) => {
      assert_eq(event, 0)
      assert_eq(cycle, 0)
      assert_eq(domain, "core")
    }
    _ => fail("expected duplicate edge rejection")
  } noraise {
    _ => fail("expected duplicate edge rejection")
  }
  let sample = @differential.Stimulus::sample(0, 0, "top/out")
  try audit_sequence([drive_a, sample, sample]) catch {
    @differential.DifferentialError::DuplicateSample(event~, cycle~, tap~) => {
      assert_eq(event, 0)
      assert_eq(cycle, 0)
      assert_eq(tap, "top/out")
    }
    _ => fail("expected duplicate sample rejection")
  } noraise {
    _ => fail("expected duplicate sample rejection")
  }
}

///|
test "stimulus coordinates are globally monotonic and event-consistent" {
  let first = @differential.Stimulus::sample(1, 2, "top/a")
  let cycle_regression = @differential.Stimulus::sample(2, 1, "top/a")
  try audit_sequence([first, cycle_regression]) catch {
    @differential.DifferentialError::NonMonotonicStimulus(index~) =>
      assert_eq(index, 1)
    _ => fail("expected cycle regression rejection")
  } noraise {
    _ => fail("expected cycle regression rejection")
  }
  let inconsistent = @differential.Stimulus::sample(1, 3, "top/b")
  try audit_sequence([first, inconsistent]) catch {
    @differential.DifferentialError::InconsistentEventCycle(index~) =>
      assert_eq(index, 1)
    _ => fail("expected one cycle per event")
  } noraise {
    _ => fail("expected one cycle per event")
  }
}

///|
fn remove_one(
  sequence : @differential.StimulusSequence,
  remove : Int32,
) -> @differential.StimulusSequence raise {
  let items : Array[@differential.Stimulus] = []
  for index, stimulus in sequence.stimuli() {
    if index != remove {
      items.push(stimulus)
    }
  }
  @differential.StimulusSequence::checked(
    sequence.identity(),
    sequence.seed(),
    items,
  )
}

///|
test "reducer output is deterministically one-minimal" {
  let sequence = audit_sequence([
    @differential.Stimulus::drive(0, 0, "top/a", audit_value("1")),
    @differential.Stimulus::drive(0, 0, "top/b", audit_value("1")),
    @differential.Stimulus::sample(0, 0, "top/out"),
    @differential.Stimulus::sample(1, 1, "top/noise"),
  ])
  let fails = fn(candidate : @differential.StimulusSequence) {
    let mut a = false
    let mut b = false
    for stimulus in candidate.stimuli() {
      match stimulus.action() {
        Drive(tap="top/a", ..) => a = true
        Drive(tap="top/b", ..) => b = true
        _ => ()
      }
    }
    a && b
  }
  let expected_failure = audit_set([audit_observation(9, 9, "top/failure", "1")])
  let no_failure = audit_set([])
  let reproduce = fn(candidate : @differential.StimulusSequence) {
    if fails(candidate) {
      @differential.compare(expected_failure, no_failure)
    } else {
      Equal
    }
  }
  let target = match reproduce(sequence) {
    Mismatch(mismatch) => mismatch.identity()
    Equal => fail("expected initial mismatch")
  }
  let reduced = @differential.reduce_mismatch(sequence, target, reproduce)
  assert_true(fails(reduced.fixture()))
  assert_eq(reduced.fixture().stimuli().length(), 2)
  for index in 0..<reduced.fixture().stimuli().length() {
    assert_false(fails(remove_one(reduced.fixture(), index)))
  }
}

///|
test "typed reducer preserves stable mismatch identity" {
  let trigger = @differential.Stimulus::sample(0, 0, "top/trigger")
  let noise = @differential.Stimulus::sample(1, 1, "top/noise")
  let sequence = audit_sequence([trigger, noise])
  let first_expected = audit_set([audit_observation(0, 0, "top/a", "0")])
  let second_expected = audit_set([audit_observation(0, 0, "top/b", "0")])
  let empty = audit_set([])
  let reproduce = fn(candidate : @differential.StimulusSequence) {
    let mut has_trigger = false
    for stimulus in candidate.stimuli() {
      match stimulus.action() {
        Sample(tap="top/trigger") => has_trigger = true
        _ => ()
      }
    }
    if has_trigger {
      @differential.compare(first_expected, empty)
    } else {
      @differential.compare(second_expected, empty)
    }
  }
  let target = match reproduce(sequence) {
    Mismatch(mismatch) => mismatch.identity()
    Equal => fail("expected initial mismatch")
  }
  let reduced = @differential.reduce_mismatch(sequence, target, reproduce)
  assert_eq(reduced.fixture().stimuli().length(), 1)
  match reduced.fixture().stimuli()[0].action() {
    Sample(tap="top/trigger") => ()
    _ => fail("stable mismatch reduction removed its trigger")
  }
}

///|
test "canonical serializers strictly round trip and reject ambiguity" {
  let semantic = "semantics/δ 1\nlocked"
  let design = audit_design(semantic_version=semantic)
  let sequence = @differential.StimulusSequence::checked(design, 99, [
    @differential.Stimulus::drive(0, 0, "top/a", audit_value("10X")),
    @differential.Stimulus::rising_edge(0, 0, "core"),
    @differential.Stimulus::sample(0, 0, "top/out"),
  ])
  let stimulus_text = sequence.to_canonical_text()
  assert_eq(@differential.parse_stimulus_sequence(stimulus_text), sequence)

  let result = @differential.ObservationSet::checked(
    @differential.ResultIdentity::checked(
      design, "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    ),
    [audit_observation(0, 0, "top/out", "10X")],
  )
  let result_text = result.to_canonical_text()
  assert_eq(@differential.parse_observation_set(result_text), result)

  try @differential.parse_stimulus_sequence(stimulus_text + "\n") catch {
    NonCanonicalArtifact => ()
    _ => fail("expected redundant newline rejection")
  } noraise {
    _ => fail("expected redundant newline rejection")
  }
  let wrong_algorithm = result_text.replace(
    old="DESIGN sha256",
    new="DESIGN sha512",
  )
  try @differential.parse_observation_set(wrong_algorithm) catch {
    InvalidCanonicalLine(..) => ()
    _ => fail("expected digest algorithm rejection")
  } noraise {
    _ => fail("expected digest algorithm rejection")
  }
  let wrong_ordinal = result_text.replace(old="O 0 ", new="O 1 ")
  try @differential.parse_observation_set(wrong_ordinal) catch {
    InvalidCanonicalLine(..) => ()
    _ => fail("expected ordinal rejection")
  } noraise {
    _ => fail("expected ordinal rejection")
  }
}
