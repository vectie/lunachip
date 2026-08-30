///|
fn artifact(
  bundle : @phase5_sync.SyncFixtureBundle,
  path : String,
) -> String raise {
  for item in bundle.artifacts() {
    if item.path() == path {
      return item.content()
    }
  }
  fail("missing artifact \{path}")
}

///|
test "production fixture matrix preserves exact schedules and sparse IDs" {
  let kinds = @phase5_sync.standard_sync_fixtures()
  assert_eq(kinds.length(), 3)
  let async_bundle = @phase5_sync.generate_sync_fixture(AsyncTwoStage)
  assert_eq(async_bundle.stimulus().ticks_per_source_unit(), 1UL)
  assert_eq(async_bundle.stimulus().events().length(), 14)
  assert_eq(async_bundle.stimulus().domains().map(domain => domain.id()), [0])
  let coprime = @phase5_sync.generate_sync_fixture(TimedThreeStage)
  assert_eq(coprime.stimulus().ticks_per_source_unit(), 15UL)
  assert_eq(coprime.stimulus().events().length(), 25)
  assert_eq(coprime.stimulus().domains().map(domain => domain.id()), [0, 3])
  assert_eq(coprime.stimulus().events()[15].time(), 75UL)
  assert_eq(coprime.stimulus().events()[15].domains(), [0, 3])
  let noncoprime = @phase5_sync.generate_sync_fixture(TimedFourStage)
  assert_eq(noncoprime.stimulus().ticks_per_source_unit(), 1UL)
  assert_eq(noncoprime.stimulus().events().length(), 13)
  let mut coincidences = 0
  for event in noncoprime.stimulus().events() {
    if event.domains().length() == 2 {
      coincidences += 1
    }
  }
  assert_eq(coincidences, 7)
}

///|
test "schedule projection is canonical and does not regenerate event identity" {
  for kind in @phase5_sync.standard_sync_fixtures() {
    let bundle = @phase5_sync.generate_sync_fixture(kind)
    let stimulus = bundle.stimulus()
    assert_eq(@verilator.parse_atomic_stimulus(stimulus.to_tsv()), stimulus)
    for ordinal, event in stimulus.events() {
      assert_eq(event.boundary(), ordinal.to_uint64())
      if ordinal > 0 {
        assert_true(event.time() > stimulus.events()[ordinal - 1].time())
      }
    }
    let manifest = artifact(bundle, "manifest.json")
    assert_true(
      manifest.contains("\"schema_version\": \"lunachip.verilator-harness/v2\""),
    )
    if kind != AsyncTwoStage {
      assert_true(manifest.contains("\"id\": 0"))
      assert_true(manifest.contains("\"id\": 3"))
      assert_false(manifest.contains("\"id\": 1"))
    }
  }
}

///|
test "production harness is atomic and sequential bridge is isolated" {
  let production = @phase5_sync.generate_sync_fixture(TimedThreeStage)
  let negative = @phase5_sync.generate_sequential_negative_fixture()
  let production_cpp = artifact(production, "harness.cpp")
  let negative_cpp = artifact(negative, "harness.cpp")
  assert_true(
    production_cpp.contains(
      "for (const auto id : active) {\n      if (id == 0U)",
    ),
  )
  assert_true(
    production_cpp.contains("    }\n    top.eval();\n    result << time"),
  )
  assert_true(
    negative_cpp.contains(
      "      else return 68;\n      top.eval();\n    }\n    result << time",
    ),
  )
  assert_false(production_cpp == negative_cpp)
  assert_false(
    production.artifacts().any(item => item.path() == "expected-sequential.tsv"),
  )
  assert_true(
    negative.artifacts().any(item => item.path() == "expected-sequential.tsv"),
  )
}

///|
test "atomic result validator finds the frozen first sequential mismatch" {
  let positive = @phase5_sync.generate_sync_fixture(TimedThreeStage)
  assert_eq(positive.compare_actual(positive.expected_tsv()), None)
  let mismatch = match positive.compare_actual(positive.sequential_tsv()) {
    Some(found) => found
    None => fail("sequential edge model unexpectedly matched")
  }
  assert_eq(mismatch, @phase5_sync.required_sequential_mismatch())
  assert_eq(
    @phase5_sync.verify_sequential_negative(positive.sequential_tsv()),
    mismatch,
  )
}

///|
test "atomic result validator rejects identity time and value corruption" {
  let bundle = @phase5_sync.generate_sync_fixture(AsyncTwoStage)
  let expected = bundle.expected_tsv()
  try
    bundle.compare_actual(
      expected.replace(
        old="LUNACHIP-PHASE5-SYNC-RESULT",
        new="LUNACHIP-PHASE5-SYNC-RESULT-BAD",
      ),
    )
  catch {
    InvalidActualResult(reason~, row=1) =>
      assert_eq(reason, "identity header mismatch")
    _ => fail("expected identity rejection")
  } noraise {
    _ => fail("expected identity rejection")
  }
  try
    bundle.compare_actual(expected.replace(old="0\t0\t0", new="00\t0\t0"))
  catch {
    InvalidActualResult(reason~, row=3) =>
      assert_eq(reason, "noncanonical time")
    _ => fail("expected exact-time rejection")
  } noraise {
    _ => fail("expected exact-time rejection")
  }
  try
    bundle.compare_actual(expected.replace(old="0\t0\t0", new="0\t0\tx"))
  catch {
    InvalidActualResult(reason~, row=3) =>
      assert_eq(reason, "noncanonical one-bit result")
    _ => fail("expected two-state result rejection")
  } noraise {
    _ => fail("expected two-state result rejection")
  }
}
