///|
test "standard plan exceeds the 100,000 post-reset-cycle gate" {
  let plans = @phase3.standard_plan()
  let copied : Array[@phase3.FixturePlan] = []
  for plan in plans {
    copied.push(plan)
  }
  assert_eq(plans.length(), 6)
  assert_eq(@phase3.total_post_reset_cycles(copied), 102000)
}

///|
test "all representative bundles are deterministic and self-comparable" {
  let kinds : Array[@phase3.FixtureKind] = [
    CombinationalLogic,
    Arithmetic,
    ControlledCounter,
    Pipeline,
    Lfsr,
    ReadyValid,
  ]
  for index, kind in kinds {
    let plan = @phase3.FixturePlan::checked(
      kind,
      0x1020304050607080UL + index.to_uint64(),
      4,
    )
    let bundle = @phase3.generate_bundle(plan)
    assert_true(
      bundle.harness_json().contains("\"stimulus\": \"stimulus.tsv\""),
    )
    assert_true(bundle.harness_json().contains("\"result\": \"actual.tsv\""))
    assert_true(bundle.harness_cpp().contains("#include \"Vlunachip_model.h\""))
    assert_true(bundle.harness_cpp().contains("using Model = Vlunachip_model;"))
    assert_true(bundle.stimulus_tsv().has_suffix("\n"))
    assert_true(bundle.expected_tsv().has_prefix("LUNACHIP-PHASE3-RESULT\t1\t"))
    let actual = bundle.parse_actual_tsv(bundle.expected_tsv())
    assert_true(bundle.compare_actual(actual) is Equal)
    assert_true(bundle.compare_actual_tsv(bundle.expected_tsv()) is Equal)
    assert_eq(bundle.expected().observations().length() % 4, 0)
    for observation in bundle.expected().observations() {
      assert_false(observation.value().to_text().contains("X"))
      assert_true(observation.cycle() >= 1UL)
    }
    let paths : Array[String] = []
    for artifact in bundle.artifacts() {
      paths.push(artifact.path())
    }
    assert_true(paths.contains("manifest.json"))
    assert_true(paths.contains("design.lcir"))
    assert_true(paths.contains("stimulus.tsv"))
    assert_true(paths.contains("expected.tsv"))
    let mut design_text = ""
    for artifact in bundle.artifacts() {
      if artifact.path() == "design.lcir" {
        design_text = artifact.content()
      }
    }
    assert_eq(design_text, @ir_codec.serialize(bundle.design()))
    assert_eq(
      bundle.expected().identity().design().design_sha256(),
      @crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode(design_text))),
    )
  }
}

///|
test "bundle bytes are stable for an identical plan" {
  let plan = @phase3.FixturePlan::checked(ControlledCounter, 123456789UL, 8)
  let first = @phase3.generate_bundle(plan)
  let second = @phase3.generate_bundle(plan)
  assert_eq(first.harness_json(), second.harness_json())
  assert_eq(first.harness_cpp(), second.harness_cpp())
  assert_eq(first.stimulus_tsv(), second.stimulus_tsv())
  assert_eq(first.expected_tsv(), second.expected_tsv())
  assert_eq(first.artifacts(), second.artifacts())
}

///|
test "actual TSV identity is parsed from the file and compared" {
  let plan = @phase3.FixturePlan::checked(Lfsr, 9UL, 2)
  let bundle = @phase3.generate_bundle(plan)
  let actual = bundle
    .expected_tsv()
    .replace_all(
      old=bundle.expected().identity().design().design_sha256(),
      new="0000000000000000000000000000000000000000000000000000000000000000",
    )
  assert_true(bundle.compare_actual_tsv(actual) is Mismatch(_))
}
