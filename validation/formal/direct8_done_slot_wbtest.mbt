///|
fn direct8_done_slot_native(read : (String) -> UInt64 raise) -> Unit raise {
  if read("i_reset") == 0UL && read("o_pending") == 1UL {
    direct8_fair_require(
      read("d_response_slot") == read("o_store_slot"),
      "d8d_pending_slot",
    )
  }
}

///|
test "pending result selector is original and typed and its extra conclusion preserves the first Done task" {
  let fixture = direct8_arbiter_fixture()
  let binding = direct8_done_slot_binding(fixture)
  assert_eq(binding.signal_type, @wire.uint(1))
  assert_true(
    dependency_generation_node(fixture.hardware(), binding.node).kind()
    is Register(_),
  )
  for slot in 0..<=1 {
    let frame : Map[String, UInt64] = {
      "o_pending": 1UL,
      "o_store_slot": slot.to_uint64(),
      "d_response_slot": slot.to_uint64(),
    }
    let read : (String) -> UInt64 raise = name => frame.get(name).unwrap_or(0UL)
    direct8_done_slot_native(read)
    frame["d_response_slot"] = 1UL - slot.to_uint64()
    try direct8_done_slot_native(read) catch {
      BadFairEdge(label) => assert_eq(label, "d8d_pending_slot")
      error => fail("unexpected pending snapshot failure: \{error}")
    } noraise {
      _ => fail("pending snapshot cannot refer to another slot")
    }
  }
  let prior : Direct8CompletionBundle = {
    artifacts: direct8_progress_artifacts_from_id(direct8_done_core_id).unwrap(),
  }
  for
    (path, digest) in [
      (
        "formal-dut.sv", "8f2556cb2afe1a5c805c41a43355572b3e197caff65f522bc54d9fd42c0fd19b",
      ),
      (
        "source-set.lcfs", "0d9b93fad7ca90b429fe863adfe0567f9d7fb7df7dc13ccd2101c5e367245a1c",
      ),
      (
        "properties.lcfp", "666370486f7746307ec073e0ac16237314ec974f39f7d8be6734453b92870547",
      ),
    ] {
    assert_eq(sha256_hex(direct8_completion_test_artifact(prior, path)), digest)
  }
  for
    (id, count) in [
      (direct8_done_slot_id, 48),
      (direct8_latency_done_slot_id, 57),
    ] {
    let bundle : Direct8CompletionBundle = {
      artifacts: direct8_progress_artifacts_from_id(id).unwrap(),
    }
    guard @formal_core.parse_proof_task(
        direct8_completion_test_artifact(bundle, id + "-prove.lcft"),
      )
      is Unbounded(task) else {
      fail("unbounded pending slot task required")
    }
    assert_eq(
      (task.assumptions().length(), task.properties().length()),
      (7, count),
    )
    if id == direct8_done_slot_id {
      let parent : Direct8CompletionBundle = {
        artifacts: direct8_progress_artifacts_from_id(direct8_engine_prefix_id).unwrap(),
      }
      guard @formal_core.parse_proof_task(
          direct8_completion_test_artifact(
            parent,
            direct8_engine_prefix_id + "-prove.lcft",
          ),
        )
        is Unbounded(accepted) else {
        fail("accepted engine prefix task required")
      }
      assert_eq(accepted.properties().length(), 44)
      assert_eq(task.assumptions(), accepted.assumptions())
      for label in accepted.properties() {
        assert_true(task.properties().contains(label))
      }
      let properties = @formal_core.parse_formal_property_manifest(
        direct8_completion_test_artifact(bundle, "properties.lcfp"),
      ).properties()
      let extra = properties
        .filter(property => {
          task.properties().contains(property.stable_name()) &&
          !accepted.properties().contains(property.stable_name())
        })
        .map(property => property.name())
      assert_eq(extra, [
        "d8l_phase_link", "d8l_issue_progress", "d8d_done_core", "d8d_pending_slot",
      ])
      for
        (path, digest) in [
          (
            "formal-dut.sv", "62d831f5960c33677444c3352138aa869dfd0458339b17d64e0a9de231f81304",
          ),
          (
            "source-set.lcfs", "387673527f12298e5ea79e4bc1a8a56f4516adeb7bea8f340ac416777fbbf37a",
          ),
          (
            "properties.lcfp", "0c426d7ecec636bc0be5fcda83dee28e8bdf9a0041e365c7e9086b073d08c59f",
          ),
        ] {
        assert_eq(
          sha256_hex(direct8_completion_test_artifact(bundle, path)),
          digest,
        )
      }
    }
    assert_eq(
      regenerate_formal_artifacts(
        direct8_completion_test_artifact(bundle, "source-set.lcfs"),
      ),
      bundle.artifacts,
    )
    for path in ["design.lcir", "names.lcnm", "formal-harness.sv"] {
      assert_eq(
        direct8_completion_test_artifact(bundle, path),
        direct8_completion_test_artifact(prior, path),
      )
    }
  }
  assert_false(direct8_done_slot_source().contains("assume"))
  assert_false(direct8_done_slot_source().contains("anyseq"))
}
