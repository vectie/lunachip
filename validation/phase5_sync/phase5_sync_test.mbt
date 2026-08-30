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
fn assert_artifact_hash(
  bundle : @phase5_sync.SyncFixtureBundle,
  path : String,
  expected : String,
) -> Unit raise {
  assert_eq(@verilator.sha256_hex(artifact(bundle, path)), expected)
}

///|
test "phase-neutral extraction preserves every synchronizer bundle byte" {
  let async_bundle = @phase5_sync.generate_sync_fixture(AsyncTwoStage)
  assert_eq(async_bundle.artifacts().length(), 7)
  for
    entry in [
      (
        "design.lcir", "032c66015a8f121cf8ff13bcae391097ade380d5994b11784992a120e808bd26",
      ),
      (
        "expected.tsv", "14dbce26519194540a8833ca523a4325899e73ab25d27bdfcfd73e82780fd395",
      ),
      (
        "harness.cpp", "1bfae384ef9418cac9cf90945e989ec1d7ce0212c69a6936e6bae3161e028d7c",
      ),
      (
        "lc_m0_b50_b68_b61_b73_b65_b35_b41_b73_b79_b6e_b63_b54_b77_b6f_b53_b74_b61_b67_b65.sv",
        "d9c38802757a1f15e64d53033f9f58633c6116c7c9fcb93df48ed4473f18766f",
      ),
      (
        "manifest.json", "51997ace5a570e42c3e6f33fc7b9bb20acf0bf1c5dea8eb9ad972be9a5e74562",
      ),
      (
        "names.lcnm", "637ca67508e04d30d694151fe12e439962668b9fb095e844454740ceb424f215",
      ),
      (
        "stimulus.tsv", "5e74108484c793ec5966c40a28214e49739b681a6a1549cc392384f4e8add30c",
      ),
    ] {
    let (path, digest) = entry
    assert_artifact_hash(async_bundle, path, digest)
  }
  let three = @phase5_sync.generate_sync_fixture(TimedThreeStage)
  assert_eq(three.artifacts().length(), 7)
  for
    entry in [
      (
        "design.lcir", "bdcb8ecbe7aa4b5ad043911a79bb8ac52395c1cda10706956a643cd1f4bf9983",
      ),
      (
        "expected.tsv", "61eb10fb0beba5c9cbcbcd1aeb591af10e3f5f3de2b93fbb00d7dd7aa7eaaef7",
      ),
      (
        "harness.cpp", "727e2ffbc1da64499b799c0c3114df1005c727a16b7245a57197c7e289693f99",
      ),
      (
        "lc_m0_b50_b68_b61_b73_b65_b35_b54_b69_b6d_b65_b64_b54_b68_b72_b65_b65_b53_b74_b61_b67_b65.sv",
        "5e77f64d843e4c22ccaa4faeac49ba40bc6836dc703919ccb470655877563a82",
      ),
      (
        "manifest.json", "dbb5619ff9f1c56b3a7faa3d1b1233d9ecd994d417936095848f97ba635e66f9",
      ),
      (
        "names.lcnm", "af310c7e5ec7e560a77a40d1597d0e5bb1301fc5f7d962049f549bbdf30afe53",
      ),
      (
        "stimulus.tsv", "ec6c63abfed4803204bee6f4ec7dfaeaa5d0f8c9d6ebc5ac9778b23218077732",
      ),
    ] {
    let (path, digest) = entry
    assert_artifact_hash(three, path, digest)
  }
  let four = @phase5_sync.generate_sync_fixture(TimedFourStage)
  assert_eq(four.artifacts().length(), 7)
  for
    entry in [
      (
        "design.lcir", "fda4fca42e6db1be2a5574153d063c66813a52c3fcbf99cdcc5ee466df6fb7a4",
      ),
      (
        "expected.tsv", "3324c37a239a973566bf1fb6af11500f0dee2d44a00dc88d7117e9e3a9a3b97d",
      ),
      (
        "harness.cpp", "1d21ce44f5a0dbe77c1ceeae592b01bc2ca1e5c21cb4440b52d8e6b7f3ba1c38",
      ),
      (
        "lc_m0_b50_b68_b61_b73_b65_b35_b54_b69_b6d_b65_b64_b46_b6f_b75_b72_b53_b74_b61_b67_b65.sv",
        "7879030833bbc73604fb88388e73273c604f53f22776417bd39dbda34dc40892",
      ),
      (
        "manifest.json", "05dcbbfe9b6bd75efffb25b1e9d1e7e9ea25e4f9bfc9797e4c0a33800f2ff62a",
      ),
      (
        "names.lcnm", "d49876c3b135eee1a33f39155f4bc51526d6f85e0f89e64efe50dc168aa48be2",
      ),
      (
        "stimulus.tsv", "3d3eb3b8f9f8f5f8694ef3e053749dce7275522836dd0e71d54197b58a107a58",
      ),
    ] {
    let (path, digest) = entry
    assert_artifact_hash(four, path, digest)
  }
  let negative = @phase5_sync.generate_sequential_negative_fixture()
  assert_eq(negative.artifacts().length(), 8)
  for
    entry in [
      (
        "design.lcir", "bdcb8ecbe7aa4b5ad043911a79bb8ac52395c1cda10706956a643cd1f4bf9983",
      ),
      (
        "expected-sequential.tsv", "d9fbe189dd71951e1a42f81aa5f9e9a3c8ee30b833b9da0fc3259d342591e80e",
      ),
      (
        "expected.tsv", "61eb10fb0beba5c9cbcbcd1aeb591af10e3f5f3de2b93fbb00d7dd7aa7eaaef7",
      ),
      (
        "harness.cpp", "700bd5d068904e028f91f6257a0aec1f50c73fd911d7d97c9bddb0e7d6460034",
      ),
      (
        "lc_m0_b50_b68_b61_b73_b65_b35_b54_b69_b6d_b65_b64_b54_b68_b72_b65_b65_b53_b74_b61_b67_b65.sv",
        "5e77f64d843e4c22ccaa4faeac49ba40bc6836dc703919ccb470655877563a82",
      ),
      (
        "manifest.json", "dbb5619ff9f1c56b3a7faa3d1b1233d9ecd994d417936095848f97ba635e66f9",
      ),
      (
        "names.lcnm", "af310c7e5ec7e560a77a40d1597d0e5bb1301fc5f7d962049f549bbdf30afe53",
      ),
      (
        "stimulus.tsv", "ec6c63abfed4803204bee6f4ec7dfaeaa5d0f8c9d6ebc5ac9778b23218077732",
      ),
    ] {
    let (path, digest) = entry
    assert_artifact_hash(negative, path, digest)
  }
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
test "atomic manifest and C++ share exact stimulus-port validation" {
  let bundle = @phase5_sync.generate_sync_fixture(AsyncTwoStage)
  guard bundle.design().top_module() is Some(hardware_module) else {
    fail("missing top module")
  }
  let ports = @verilator.collect_ports(
    hardware_module,
    bundle.emitted().manifest(),
  )
  let invalid = @verilator.AtomicStimulus::checked(
    1UL,
    [@verilator.StimulusDomain::checked(0, "missing_clock")],
    [@verilator.AtomicStimulusEvent::checked(0UL, 0UL, [], [0])],
  )
  try
    @verilator.atomic_harness_json(
      bundle.emitted(),
      ports,
      invalid,
      "harness.cpp",
    )
  catch {
    InvalidAtomicStimulusClockPort("missing_clock") => ()
    _ => fail("expected manifest clock-port rejection")
  } noraise {
    _ => fail("expected manifest clock-port rejection")
  }
  try
    @verilator.atomic_harness_cpp(ports, invalid, "RESULT\n", AtomicEdges)
  catch {
    InvalidAtomicStimulusClockPort("missing_clock") => ()
    _ => fail("expected C++ clock-port rejection")
  } noraise {
    _ => fail("expected C++ clock-port rejection")
  }
  for
    invalid_filename in [
      "../harness.cpp", "/harness.cpp", "nested path/harness.cpp", "harness.cc",
    ] {
    try
      @verilator.atomic_harness_json(
        bundle.emitted(),
        ports,
        bundle.stimulus(),
        invalid_filename,
      )
    catch {
      InvalidAtomicHarnessFilename(actual) =>
        assert_eq(actual, invalid_filename)
      _ => fail("expected safe-relative harness filename rejection")
    } noraise {
      _ => fail("expected safe-relative harness filename rejection")
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
