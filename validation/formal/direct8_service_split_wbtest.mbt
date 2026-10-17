///|
test "ownership and ACK credit selections partition the four additions without changing equations" {
  let joint : Direct8CompletionBundle = {
    artifacts: direct8_progress_artifacts_from_id(direct8_service_phase_id).unwrap(),
  }
  let baseline : Direct8CompletionBundle = {
    artifacts: direct8_progress_artifacts_from_id(direct8_done_slot_id).unwrap(),
  }
  let common = direct8_service_phase_selected(baseline, direct8_done_slot_id)
  let all = direct8_service_phase_selected(joint, direct8_service_phase_id)
  for
    (path, digest) in [
      (
        "formal-dut.sv", "1df998f73b9401ff115f62bc17d70ec56fc0f4dc3faad45077ad430b40d8d16e",
      ),
      (
        "source-set.lcfs", "2eddb5f89e58a2d03aed9ed9063966de59531106f2d567c00ba75f98f144edad",
      ),
      (
        "properties.lcfp", "0e2606e0f76997b85b2a57f0d011ba0b6512563b1d76d23ca3947c477834fc22",
      ),
    ] {
    assert_eq(sha256_hex(direct8_completion_test_artifact(joint, path)), digest)
  }
  let selections : Array[ReadOnlyArray[String]] = []
  for part in [Direct8ServicePart::Ownership, AckCredit] {
    let id = part.id()
    let bundle : Direct8CompletionBundle = {
      artifacts: direct8_progress_artifacts_from_id(id).unwrap(),
    }
    let selected = direct8_service_phase_selected(bundle, id)
    selections.push(selected)
    assert_eq(selected.length(), part.count())
    for name in common {
      assert_true(selected.contains(name))
    }
    for name in selected {
      assert_true(all.contains(name))
    }
    assert_eq(
      selected.filter(name => !common.contains(name)),
      if part == Ownership {
        ["d8l_client_phase"]
      } else {
        ["d8l_client_service11", "d8l_service_credit4", "d8l_client_credit"]
      },
    )
    guard @formal_core.parse_proof_task(
        direct8_completion_test_artifact(bundle, id + "-prove.lcft"),
      )
      is Unbounded(task) else {
      fail("unbounded component required")
    }
    guard @formal_core.parse_proof_task(
        direct8_completion_test_artifact(
          joint,
          direct8_service_phase_id + "-prove.lcft",
        ),
      )
      is Unbounded(parent) else {
      fail("joint task required")
    }
    assert_eq(task.assumptions(), parent.assumptions())
    assert_eq(task.induction(), parent.induction())
    for
      path in [
        "design.lcir", "names.lcnm", "formal-harness.sv", "arbiter-bindings.lcab",
      ] {
      assert_eq(
        direct8_completion_test_artifact(bundle, path),
        direct8_completion_test_artifact(joint, path),
      )
    }
    // Replace only selected assertion export, retaining every observer equation.
    let fixture = direct8_arbiter_fixture()
    let emitted = @rtl.emit_design(
      @ir.Design::single(
        "QueuedConcurrentDirect8CompletionPilot",
        fixture.hardware(),
      ),
    )
    let clock = port_identifier(emitted, InputPort, "clock")
    let export_for : (Direct8ServicePart) -> String raise = selected_part => {
      direct8_arbiter_property_export(
        clock,
        engine_progress=true,
        owner_support=true,
        completed_prefix=true,
        latency=true,
        service_credit=true,
        done_core=true,
        pending_slot=true,
        service_phase=true,
        service_part=selected_part,
      ).source()
    }
    let source = direct8_completion_test_artifact(bundle, "formal-dut.sv")
    let export_source = export_for(part)
    assert_eq(source.split(export_source).count(), 2)
    assert_eq(
      source.replace(old=export_source, new=export_for(Joint)),
      direct8_completion_test_artifact(joint, "formal-dut.sv"),
    )
    assert_eq(
      regenerate_formal_artifacts(
        direct8_completion_test_artifact(bundle, "source-set.lcfs"),
      ),
      bundle.artifacts,
    )
  }
  assert_eq(selections[0].filter(name => selections[1].contains(name)), common)
  for name in all {
    assert_true(selections[0].contains(name) || selections[1].contains(name))
  }
}
