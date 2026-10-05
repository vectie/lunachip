///|
test "generation support has one exact additive identity and leaves the four standard fixtures unchanged" {
  let fixture : @formal.DependencyFormalFixture = LatestWriterGenerationSupport
  assert_eq(fixture.id(), "phase6-dependency-generation-support")
  assert_eq(
    @formal.DependencyFormalFixture::from_id(fixture.id()),
    Some(fixture),
  )
  assert_eq(
    @formal.DependencyFormalFixture::from_id("dependency-generation-support"),
    None,
  )
  let standard = @formal.standard_dependency_formal_bundles()
  assert_eq(standard.map(bundle => bundle.fixture()), [
    LatestWriter,
    NegativeFailedGeneration,
    NegativeNewIntentPriority,
    NegativeInnerIdentity,
  ])
  for bundle in standard {
    let source_set = dependency_formal_artifact(bundle, "source-set.lcfs")
    assert_false(source_set.contains("SUPPORT "))
    assert_false(
      dependency_formal_artifact(bundle, "formal-harness.sv").contains(
        "lc_generation_all_boundary_matches_reference",
      ),
    )
    assert_eq(
      @formal.regenerate_formal_artifacts(source_set),
      bundle.artifacts(),
    )
  }
}

///|
test "generation support appends p16 and only an all-boundary raw eighteen-field assertion" {
  let baseline = @formal.generate_dependency_formal_bundle(LatestWriter)
  let support = @formal.generate_dependency_formal_bundle(
    LatestWriterGenerationSupport,
  )
  let baseline_properties = @formal_core.parse_formal_property_manifest(
    dependency_formal_artifact(baseline, "properties.lcfp"),
  )
  let support_properties = @formal_core.parse_formal_property_manifest(
    dependency_formal_artifact(support, "properties.lcfp"),
  )
  assert_eq(baseline_properties.properties().length(), 16)
  assert_eq(support_properties.properties().length(), 17)
  for ordinal in 0..<16 {
    assert_eq(
      support_properties.properties()[ordinal],
      baseline_properties.properties()[ordinal],
    )
  }
  let added = support_properties.properties()[16]
  assert_eq(added.id().ordinal(), 16)
  assert_eq(added.name(), "generation_all_boundary_matches_reference")
  assert_eq(added.kind(), Assertion)
  assert_eq(added.disable(), NeverDisabled)
  assert_eq(added.domain(), baseline_properties.properties()[4].domain())
  assert_true(added.stable_name().has_prefix("lc_p16_"))
  let relation =
    #|  wire lc_generation_all_boundary_matches_reference = lc_reset
    #|    || (lc_o_next_ticket == lc_g_next
    #|      && lc_o_head_ticket == lc_g_head
    #|      && lc_o_writer_status_0 == lc_g_status[0]
    #|      && lc_o_writer_ticket_0 == lc_g_ticket[0]
    #|      && lc_o_writer_status_1 == lc_g_status[1]
    #|      && lc_o_writer_ticket_1 == lc_g_ticket[1]
    #|      && lc_o_writer_status_2 == lc_g_status[2]
    #|      && lc_o_writer_ticket_2 == lc_g_ticket[2]
    #|      && lc_o_writer_status_3 == lc_g_status[3]
    #|      && lc_o_writer_ticket_3 == lc_g_ticket[3]
    #|      && lc_o_writer_status_4 == lc_g_status[4]
    #|      && lc_o_writer_ticket_4 == lc_g_ticket[4]
    #|      && lc_o_writer_status_5 == lc_g_status[5]
    #|      && lc_o_writer_ticket_5 == lc_g_ticket[5]
    #|      && lc_o_dependency_status_0 == lc_g_snapshot_status[0]
    #|      && lc_o_dependency_ticket_0 == lc_g_snapshot_ticket[0]
    #|      && lc_o_dependency_status_1 == lc_g_snapshot_status[1]
    #|      && lc_o_dependency_ticket_1 == lc_g_snapshot_ticket[1]);
    #|
  let assertion = "  always @(posedge lc_clock) begin\n    \{added.stable_name()}: assert ((lc_generation_all_boundary_matches_reference) === 1'b1);\n  end\n"
  let harness = dependency_formal_artifact(support, "formal-harness.sv")
  assert_eq(harness.split(relation).length(), 2)
  assert_eq(harness.split(assertion).length(), 2)
  assert_eq(harness.split(": assume (").length(), 5)
  assert_eq(harness.split(": assert (").length(), 9)
  assert_eq(harness.split(": cover (").length(), 6)
  // Removing only the additive predicate and p16 yields the entire old source,
  // including its original assumptions, seven assertions, covers and ghost.
  assert_eq(
    harness.replace(old=relation, new="").replace(old=assertion, new=""),
    dependency_formal_artifact(baseline, "formal-harness.sv"),
  )
  for artifact in baseline.artifacts() {
    if artifact.path() == "design.lcir" ||
      (
        artifact.path().has_suffix(".sv") &&
        artifact.path() != "formal-harness.sv"
      ) {
      assert_eq(
        dependency_formal_artifact(support, artifact.path()),
        artifact.content(),
      )
    }
  }
  let source_set = dependency_formal_artifact(support, "source-set.lcfs")
  assert_true(source_set.contains("MUTATION none\n"))
  assert_eq(
    source_set
    .split(
      "SUPPORT all-boundary-18-field-generation-relation-assertion-not-assumption\n",
    )
    .length(),
    2,
  )
  assert_true(
    source_set.contains(
      "COVERS require-all-five-actual-witnesses-no-vacuous-pass\n",
    ),
  )
}

///|
test "generation support selects all eight assertions with unchanged timing assumptions and bounded result contract" {
  let support = @formal.generate_dependency_formal_bundle(
    LatestWriterGenerationSupport,
  )
  let properties = @formal_core.parse_formal_property_manifest(
    dependency_formal_artifact(support, "properties.lcfp"),
  )
  assert_eq(support.tasks().length(), 1)
  assert_eq(support.expected_failure(), "none")
  let gate = support.tasks()[0]
  assert_eq(gate.name(), "phase6-dependency-generation-support-bmc")
  assert_eq(gate.task_class(), BoundedSafetyTask)
  assert_eq(gate.expected_status(), "pass")
  assert_eq(gate.bound(), 256)
  assert_eq(gate.timeout_seconds(), 600)
  guard gate.task() is Bounded(task) else {
    fail("support fixture must remain BMC only")
  }
  assert_eq(task.mode(), BoundedSafety)
  // Proof-task names are canonical lexicographic order; the property manifest
  // remains numeric identity order. Compare exact membership, not those orders.
  let assertions = properties
    .properties()
    .filter(item => item.kind() is Assertion)
    .map(item => item.stable_name())
  assert_eq(task.properties().length(), assertions.length())
  assert_true(task.properties().all(name => assertions.contains(name)))
  assert_eq(task.properties().length(), 8)
  assert_eq(
    task.assumptions(),
    properties
    .properties()
    .filter(item => item.kind() is Assumption)
    .map(item => item.stable_name()),
  )
  assert_eq(task.assumptions().length(), 4)
  assert_eq(
    properties.properties().filter(item => item.kind() is Cover).length(),
    5,
  )
  guard task.timing_contract() is Some(timing) else {
    fail("missing support timing contract")
  }
  assert_eq(timing.global_timestep().steps(), 2)
  assert_eq(timing.clocks().length(), 1)
  assert_eq(timing.legal_transition_assumptions().length(), 4)
  assert_eq(timing.fairness_assumptions().length(), 0)
  assert_eq(
    @formal_core.parse_proof_task(gate.task().to_canonical_text()),
    gate.task(),
  )
  @formal.verify_task_property_binding(gate.task(), properties)
  let execution = dependency_formal_artifact(support, gate.name() + ".lcfg")
  assert_true(execution.contains("SELECTED-ASSUMPTIONS 4\n"))
  assert_true(execution.contains("SELECTED-PROPERTIES 8\n"))
  assert_true(
    execution.contains("BOUND-MAPPING 256-global-steps-128-dut-clocks\n"),
  )
  assert_true(execution.contains("EXPECTED-FAILURE none\n"))
  assert_false(support.job_json().contains("\"mode\": \"cover\""))
  let source_set = dependency_formal_artifact(support, "source-set.lcfs")
  assert_eq(
    @formal.regenerate_formal_artifacts(source_set),
    support.artifacts(),
  )
  assert_eq(
    @formal.generate_dependency_formal_bundle(LatestWriterGenerationSupport),
    support,
  )
  // Synthetic classification only: no engine execution or proof claim here.
  match @formal.map_sby_result(gate.task(), "PASS").result() {
    BoundedResult(value) => assert_eq(value.outcome(), BoundedPass)
    _ => fail("support BMC cannot become an unbounded proof")
  }
}
