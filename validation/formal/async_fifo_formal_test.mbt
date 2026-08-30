///|
fn async_fifo_artifact(
  bundle : AsyncFifoFormalBundle,
  path : String,
) -> String raise {
  for artifact in bundle.artifacts() {
    if artifact.path() == path {
      return artifact.content()
    }
  }
  fail("missing asynchronous-FIFO artifact \{path}")
}

///|
fn async_fifo_all_fixtures() -> Array[AsyncFifoFormalFixture] {
  [
    ValidAsyncFifo,
    BrokenAsyncFifoGray,
    BrokenAsyncFifoFull,
    BrokenAsyncFifoAddress,
    BrokenAsyncFifoStorageOrder,
    BrokenAsyncFifoReadPipeline,
    BrokenAsyncFifoWritePipeline,
    BrokenAsyncFifoWriteAddressBounds,
    BrokenAsyncFifoReadAddressBounds,
  ]
}

///|
fn async_fifo_expected_observations() -> Array[(String, Int)] {
  [
    ("source_transfer", 1),
    ("destination_transfer", 1),
    ("write_binary", 3),
    ("write_binary_next", 3),
    ("read_binary", 3),
    ("read_binary_next", 3),
    ("write_gray", 3),
    ("write_gray_next", 3),
    ("read_gray", 3),
    ("read_gray_next", 3),
    ("read_gray_stage0", 3),
    ("read_gray_stage1", 3),
    ("write_gray_stage0", 3),
    ("write_gray_stage1", 3),
    ("full", 1),
    ("full_next", 1),
    ("nonempty", 1),
    ("nonempty_next", 1),
    ("write_address", 2),
    ("read_address", 2),
  ]
}

///|
test "all asynchronous FIFO fixtures connect exact observation ports" {
  let valid = generate_async_fifo_formal_bundle(ValidAsyncFifo)
  let fixed_properties = async_fifo_artifact(valid, "properties.lcfp")
  for fixture in async_fifo_all_fixtures() {
    let bundle = generate_async_fifo_formal_bundle(fixture)
    let harness = async_fifo_artifact(bundle, "formal-harness.sv")
    let dut = bundle
      .artifacts()
      .filter(artifact => {
        artifact.path().has_suffix(".sv") &&
        artifact.path() != "formal-harness.sv"
      })
    assert_eq(dut.length(), 1)
    assert_false(harness.contains("lc_dut."))
    assert_eq(async_fifo_artifact(bundle, "properties.lcfp"), fixed_properties)
    let expected = async_fifo_expected_observations()
    for index, role_width in expected {
      let (role, width) = role_width
      let port = "lc_formal_observe_\{role}"
      let range = if width == 1 { "" } else { "[\{width - 1}:0] " }
      let declaration_suffix = if index + 1 == expected.length() {
        "\n);\n\n"
      } else {
        ",\n"
      }
      let declaration = "output logic \{range}\{port}" + declaration_suffix
      assert_eq(dut[0].content().split(declaration).length(), 2)
      assert_true(harness.contains("wire \{range}lc_\{role};"))
      let connection = ".\{port}(lc_\{role})"
      assert_true(harness.contains(connection))
      assert_eq(harness.split(connection).length(), 2)
    }
  }
}

///|
test "asynchronous FIFO bundle is deterministic and binds exact property matrix" {
  let bundle = generate_async_fifo_formal_bundle(ValidAsyncFifo)
  assert_eq(bundle, generate_async_fifo_formal_bundle(ValidAsyncFifo))
  assert_eq(bundle.tasks().length(), 7)
  assert_eq(bundle.completion_bound(), 80)
  assert_eq(bundle.expected_failure(), "none")
  let source = async_fifo_artifact(bundle, "source-set.lcfs")
  for
    line in [
      "FAMILY async-fifo\n", "PROFILE depth=4 payload=bits8 synchronizer-stages=2\n",
      "COINCIDENCE atomic-global-pre-state\n", "RESET coordinated-idle-initialization-unilateral-reset-excluded\n",
      "COMPLETION-BOUND scheduling-intervals 80 conditional-on-bounded-clocks-eventual-ready-and-at-least-80-remaining-bmc-intervals\n",
    ] {
    assert_true(source.contains(line))
  }
  assert_eq(regenerate_formal_artifacts(source), bundle.artifacts())
  let properties = @formal_core.parse_formal_property_manifest(
    async_fifo_artifact(bundle, "properties.lcfp"),
  )
  assert_eq(properties.properties().length(), 35)
  assert_eq(
    properties.properties().filter(p => p.kind() is Assumption).length(),
    7,
  )
  assert_eq(
    properties.properties().filter(p => p.kind() is Assertion).length(),
    22,
  )
  assert_eq(properties.properties().filter(p => p.kind() is Cover).length(), 6)
}

///|
test "asynchronous FIFO tasks bind sparse schema two clocks and individual covers" {
  let bundle = generate_async_fifo_formal_bundle(ValidAsyncFifo)
  guard bundle.tasks()[0].task() is Bounded(task) else {
    fail("expected bounded task")
  }
  guard task.timing_contract() is Some(timing) else {
    fail("missing timing contract")
  }
  assert_eq(timing.clocks().map(clock => clock.domain().ordinal()), [0, 2])
  assert_eq(timing.coincidence_policy(), AtomicGlobalPreState)
  let covers = bundle.tasks().filter(t => t.task_class() is BoundedCoverTask)
  assert_eq(covers.length(), 6)
  for cover in covers {
    guard cover.task() is Bounded(value) else { fail("cover must be bounded") }
    assert_eq(value.properties().length(), 1)
  }
}

///|
test "asynchronous FIFO semantic mutants preserve production bytes and predicates" {
  let valid = generate_async_fifo_formal_bundle(ValidAsyncFifo)
  let valid_ir = async_fifo_artifact(valid, "design.lcir")
  let valid_rtl = valid
    .artifacts()
    .filter(a => a.path().has_suffix(".sv") && a.path() != "formal-harness.sv")
  assert_eq(valid_rtl.length(), 1)
  let cases : Array[(AsyncFifoFormalFixture, String, String)] = [
    (
      BrokenAsyncFifoGray,
      "lc_monitored_write_gray_equation = lc_write_gray_next ^",
      "write_gray_equation_exact",
    ),
    (
      BrokenAsyncFifoFull,
      "lc_monitored_full_next = lc_full_next ^",
      "full_equation_exact",
    ),
    (
      BrokenAsyncFifoAddress,
      "lc_monitored_write_address = lc_write_address ^",
      "write_address_selection_exact",
    ),
    (
      BrokenAsyncFifoStorageOrder,
      "lc_monitored_destination_word = lc_destination_word ^",
      "watched_token_data_integrity",
    ),
    (
      BrokenAsyncFifoReadPipeline,
      "lc_monitored_read_gray_stage0 = lc_read_gray_stage0 ^",
      "read_gray_source_pipeline_exact",
    ),
    (
      BrokenAsyncFifoWritePipeline,
      "lc_monitored_write_gray_stage0 = lc_write_gray_stage0 ^",
      "write_gray_destination_pipeline_exact",
    ),
    (
      BrokenAsyncFifoWriteAddressBounds,
      "lc_monitored_write_address_wide = {1'b0,lc_write_address} |",
      "write_address_in_bounds",
    ),
    (
      BrokenAsyncFifoReadAddressBounds,
      "lc_monitored_read_address_wide = {1'b0,lc_read_address} |",
      "read_address_in_bounds",
    ),
  ]
  let predicates = [
    "lc_write_gray_equation_exact = lc_monitored_write_gray_equation", "lc_write_gray_hold_or_one_bit_transition = lc_source_transfer",
    "lc_read_gray_equation_exact = lc_read_gray_next", "lc_read_gray_hold_or_one_bit_transition = lc_destination_transfer",
    "lc_full_equation_exact = lc_monitored_full_next", "lc_write_address_selection_exact = lc_monitored_write_address",
    "lc_write_address_in_bounds = lc_monitored_write_address_wide < 4", "lc_read_address_selection_exact = lc_read_address",
    "lc_read_address_in_bounds = lc_monitored_read_address_wide < 4", "lc_watched_token_ordering = !lc_ordering_error",
    "lc_watched_token_data_integrity = !lc_data_error",
  ]
  let valid_harness = async_fifo_artifact(valid, "formal-harness.sv")
  assert_true(
    valid_harness.contains(
      "wire lc_source_event = lc_protocol_active && lc_source_rise && lc_source_transfer;",
    ),
  )
  assert_true(
    valid_harness.contains(
      "wire lc_destination_event = lc_protocol_active && lc_destination_rise && lc_destination_transfer;",
    ),
  )
  assert_true(valid_harness.contains("if (lc_destination_event) begin\n"))
  assert_true(valid_harness.contains("if (lc_source_event) begin\n"))
  for case in cases {
    let (fixture, marker, expected_failure) = case
    let bundle = generate_async_fifo_formal_bundle(fixture)
    assert_eq(async_fifo_artifact(bundle, "design.lcir"), valid_ir)
    let rtl = bundle
      .artifacts()
      .filter(a => a.path().has_suffix(".sv") && a.path() != "formal-harness.sv")
    assert_eq(rtl, valid_rtl)
    let harness = async_fifo_artifact(bundle, "formal-harness.sv")
    assert_true(harness.contains(marker))
    let valid_lines = valid_harness.split("\n").to_array()
    let mutant_lines = harness.split("\n").to_array()
    assert_eq(mutant_lines.length(), valid_lines.length())
    let mut differing_lines = 0
    for index, line in valid_lines {
      if line != mutant_lines[index] {
        differing_lines = differing_lines + 1
      }
    }
    assert_eq(differing_lines, 1)
    assert_true(predicates.all(predicate => harness.contains(predicate)))
    assert_eq(bundle.tasks().length(), 1)
    assert_eq(bundle.tasks()[0].expected_status(), "fail")
    assert_false(bundle.expected_failure() == "none")
    let property_manifest = @formal_core.parse_formal_property_manifest(
      async_fifo_artifact(bundle, "properties.lcfp"),
    )
    let matching = property_manifest
      .properties()
      .filter(property => property.name() == expected_failure)
    assert_eq(matching.length(), 1)
    assert_eq(bundle.expected_failure(), matching[0].stable_name())
    assert_true(
      async_fifo_artifact(bundle, fixture.id() + "-bmc.lcfg").contains(
        "EXPECTED-FAILURE \{bundle.expected_failure()}\n",
      ),
    )
  }
}

///|
test "asynchronous FIFO registry rejects malformed and cross-family identities" {
  let malformed = [
    "LUNACHIP-PHASE5-FORMAL-SOURCE-SET 1\nFIXTURE valid-async-fifo\nEND\n", "LUNACHIP-PHASE5-FORMAL-SOURCE-SET 1\nFAMILY async-fifo\nFAMILY async-fifo\nFIXTURE valid-async-fifo\nEND\n",
    "LUNACHIP-PHASE5-FORMAL-SOURCE-SET 1\nFAMILY async-fifo\nEND\n", "LUNACHIP-PHASE5-FORMAL-SOURCE-SET 1\nFAMILY async-fifo\nFIXTURE valid-async-fifo\nFIXTURE valid-async-fifo\nEND\n",
    "LUNACHIP-PHASE5-FORMAL-SOURCE-SET 1\nFAMILY async-fifo\nFIXTURE valid-synchronizer\nEND\n",
    "LUNACHIP-PHASE5-FORMAL-SOURCE-SET 1\nFAMILY bit-synchronizer\nFIXTURE valid-async-fifo\nEND\n",
    "LUNACHIP-PHASE5-FORMAL-SOURCE-SET 1\nFAMILY async-fifo\nFIXTURE forged\nEND\n",
  ]
  for source_set in malformed {
    try regenerate_formal_artifacts(source_set) catch {
      _ => ()
    } noraise {
      _ => fail("malformed asynchronous-FIFO identity must fail")
    }
  }
}
