///|
test "latency profile preserves the accepted engine bundle and selects nine new conclusions" {
  let parent : Direct8CompletionBundle = {
    artifacts: generate_direct8_arbiter_artifacts(
      engine_progress=true,
      owner_support=true,
      completed_prefix=true,
    ),
  }
  for
    (path, expected) in [
      (
        "formal-dut.sv", "850e6fb39724e77d255029f11b08bff7d1e38fc145045a0fb576d912bb996d37",
      ),
      (
        "source-set.lcfs", "09494d7a6ce40a3166b20d7eaa98087156a4a87795d2836a97a21361cfba3d07",
      ),
      (
        "properties.lcfp", "767a7f7d995e78d46b867649c2b5f4e6c1038dc342750972dc69a1c7042354ab",
      ),
    ] {
    assert_eq(
      sha256_hex(direct8_completion_test_artifact(parent, path)),
      expected,
    )
  }
  let bundle : Direct8CompletionBundle = {
    artifacts: direct8_progress_artifacts_from_id(direct8_latency_id).unwrap(),
  }
  let before = @formal_core.parse_formal_property_manifest(
    direct8_completion_test_artifact(parent, "properties.lcfp"),
  )
  let after = @formal_core.parse_formal_property_manifest(
    direct8_completion_test_artifact(bundle, "properties.lcfp"),
  )
  assert_eq(after.properties().length(), 60)
  for index, property in before.properties() {
    assert_eq(after.properties()[index], property)
  }
  let name = direct8_latency_id + "-prove"
  guard @formal_core.parse_proof_task(
      direct8_completion_test_artifact(bundle, name + ".lcft"),
    )
    is Unbounded(task) else {
    fail("unbounded latency task required")
  }
  assert_eq((task.assumptions().length(), task.properties().length()), (7, 53))
  assert_eq(task.induction(), @formal_core.InductionMethod::k_induction(32))
  assert_eq(
    regenerate_formal_artifacts(
      direct8_completion_test_artifact(bundle, "source-set.lcfs"),
    ),
    bundle.artifacts,
  )
  for artifact in parent.artifacts {
    if artifact.path == "design.lcir" ||
      artifact.path == "names.lcnm" ||
      artifact.path == "formal-harness.sv" ||
      artifact.path.has_prefix("production") ||
      artifact.path == "arbiter-bindings.lcab" {
      assert_eq(
        direct8_completion_test_artifact(bundle, artifact.path),
        artifact.content,
      )
    }
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
  ).source()
  let new_export = direct8_arbiter_property_export(
    clock,
    engine_progress=true,
    owner_support=true,
    completed_prefix=true,
    latency=true,
  ).source()
  assert_eq(
    direct8_completion_test_artifact(bundle, "formal-dut.sv")
    .replace(old=direct8_latency_source(), new="")
    .replace(old=new_export, new=old_export),
    direct8_completion_test_artifact(parent, "formal-dut.sv"),
  )
  let source = direct8_latency_source()
  assert_false(source.contains("assume"))
  assert_false(source.contains("anyseq"))
  assert_true(source.contains("{19'd0,lc_g_t_reader_row}"))
  assert_true(source.contains("11'd1666"))
  assert_true(source.contains("11'd898"))
  assert_true(source.contains("11'd99"))
}

///|
test "fixed-stride potentials decrease for every legal transfer rectangle including row wraps" {
  for
    (row_limit, column_limit, stride, capacity, unit) in [
      (8, 16, 16, 128, 13),
      (16, 8, 8, 128, 13),
      (8, 8, 8, 64, 14),
    ] {
    for rows in 1..<=row_limit {
      for columns in 1..<=column_limit {
        for row in 0..<rows {
          for column in 0..<columns {
            let ordinal = row * stride + column
            assert_true(ordinal < capacity)
            let next = if column + 1 == columns {
              (row + 1) * stride
            } else {
              ordinal + 1
            }
            assert_true(next >= ordinal + 1)
            for age in 0..<=11 {
              let bus = unit * (capacity - ordinal) -
                (if unit == 14 { 1 } else { 0 }) -
                age
              let after_ack = if unit == 13 {
                unit * (capacity - ordinal - 1) + 1
              } else if row + 1 == rows && column + 1 == columns {
                0
              } else {
                unit * (capacity - next)
              }
              assert_true(bus >= after_ack + 1)
            }
          }
        }
      }
    }
  }
}
