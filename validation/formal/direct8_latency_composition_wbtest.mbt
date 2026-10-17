///|
test "age and latency composition selects exact original groups with accepted payload support" {
  let parent_id = Direct8ServicePart::JointPayload.id()
  let parent : Direct8CompletionBundle = {
    artifacts: direct8_progress_artifacts_from_id(parent_id).unwrap(),
  }
  for
    (path, digest) in [
      (
        "formal-dut.sv", "ae94910f5b22f163ece206a83de6b949b9ff3e37d0c27ada71551639d733541f",
      ),
      (
        "source-set.lcfs", "665bb70c840573660b054a842847264bff051f16c2f63349a4c7d6f47e8aac76",
      ),
      (
        "properties.lcfp", "db36a98dace14a2358056faf4b157a2f36be1a38fe6d3d23a40d8934e6f2b13d",
      ),
    ] {
    assert_eq(
      sha256_hex(direct8_completion_test_artifact(parent, path)),
      digest,
    )
  }
  let full : Direct8CompletionBundle = {
    artifacts: direct8_progress_artifacts_from_id(direct8_latency_done_slot_id).unwrap(),
  }
  let original = direct8_service_phase_selected(
    full, direct8_latency_done_slot_id,
  )
  let accepted = direct8_service_phase_selected(parent, parent_id)
  let emitted = @rtl.emit_design(
    @ir.Design::single(
      "QueuedConcurrentDirect8CompletionPilot",
      direct8_arbiter_fixture().hardware(),
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
  guard @formal_core.parse_proof_task(
      direct8_completion_test_artifact(parent, parent_id + "-prove.lcft"),
    )
    is Unbounded(prior) else {
    fail("accepted proof required")
  }
  for part in [Direct8ServicePart::AgePotential, FullLatency] {
    let id = part.id()
    let bundle : Direct8CompletionBundle = {
      artifacts: direct8_progress_artifacts_from_id(id).unwrap(),
    }
    let names = direct8_service_phase_selected(bundle, id)
    assert_eq(names.length(), part.count())
    for name in accepted {
      assert_true(names.contains(name))
    }
    let extra = names.filter(name => !accepted.contains(name))
    assert_eq(
      extra,
      if part == FullLatency {
        [
          "d8l_potential_bounds", "d8l_potential_step", "d8l_age_history", "d8l_age_potential",
          "d8l_command_latency",
        ]
      } else {
        [
          "d8l_potential_bounds", "d8l_potential_step", "d8l_age_history", "d8l_age_potential",
        ]
      },
    )
    if part == FullLatency {
      for name in original {
        assert_true(names.contains(name))
      }
      assert_eq(
        names.filter(name => !original.contains(name)),
        direct8_payload_property_names(),
      )
    }
    guard @formal_core.parse_proof_task(
        direct8_completion_test_artifact(bundle, id + "-prove.lcft"),
      )
      is Unbounded(task) else {
      fail("unbounded composition required")
    }
    assert_eq(task.assumptions(), prior.assumptions())
    assert_eq(task.induction(), prior.induction())
    assert_eq(task.properties().length(), part.count())
    let job = direct8_completion_test_artifact(bundle, "job.json")
    assert_true(job.contains("\"timeout_seconds\": 600"))
    for
      path in [
        "design.lcir", "names.lcnm", "formal-harness.sv", "arbiter-bindings.lcab",
      ] {
      assert_eq(
        direct8_completion_test_artifact(bundle, path),
        direct8_completion_test_artifact(parent, path),
      )
    }
    let dut = direct8_completion_test_artifact(bundle, "formal-dut.sv")
    assert_eq(dut.split(export_for(part)).count(), 2)
    assert_eq(
      dut.replace(old=export_for(part), new=export_for(JointPayload)),
      direct8_completion_test_artifact(parent, "formal-dut.sv"),
    )
    assert_eq(
      regenerate_formal_artifacts(
        direct8_completion_test_artifact(bundle, "source-set.lcfs"),
      ),
      bundle.artifacts,
    )
    assert_true(
      direct8_completion_test_artifact(bundle, "source-set.lcfs").contains(
        part.scope(),
      ),
    )
  }
}

///|
test "command age resets and inclusive deadlines reject saturated and stalled observers" {
  // Abstract observer boundaries, not reachable traces or formal witnesses.
  for (engine, done, bound) in [(0, 4UL, 1666), (1, 3UL, 99), (2, 4UL, 898)] {
    let frame : Map[String, UInt64] = Map([])
    let read : (String) -> UInt64 raise = name => frame.get(name).unwrap_or(0UL)
    let observer = Direct8LatencyNative::new()
    observer.active[engine] = true
    observer.ages[engine] = 2047
    observer.previous[engine] = Some(1)
    frame["i_reset"] = 1UL
    observer.step(read, Direct8ArbiterNative::new().watches)
    assert_false(observer.active[engine])
    assert_eq((observer.ages[engine], observer.previous[engine]), (0, None))
    frame["i_reset"] = 0UL
    observer.observe(read, [0, 0, 0])
    for
      (age, rank, terminal, expected) in [
        (bound, 0, true, ""),
        (bound, 1, false, "d8l_age_potential"),
        (bound + 1, 0, true, "d8l_age_potential"),
        (2047, 0, true, "d8l_age_potential"),
        (1, 1, false, "d8l_potential_step"),
      ] {
      let check = Direct8LatencyNative::new()
      check.active[engine] = true
      check.ages[engine] = age
      let ranks = [0, 0, 0]
      ranks[engine] = rank
      frame["q_engine_state_\{engine}"] = if terminal { done } else { 1UL }
      if expected == "d8l_potential_step" {
        check.previous[engine] = Some(rank)
      }
      try check.observe(read, ranks) catch {
        BadFairEdge(label) => assert_eq(label, expected)
        error => fail("unexpected age boundary failure: \{error}")
      } noraise {
        _ => assert_eq(expected, "")
      }
    }
  }
  let source = direct8_latency_source()
  assert_true(source.contains("lc_l_age_0 < 11'd2047"))
  assert_true(source.contains("lc_l_age_0 <= 11'd1;"))
  assert_false(source.contains("assume"))
  assert_false(source.contains("anyseq"))
}
