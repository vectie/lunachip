///|
test "handshake differential fixtures are canonical and fully observed" {
  for kind in @phase5_handshake_diff.standard_handshake_fixtures() {
    let first = @phase5_handshake_diff.generate_handshake_fixture(kind)
    let second = @phase5_handshake_diff.generate_handshake_fixture(kind)
    assert_eq(first.artifacts(), second.artifacts())
    assert_true(first.stimulus().events().length() > 20)
    assert_eq(first.compare_actual(first.expected_tsv()), None)
    for event in first.stimulus().events() {
      for drive in event.drives() {
        assert_false(drive.value().known_mask().contains("0"))
      }
    }
    let header = first.expected_tsv().split("\n").to_array()[1]
    assert_true(header.contains("destination_valid"))
    assert_true(header.contains("destination_word"))
    assert_true(header.contains("source_ready"))
    if kind == MultiLeafRational {
      assert_true(header.contains("destination_tag"))
    }
  }
}

///|
test "reset-loss fixture is classified without broadening the claim" {
  let reset_kind : @phase5_handshake_diff.HandshakeFixtureKind = CoordinatedResetFlush
  assert_eq(reset_kind.evidence_class(), "expected-reset-flush-loss")
  for kind in @phase5_handshake_diff.standard_handshake_fixtures() {
    if kind != CoordinatedResetFlush {
      assert_eq(kind.evidence_class(), "lossless-coordinated-operation")
    }
  }
}

///|
test "handshake matrix contains atomic coincidences and a wrong-edge witness" {
  let mut coincidences = 0
  for kind in @phase5_handshake_diff.standard_handshake_fixtures() {
    for
      event in @phase5_handshake_diff.generate_handshake_fixture(kind)
      .stimulus()
      .events() {
      if event.domains().length() == 2 {
        coincidences += 1
      }
    }
  }
  assert_true(coincidences > 0)
  let negative = @phase5_handshake_diff.generate_sequential_negative_fixture()
  assert_eq(
    negative.compare_actual(negative.sequential_tsv()),
    Some(@phase5_handshake_diff.required_sequential_mismatch()),
  )
}

///|
test "coincident fixture consumes and refills one response atomically" {
  let fixture = @phase5_handshake_diff.generate_handshake_fixture(
    CoincidentRefill,
  )
  assert_true(fixture.expected_tsv().contains("70\t35\t1\t19\t0\n"))
  assert_true(fixture.expected_tsv().contains("72\t36\t1\te6\t0\n"))
}

///|
test "directed scalar fixture covers capture acknowledge and consume" {
  let fixture = @phase5_handshake_diff.generate_handshake_fixture(
    DirectedScalar,
  )
  assert_true(fixture.expected_tsv().contains("14\t9\t0\t00\t0\n"))
  assert_true(fixture.expected_tsv().contains("21\t14\t1\t2a\t0\n"))
  assert_true(fixture.expected_tsv().contains("24\t16\t1\t2a\t1\n"))
  assert_true(fixture.expected_tsv().contains("33\t22\t0\t2a\t1\n"))
}
