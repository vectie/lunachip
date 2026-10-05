///|
fn artifact_content(
  bundle : @formal.FifoFormalBundle,
  path : String,
) -> String raise {
  for artifact in bundle.artifacts() {
    if artifact.path == path {
      return artifact.content
    }
  }
  fail("missing artifact \{path}")
}

///|
test "valid FIFO bundle has isolated bounded, unbounded, and cover tasks" {
  let bundle = @formal.generate_fifo_bundle(ValidFifo)
  assert_eq(bundle.top_identifier(), "lc_formal_fifo_top")
  assert_eq(bundle.tasks().length(), 3)
  assert_eq(bundle.tasks()[0].task_class(), BoundedSafetyTask)
  assert_eq(bundle.tasks()[1].task_class(), UnboundedSafetyTask)
  assert_eq(bundle.tasks()[1].expected_status(), "pass")
  match bundle.tasks()[1].task() {
    Unbounded(task) => assert_eq(task.properties().length(), 4)
    _ => fail("expected unbounded structural proof task")
  }
  assert_eq(bundle.tasks()[2].task_class(), BoundedCoverTask)
  for task in bundle.tasks() {
    assert_eq(
      @formal_core.parse_proof_task(task.task().to_canonical_text()),
      task.task(),
    )
    match task.task() {
      Bounded(value) => {
        assert_true(value.assumptions().all(name => name.has_prefix("lc_p")))
        assert_true(value.properties().all(name => name.has_prefix("lc_p")))
      }
      Unbounded(value) => {
        assert_true(value.assumptions().all(name => name.has_prefix("lc_p")))
        assert_true(value.properties().all(name => name.has_prefix("lc_p")))
      }
    }
  }
  let harness = artifact_content(bundle, "formal-harness.sv")
  let source_set = artifact_content(bundle, "source-set.lcfs")
  assert_true(
    source_set.contains("ADDRESS-KNOWNNESS two-state-formal-all-binary\n"),
  )
  let prove_execution = artifact_content(bundle, "valid-fifo-prove.lcfg")
  assert_true(prove_execution.contains("SELECTED-PROPERTIES 4\n"))
  assert_true(
    prove_execution.contains("ADDRESS-KNOWNNESS two-state-formal-all-binary\n"),
  )
  assert_true(harness.contains("always @($global_clock)"))
  assert_false(harness.contains("lc_formal_timestep"))
  assert_true(harness.contains("lc_formal_cycle == 4'd0"))
  assert_true(harness.contains("? lc_reset : !lc_reset"))
  assert_true(harness.contains("lc_reference_memory"))
  assert_true(harness.contains("lc_expected_data"))
  assert_true(harness.contains(": assume ("))
  assert_true(harness.contains(": assert ("))
  assert_true(harness.contains(": cover ("))
  assert_false(harness.contains(" property (@"))
  assert_false(harness.contains("assign lc_reset = 1'b1"))
  assert_true(bundle.job_json().contains("\"mode\": \"bmc\""))
  assert_true(bundle.job_json().contains("\"mode\": \"prove\""))
  assert_true(bundle.job_json().contains("\"mode\": \"cover\""))
}

///|
test "negative FIFO and protocol fixtures are separate expected-fail bundles" {
  let broken_data = @formal.generate_fifo_bundle(BrokenFifoData)
  let broken_protocol = @formal.generate_fifo_bundle(BrokenResponseProtocol)
  assert_eq(broken_data.tasks().length(), 1)
  assert_eq(broken_protocol.tasks().length(), 1)
  assert_eq(broken_data.tasks()[0].expected_status(), "fail")
  assert_eq(broken_protocol.tasks()[0].expected_status(), "fail")
  assert_true(
    artifact_content(broken_data, "formal-harness.sv").contains(
      "lc_dut_response_data ^ 8'h01",
    ),
  )
  assert_true(
    artifact_content(broken_data, "formal-harness.sv").contains(
      "lc_negative_schedule_ok",
    ),
  )
  assert_true(
    artifact_content(broken_protocol, "formal-harness.sv").contains(
      "wire lc_checked_response_valid = ~lc_dut_response_valid",
    ),
  )
  assert_false(
    artifact_content(
      @formal.generate_fifo_bundle(ValidFifo),
      "formal-harness.sv",
    ).contains("lc_negative_schedule_ok"),
  )
}

///|
test "broken bounds fixture is isolated and expected to fail" {
  let bundle = @formal.generate_fifo_bundle(BrokenBounds)
  assert_eq(bundle.tasks().length(), 1)
  assert_eq(bundle.tasks()[0].expected_status(), "fail")
  assert_true(
    artifact_content(bundle, "formal-harness.sv").contains(
      "wire [1:0] lc_checked_occupancy = 2'b11",
    ),
  )
  let source_set = artifact_content(bundle, "source-set.lcfs")
  assert_true(source_set.contains("IR design.lcir sha256 "))
  assert_eq(artifact_content(bundle, "design.lcir").length() > 0, true)
}

///|
test "SBY mapping preserves bounded evidence and unbounded proof taxonomy" {
  let bundle = @formal.generate_fifo_bundle(ValidFifo)
  let bounded = @formal.map_sby_result(bundle.tasks()[0].task(), "PASS\n")
  match bounded.result() {
    BoundedResult(result) => assert_eq(result.outcome(), BoundedPass)
    _ => fail("expected bounded result")
  }
  let witness = @formal.SbyEvidence::checked(
    CoverWitnessTrace,
    "engine_0/trace.vcd",
    "cover trace",
  )
  let covered = @formal.map_sby_result(
    bundle.tasks()[2].task(),
    "PASS",
    evidence=witness,
  )
  match covered.result() {
    BoundedResult(result) =>
      match result.outcome() {
        CoverWitness(artifact) => {
          assert_eq(artifact.name(), "engine_0/trace.vcd")
          assert_eq(artifact.sha256().length(), 64)
        }
        _ => fail("expected cover witness")
      }
    _ => fail("expected bounded cover result")
  }
  let proved = @formal.map_sby_result(bundle.tasks()[1].task(), "PASS")
  match proved.result() {
    UnboundedResult(result) => assert_eq(result.outcome(), Proved)
    _ => fail("expected unbounded result")
  }
}

///|
test "failed safety requires and retains a counterexample hash" {
  let bundle = @formal.generate_fifo_bundle(BrokenFifoData)
  try @formal.map_sby_result(bundle.tasks()[0].task(), "FAIL") catch {
    MissingCounterexample(name) => assert_eq(name, "broken-fifo-data-bmc")
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected missing counterexample")
  }
  let failed = @formal.map_sby_result(
    bundle.tasks()[0].task(),
    "FAIL 0 1\n",
    evidence=@formal.SbyEvidence::checked(
      BaseCounterexampleTrace,
      "engine_0/trace.vcd",
      "counterexample",
    ),
  )
  match failed.result() {
    BoundedResult(result) =>
      match result.outcome() {
        SafetyCounterexample(artifact) => {
          assert_eq(artifact.name(), "engine_0/trace.vcd")
          assert_eq(artifact.sha256().length(), 64)
          assert_eq(
            @formal_core.parse_proof_result(result.to_canonical_text()),
            failed.result(),
          )
        }
        _ => fail("expected counterexample")
      }
    _ => fail("expected bounded failure")
  }
}

///|
test "unknown and tool-error statuses remain non-proof outcomes" {
  let bundle = @formal.generate_fifo_bundle(ValidFifo)
  match @formal.map_sby_result(bundle.tasks()[0].task(), "UNKNOWN").result() {
    BoundedResult(result) =>
      assert_eq(result.outcome(), BoundedInconclusive("SBY UNKNOWN"))
    _ => fail("expected bounded result")
  }
  match @formal.map_sby_result(bundle.tasks()[1].task(), "ERROR").result() {
    UnboundedResult(result) =>
      assert_eq(result.outcome(), UnboundedToolError("SBY ERROR"))
    _ => fail("expected unbounded result")
  }
}

///|
test "induction failure is inconclusive and retains a diagnostic hash" {
  let bundle = @formal.generate_fifo_bundle(ValidFifo)
  let mapped = @formal.map_sby_result(
    bundle.tasks()[1].task(),
    "FAIL",
    evidence=@formal.SbyEvidence::checked(
      InductionDiagnosticTrace,
      "engine_0/trace_induct.vcd",
      "unreachable induction trace",
    ),
  )
  match mapped.result() {
    UnboundedResult(result) =>
      assert_eq(
        result.outcome(),
        UnboundedInconclusive(
          "SBY induction-step failure; not a reachable counterexample",
        ),
      )
    _ => fail("expected unbounded result")
  }
  guard mapped.evidence() is Some(artifact) else {
    fail("expected retained induction diagnostic")
  }
  assert_eq(artifact.name(), "engine_0/trace_induct.vcd")
  assert_eq(artifact.sha256().length(), 64)
}
