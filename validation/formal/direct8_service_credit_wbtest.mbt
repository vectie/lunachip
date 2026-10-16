///|
fn direct8_service_credit_native(
  read : (String) -> UInt64 raise,
  arbiter : Direct8ArbiterNative,
) -> Unit raise {
  if read("i_reset") == 1UL {
    return
  }
  let yes = name => read(name) == 1UL
  let state = read("r_state")
  let ack = yes("e_response_accept")
  direct8_fair_require(
    !arbiter.active || (arbiter.age <= 4 && (ack || arbiter.age < 4)),
    "d8l_service_credit4",
  )
  for index in 0..<2 {
    let watch = arbiter.watches[index]
    if watch.active {
      let owned = read("r_owner") == index.to_uint64()
      let credit = if watch.granted {
        arbiter.active && owned && watch.age <= arbiter.age + 5
      } else if state == 0UL {
        yes("e_grant") &&
        read("e_choose_engine") == index.to_uint64() &&
        watch.age <= 5
      } else {
        arbiter.active && !owned && watch.age <= arbiter.age
      }
      direct8_fair_require(credit, "d8l_client_credit")
    }
  }
}

///|
test "service credit preserves inclusive ACK and rejects excess age and stolen regrant" {
  for mutation in 0..<4 {
    let arbiter = Direct8ArbiterNative::new()
    arbiter.active = mutation != 3
    arbiter.age = if mutation == 3 { 0 } else { 4 }
    let watch = arbiter.watches[0]
    watch.active = true
    watch.granted = mutation != 3
    watch.age = if mutation == 2 { 10 } else if mutation == 3 { 5 } else { 9 }
    let frame : Map[String, UInt64] = {
      "r_state": if mutation == 3 {
        0UL
      } else {
        2UL
      },
      "e_response_accept": if mutation == 1 {
        0UL
      } else {
        1UL
      },
      "e_grant": if mutation == 3 {
        1UL
      } else {
        0UL
      },
      "e_choose_engine": if mutation == 3 {
        1UL
      } else {
        0UL
      },
    }
    try
      direct8_service_credit_native(
        name => frame.get(name).unwrap_or(0UL),
        arbiter,
      )
    catch {
      BadFairEdge(label) =>
        assert_eq(
          label,
          if mutation == 1 {
            "d8l_service_credit4"
          } else {
            "d8l_client_credit"
          },
        )
      error => fail("unexpected credit failure: \{error}")
    } noraise {
      _ => assert_eq(mutation, 0)
    }
  }
}

///|
test "service credit profile retains the timed-out profile exactly and adds two conclusions" {
  let parent : Direct8CompletionBundle = {
    artifacts: direct8_progress_artifacts_from_id(direct8_latency_id).unwrap(),
  }
  for
    (path, digest) in [
      (
        "formal-dut.sv", "92627660c73df11ab7a7d0b031811aa9bd671afe3b8bc489929006777c575bb1",
      ),
      (
        "source-set.lcfs", "60033d1f5b789ea013b140cee44a409ae7b02432af9ff1d099322b2f94c1516d",
      ),
      (
        "properties.lcfp", "7943e86d813f8f63521f879414ba25b45676a573ed0ab77938970fa3d4a96644",
      ),
    ] {
    assert_eq(
      sha256_hex(direct8_completion_test_artifact(parent, path)),
      digest,
    )
  }
  let bundle : Direct8CompletionBundle = {
    artifacts: direct8_progress_artifacts_from_id(direct8_latency_credit_id).unwrap(),
  }
  let before = @formal_core.parse_formal_property_manifest(
    direct8_completion_test_artifact(parent, "properties.lcfp"),
  )
  let after = @formal_core.parse_formal_property_manifest(
    direct8_completion_test_artifact(bundle, "properties.lcfp"),
  )
  assert_eq(after.properties().length(), 62)
  for index, property in before.properties() {
    assert_eq(after.properties()[index], property)
  }
  let name = direct8_latency_credit_id + "-prove"
  guard @formal_core.parse_proof_task(
      direct8_completion_test_artifact(bundle, name + ".lcft"),
    )
    is Unbounded(task) else {
    fail("unbounded credit task required")
  }
  assert_eq((task.assumptions().length(), task.properties().length()), (7, 55))
  assert_eq(
    regenerate_formal_artifacts(
      direct8_completion_test_artifact(bundle, "source-set.lcfs"),
    ),
    bundle.artifacts,
  )
  let source = direct8_service_credit_source()
  assert_false(source.contains("assume"))
  assert_false(source.contains("anyseq"))
  for
    path in [
      "design.lcir", "names.lcnm", "formal-harness.sv", "arbiter-bindings.lcab",
    ] {
    assert_eq(
      direct8_completion_test_artifact(parent, path),
      direct8_completion_test_artifact(bundle, path),
    )
  }
}
