///|
fn value(text : String) -> @differential.NormalizedValue raise {
  @differential.NormalizedValue::parse(text)
}

///|
fn design_identity() -> @differential.DesignIdentity raise {
  @differential.DesignIdentity::checked(
    "phase3-v1", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  )
}

///|
fn result_identity() -> @differential.ResultIdentity raise {
  @differential.ResultIdentity::checked(
    design_identity(),
    "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  )
}

///|
fn observation(
  event : UInt64,
  cycle : UInt64,
  phase : @differential.ObservationPhase,
  tap : String,
  bits : String,
) -> @differential.Observation raise {
  @differential.Observation::checked(event, cycle, phase, tap, value(bits))
}

///|
fn observation_set(
  observations : Array[@differential.Observation],
) -> @differential.ObservationSet raise {
  @differential.ObservationSet::checked(result_identity(), observations)
}

///|
fn stimulus_sequence(
  seed : UInt64,
  stimuli : Array[@differential.Stimulus],
) -> @differential.StimulusSequence raise {
  @differential.StimulusSequence::checked(design_identity(), seed, stimuli)
}

///|
test "normalizes 0/1/X values and unknown bit payloads" {
  assert_eq(value("10xX").to_text(), "10XX")
  assert_eq(
    @differential.NormalizedValue::from_planes("1101", "1010").to_text(),
    "1X0X",
  )
}

///|
test "equal observation sets compare equal independent of adapter order" {
  let first = observation(0, 0, Settled, "top/a", "1")
  let second = observation(1, 1, PostEdge, "top/data", "10X0")
  let expected = observation_set([second, first])
  let actual = observation_set([first, second])
  assert_eq(@differential.compare(expected, actual), Equal)
}

///|
test "reports a stable value and X mismatch" {
  let expected = observation_set([
    observation(4, 3, PostEdge, "top/data", "10X0"),
  ])
  let actual = observation_set([observation(4, 3, PostEdge, "top/data", "1010")])
  match @differential.compare(expected, actual) {
    Mismatch(mismatch) => {
      assert_eq(mismatch.expected_index(), Some(0))
      assert_eq(mismatch.actual_index(), Some(0))
      match mismatch.kind() {
        ValueMismatch(difference~, ..) =>
          assert_eq(
            difference,
            Bit(index_from_msb=2, expected=Unknown, actual=One),
          )
        _ => fail("expected value mismatch")
      }
    }
    Equal => fail("expected mismatch")
  }
}

///|
test "distinguishes missing taps and extra events" {
  let base = observation(0, 0, Settled, "top/a", "0")
  let expected = observation_set([
    base,
    observation(1, 1, Settled, "top/b", "1"),
  ])
  let missing_tap = observation_set([base])
  match @differential.compare(expected, missing_tap) {
    Mismatch(mismatch) =>
      match mismatch.kind() {
        MissingActual(missing) => assert_eq(missing.tap(), "top/b")
        _ => fail("expected missing observation")
      }
    Equal => fail("expected missing observation")
  }

  let extra_event = observation_set([
    base,
    observation(2, 2, Settled, "top/c", "X"),
  ])
  match @differential.compare(observation_set([base]), extra_event) {
    Mismatch(mismatch) =>
      match mismatch.kind() {
        ExtraActual(extra) => {
          assert_eq(extra.event(), 2)
          assert_eq(extra.tap(), "top/c")
        }
        _ => fail("expected extra observation")
      }
    Equal => fail("expected extra observation")
  }
}

///|
test "first mismatch is stable after canonical sorting" {
  let expected = observation_set([
    observation(5, 5, Settled, "top/z", "0"),
    observation(1, 1, Settled, "top/b", "1"),
    observation(1, 1, Settled, "top/a", "1"),
  ])
  let actual = observation_set([
    observation(5, 5, Settled, "top/z", "1"),
    observation(1, 1, Settled, "top/a", "0"),
    observation(1, 1, Settled, "top/b", "0"),
  ])
  match @differential.compare(expected, actual) {
    Mismatch(mismatch) =>
      match mismatch.kind() {
        ValueMismatch(expected~, ..) => assert_eq(expected.tap(), "top/a")
        _ => fail("expected value mismatch")
      }
    Equal => fail("expected mismatch")
  }
}

///|
test "canonical tap order is UTF-8 byte order" {
  let results = observation_set([
    observation(0, 0, Settled, "top/𐀀", "1"),
    observation(0, 0, Settled, "top/", "0"),
  ])
  inspect(
    results.to_canonical_text(),
    content=(
      #|LUNACHIP-DIFFERENTIAL-RESULT 1
      #|SEMANTIC 7068617365332d7631
      #|DESIGN sha256 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
      #|STIMULUS sha256 bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
      #|OBSERVATIONS 2
      #|O 0 0 0 settled 746f702fee8080 1 0 1
      #|O 1 0 0 settled 746f702ff0908080 1 1 1
      #|END
      #|
    ),
  )
}

///|
test "deterministic reducer preserves the caller failure predicate" {
  let sequence = stimulus_sequence(1234, [
    @differential.Stimulus::drive(0, 0, "top/noise", value("0")),
    @differential.Stimulus::sample(0, 0, "top/noise"),
    @differential.Stimulus::drive(1, 1, "top/trigger", value("1")),
    @differential.Stimulus::rising_edge(1, 1, "core"),
    @differential.Stimulus::sample(1, 1, "top/out"),
  ])
  let failure_predicate = fn(candidate : @differential.StimulusSequence) {
    let mut trigger = false
    let mut edge = false
    for stimulus in candidate.stimuli() {
      match stimulus.action() {
        Drive(tap="top/trigger", ..) => trigger = true
        RisingEdge(domain="core") => edge = true
        _ => ()
      }
    }
    trigger && edge
  }
  let expected_failure = observation_set([
    observation(9, 9, Settled, "top/failure", "1"),
  ])
  let no_failure = observation_set([])
  let reproduce = fn(candidate : @differential.StimulusSequence) {
    if failure_predicate(candidate) {
      @differential.compare(expected_failure, no_failure)
    } else {
      Equal
    }
  }
  let target = match reproduce(sequence) {
    Mismatch(mismatch) => mismatch.identity()
    Equal => fail("expected initial mismatch")
  }
  let first = @differential.reduce_mismatch(sequence, target, reproduce)
  let second = @differential.reduce_mismatch(sequence, target, reproduce)
  assert_eq(first.fixture().seed(), 1234)
  assert_eq(first.fixture().stimuli().length(), 2)
  assert_true(failure_predicate(first.fixture()))
  assert_eq(
    first.fixture().to_canonical_text(),
    second.fixture().to_canonical_text(),
  )
}

///|
test "canonical persisted artifacts are byte stable" {
  let sequence = stimulus_sequence(42, [
    @differential.Stimulus::drive(0, 0, "top/δ", value("10X")),
    @differential.Stimulus::rising_edge(1, 1, "clk"),
    @differential.Stimulus::sample(1, 1, "top/out"),
  ])
  inspect(
    sequence.to_canonical_text(),
    content=(
      #|LUNACHIP-DIFFERENTIAL-STIMULUS 1
      #|SEMANTIC 7068617365332d7631
      #|DESIGN sha256 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
      #|SEED 42
      #|STIMULI 3
      #|S 0 0 0 drive 746f702fceb4 3 100 110
      #|S 1 1 1 edge 636c6b
      #|S 2 1 1 sample 746f702f6f7574
      #|END
      #|
    ),
  )
  let results = observation_set([observation(1, 1, Settled, "top/out", "10X")])
  inspect(
    results.to_canonical_text(),
    content=(
      #|LUNACHIP-DIFFERENTIAL-RESULT 1
      #|SEMANTIC 7068617365332d7631
      #|DESIGN sha256 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
      #|STIMULUS sha256 bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
      #|OBSERVATIONS 1
      #|O 0 1 1 settled 746f702f6f7574 3 100 110
      #|END
      #|
    ),
  )
}
