///|
test "explicit arithmetic latency adds only the original assertion to accepted59" {
  let make : (Direct8ServicePart) -> Direct8CompletionBundle raise = part => {
    artifacts: direct8_progress_artifacts_from_id(part.id()).unwrap(),
  }
  let accepted = make(ArithmeticPotential)
  let original = make(FullLatency)
  let full = make(ArithmeticLatency)
  let text = direct8_completion_test_artifact
  for
    (path, digest) in [
      (
        "formal-dut.sv", "01e249425dcca9b1de441a8d5e4c6ab765b3127c552a25bc5be3b9b7ca669db9",
      ),
      (
        "source-set.lcfs", "12afbf8be9876bcd317a99c76927896ba4ce0dda3c15b9191df48a9f55420ac4",
      ),
      (
        "properties.lcfp", "ac97110e3c1c9340ab3b5f0c0cd8cf8d2f661f0b69ab23d932eaf55c265e0ea6",
      ),
    ] {
    assert_eq(sha256_hex(text(accepted, path)), digest)
  }
  for
    (path, digest) in [
      (
        "formal-dut.sv", "3beb93ae7062f4531476439593b20e146d77c3858d33df94bc66fff5ed8652c9",
      ),
      (
        "source-set.lcfs", "8a4652b6a1f14aba42a5287f0e6aaf4f944309468e87188d10706983a6a3385d",
      ),
      (
        "properties.lcfp", "b1279066204cd91eba353ad99a8a4625102e0d370fff2348a39627c91a9742e6",
      ),
    ] {
    assert_eq(sha256_hex(text(original, path)), digest)
  }
  let part = Direct8ServicePart::ArithmeticLatency
  let selected = direct8_service_phase_selected(full, part.id())
  let prior_names = direct8_service_phase_selected(
    accepted,
    ArithmeticPotential.id(),
  )
  assert_eq(selected.length(), 60)
  assert_eq(selected.filter(name => !prior_names.contains(name)), [
    "d8l_command_latency",
  ])
  assert_true(prior_names.all(name => selected.contains(name)))
  assert_eq(
    selected,
    direct8_service_phase_selected(original, FullLatency.id()),
  )
  assert_eq(text(full, "properties.lcfp"), text(original, "properties.lcfp"))
  guard @formal_core.parse_proof_task(text(full, part.id() + "-prove.lcft"))
    is Unbounded(task) else {
    fail("unbounded latency task")
  }
  guard @formal_core.parse_proof_task(
      text(accepted, ArithmeticPotential.id() + "-prove.lcft"),
    )
    is Unbounded(prior) else {
    fail("accepted59 task")
  }
  assert_eq(task.assumptions(), prior.assumptions())
  assert_eq(task.assumptions().length(), 7)
  assert_eq(task.induction(), prior.induction())
  assert_eq(task.properties().length(), 60)
  assert_true(text(full, "job.json").contains("\"timeout_seconds\": 600"))
  for artifact in accepted.artifacts {
    if artifact.path.has_prefix("production-") ||
      [
        "design.lcir", "names.lcnm", "formal-harness.sv", "arbiter-bindings.lcab",
        "arithmetic-helpers.lcah",
      ].contains(artifact.path) {
      assert_eq(text(full, artifact.path), artifact.content)
    }
  }
  let fixture = direct8_arbiter_fixture()
  let emitted = @rtl.emit_design(
    @ir.Design::single(
      "QueuedConcurrentDirect8CompletionPilot",
      fixture.hardware(),
    ),
  )
  let clock = port_identifier(emitted, InputPort, "clock")
  let exported : (Direct8ServicePart) -> String raise = selection => {
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
      service_part=selection,
    ).source()
  }
  let dut = text(full, "formal-dut.sv")
  assert_eq(dut.split(exported(part)).count(), 2)
  assert_eq(
    dut.replace(old=exported(part), new=exported(ArithmeticPotential)),
    text(accepted, "formal-dut.sv"),
  )
  let plans = direct8_arithmetic_helpers(
    fixture.hardware(),
    text(original, "formal-dut.sv"),
  )
  assert_eq(plans.length(), 13)
  let mut restored = dut
  for plan in plans {
    assert_eq(restored.split(plan.replacement).count(), 2)
    restored = restored.replace(old=plan.replacement, new=plan.original)
  }
  assert_eq(restored, text(original, "formal-dut.sv"))
  assert_eq(
    text(full, "arithmetic-helpers.lcah"),
    direct8_arithmetic_report(plans),
  )
  assert_eq(
    sha256_hex(text(full, "arithmetic-helpers.lcah")),
    "957730b66955a1ef05ae1ff9fa8e1abaea7e5459c7409b926101767aaa5d8d74",
  )
  assert_eq(
    regenerate_formal_artifacts(text(full, "source-set.lcfs")),
    full.artifacts,
  )
  assert_true(
    text(full, "source-set.lcfs").contains(
      "ENGINE-SCOPE local-progress-and-selected-whole-command-latency-conclusions-no-live-entry-ownership",
    ),
  )
}
