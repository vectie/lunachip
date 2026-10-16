///|
test "Done core profiles preserve older latency inputs and distinguish phase from latency selection" {
  let prior : Direct8CompletionBundle = {
    artifacts: direct8_progress_artifacts_from_id(direct8_latency_credit_id).unwrap(),
  }
  for
    (path, digest) in [
      (
        "formal-dut.sv", "f6540f7cc1e0ddce8c5c7ffc0d758794d3f8cddc78c56fc10716ab3a11e43067",
      ),
      (
        "source-set.lcfs", "32076aeeb5bb28e6693139b42b27de07220204f6e96f4ecf31ad75180c251de2",
      ),
      (
        "properties.lcfp", "e94f860b654149e02377fa6b8808a8685e202d9ca5299aed5ea741d7aa972c3a",
      ),
    ] {
    assert_eq(sha256_hex(direct8_completion_test_artifact(prior, path)), digest)
  }
  for
    (id, count, full) in [
      (direct8_done_core_id, 47, false),
      (direct8_latency_done_id, 56, true),
    ] {
    let bundle : Direct8CompletionBundle = {
      artifacts: direct8_progress_artifacts_from_id(id).unwrap(),
    }
    let parent : Direct8CompletionBundle = {
      artifacts: generate_direct8_arbiter_artifacts(
        engine_progress=true,
        owner_support=true,
        completed_prefix=true,
        latency=full,
        service_credit=full,
      ),
    }
    let before = @formal_core.parse_formal_property_manifest(
      direct8_completion_test_artifact(parent, "properties.lcfp"),
    )
    let after = @formal_core.parse_formal_property_manifest(
      direct8_completion_test_artifact(bundle, "properties.lcfp"),
    )
    assert_eq(after.properties().length(), count + 7)
    for index, property in before.properties() {
      assert_eq(after.properties()[index], property)
    }
    guard @formal_core.parse_proof_task(
        direct8_completion_test_artifact(bundle, id + "-prove.lcft"),
      )
      is Unbounded(task) else {
      fail("unbounded Done task required")
    }
    assert_eq(
      (task.assumptions().length(), task.properties().length()),
      (7, count),
    )
    assert_eq(task.induction(), @formal_core.InductionMethod::k_induction(32))
    assert_eq(
      after
      .properties()
      .iter()
      .any(item => {
        item.name() == "d8l_command_latency" &&
        task.properties().iter().any(label => label == item.stable_name())
      }),
      full,
    )
    assert_eq(
      regenerate_formal_artifacts(
        direct8_completion_test_artifact(bundle, "source-set.lcfs"),
      ),
      bundle.artifacts,
    )
    for
      path in [
        "design.lcir", "names.lcnm", "formal-harness.sv", "arbiter-bindings.lcab",
      ] {
      assert_eq(
        direct8_completion_test_artifact(parent, path),
        direct8_completion_test_artifact(bundle, path),
      )
    }
    let emitted = @rtl.emit_design(
      @ir.Design::single(
        "QueuedConcurrentDirect8CompletionPilot",
        direct8_arbiter_fixture().hardware(),
      ),
    )
    let clock = port_identifier(emitted, InputPort, "clock")
    let old_export = direct8_arbiter_property_export(
      clock,
      engine_progress=true,
      owner_support=true,
      completed_prefix=true,
      latency=full,
      service_credit=full,
    ).source()
    let new_export = direct8_arbiter_property_export(
      clock,
      engine_progress=true,
      owner_support=true,
      completed_prefix=true,
      latency=full,
      service_credit=full,
      done_core=true,
    ).source()
    let stripped = direct8_completion_test_artifact(bundle, "formal-dut.sv")
      .replace(old=direct8_done_core_source(), new="")
      .replace(old=new_export, new=old_export)
    assert_eq(
      if full {
        stripped
      } else {
        stripped.replace(old=direct8_latency_source(), new="")
      },
      direct8_completion_test_artifact(parent, "formal-dut.sv"),
    )
  }
  assert_false(direct8_done_core_source().contains("assume"))
  assert_false(direct8_done_core_source().contains("anyseq"))
}
