///|
test "payload profiles preserve accepted service inputs and add original metadata conclusions only" {
  let accepted_id = Direct8ServicePart::AckCredit.id()
  let accepted : Direct8CompletionBundle = {
    artifacts: direct8_progress_artifacts_from_id(accepted_id).unwrap(),
  }
  for
    (path, digest) in [
      (
        "formal-dut.sv", "51efd233aaf5c5cc2a08291bda27772d8d4c94250fb611cd6d1ebe9fe8e64761",
      ),
      (
        "source-set.lcfs", "840843a27494d8eaa11173494314ad6d26a615b1ad04861105e1b59ee0990a6e",
      ),
      (
        "properties.lcfp", "a941f44cf1121174ca11e57a25193b6c708cef510621f6dd47910cbb661232e8",
      ),
    ] {
    assert_eq(
      sha256_hex(direct8_completion_test_artifact(accepted, path)),
      digest,
    )
  }
  let fixture = direct8_arbiter_fixture()
  let owner : Direct8CompletionBundle = {
    artifacts: direct8_progress_artifacts_from_id(
      Direct8ServicePart::Ownership.id(),
    ).unwrap(),
  }
  for
    (path, digest) in [
      (
        "formal-dut.sv", "b56b3e547e9eb57fd93e7731401de4582fee40d70b3b34228bcb320e58f95e17",
      ),
      (
        "source-set.lcfs", "1d1ef7fba17f9d336f56f5249f83ae83517bb22d5d7a493f4bde2595c6bc8bc3",
      ),
      (
        "properties.lcfp", "3e0fb2f3122fc5165fae4a57ec7a0188b1df808116fb866df7ddd6a1baf02e15",
      ),
    ] {
    assert_eq(sha256_hex(direct8_completion_test_artifact(owner, path)), digest)
  }
  let bindings = direct8_payload_bindings(fixture)
  assert_eq(bindings.length(), 10)
  for index, binding in bindings {
    assert_false(bindings[:index].any(prior => prior.name == binding.name))
    let node = dependency_generation_node(fixture.hardware(), binding.node)
    assert_eq(node.signal_type(), binding.signal_type)
    assert_true(node.kind() is Register(_) || binding.name == "p_read_fault")
  }
  let emitted = @rtl.emit_design(
    @ir.Design::single(
      "QueuedConcurrentDirect8CompletionPilot",
      fixture.hardware(),
    ),
  )
  let clock = port_identifier(emitted, InputPort, "clock")
  let export_for : (Direct8ServicePart) -> String raise = part => {
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
      service_part=part,
    ).source()
  }
  let joint : Direct8CompletionBundle = {
    artifacts: direct8_progress_artifacts_from_id(direct8_service_phase_id).unwrap(),
  }
  for part in [Direct8ServicePart::Payload, JointPayload] {
    let id = part.id()
    let bundle : Direct8CompletionBundle = {
      artifacts: direct8_progress_artifacts_from_id(id).unwrap(),
    }
    let base_id = if part == Payload {
      direct8_done_slot_id
    } else {
      direct8_service_phase_id
    }
    let base : Direct8CompletionBundle = {
      artifacts: direct8_progress_artifacts_from_id(base_id).unwrap(),
    }
    let selected = direct8_service_phase_selected(bundle, id)
    let original = direct8_service_phase_selected(base, base_id)
    assert_eq(selected.length(), part.count())
    for name in original {
      assert_true(selected.contains(name))
    }
    assert_eq(
      selected.filter(name => !original.contains(name)),
      direct8_payload_property_names(),
    )
    assert_eq(selected.contains("d8l_client_phase"), part == JointPayload)
    guard @formal_core.parse_proof_task(
        direct8_completion_test_artifact(bundle, id + "-prove.lcft"),
      )
      is Unbounded(task) else {
      fail("unbounded payload task required")
    }
    guard @formal_core.parse_proof_task(
        direct8_completion_test_artifact(accepted, accepted_id + "-prove.lcft"),
      )
      is Unbounded(parent) else {
      fail("accepted service task required")
    }
    assert_eq(task.assumptions(), parent.assumptions())
    assert_eq(task.induction(), parent.induction())
    for path in ["design.lcir", "names.lcnm", "formal-harness.sv"] {
      assert_eq(
        direct8_completion_test_artifact(bundle, path),
        direct8_completion_test_artifact(accepted, path),
      )
    }
    let source = direct8_completion_test_artifact(bundle, "formal-dut.sv")
    let controls = direct8_arbiter_bindings([], emitted).0
    let declarations = direct8_arbiter_bindings(
        ReadOnlyArray::from_array(bindings),
        emitted,
      ).0
    assert_true(declarations.has_prefix(controls))
    let extra = declarations[controls.length():].to_owned()
    for addition in [extra, direct8_payload_source(), export_for(part)] {
      assert_eq(source.split(addition).count(), 2)
    }
    assert_eq(
      source
      .replace(old=extra, new="")
      .replace(old=direct8_payload_source(), new="")
      .replace(old=export_for(part), new=export_for(Joint)),
      direct8_completion_test_artifact(joint, "formal-dut.sv"),
    )
    assert_eq(
      regenerate_formal_artifacts(
        direct8_completion_test_artifact(bundle, "source-set.lcfs"),
      ),
      bundle.artifacts,
    )
  }
  assert_false(direct8_payload_source().contains("assume"))
  assert_false(direct8_payload_source().contains("anyseq"))
}
