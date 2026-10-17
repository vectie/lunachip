///|
fn direct8_service_phase_selected(
  bundle : Direct8CompletionBundle,
  id : String,
) -> ReadOnlyArray[String] raise {
  guard @formal_core.parse_proof_task(
      direct8_completion_test_artifact(bundle, id + "-prove.lcft"),
    )
    is Unbounded(task) else {
    fail("unbounded component task required")
  }
  @formal_core.parse_formal_property_manifest(
    direct8_completion_test_artifact(bundle, "properties.lcfp"),
  )
  .properties()
  .filter(property => task.properties().contains(property.stable_name()))
  .map(property => property.name())
}

///|
test "service phase selects accepted48 plus four service conclusions and preserves full57 inputs" {
  let bundle : Direct8CompletionBundle = {
    artifacts: direct8_progress_artifacts_from_id(direct8_service_phase_id).unwrap(),
  }
  let selected = direct8_service_phase_selected(
    bundle, direct8_service_phase_id,
  )
  assert_eq(selected.length(), 52)
  for
    (id, full) in [
      (direct8_done_slot_id, false),
      (direct8_latency_done_slot_id, true),
    ] {
    let prior : Direct8CompletionBundle = {
      artifacts: direct8_progress_artifacts_from_id(id).unwrap(),
    }
    let names = direct8_service_phase_selected(prior, id)
    for name in (if full { selected } else { names }) {
      assert_true((if full { names } else { selected }).contains(name))
    }
    let difference = (if full { names } else { selected }).filter(name => {
      !(if full { selected } else { names }).contains(name)
    })
    assert_eq(
      difference,
      if full {
        [
          "d8l_potential_bounds", "d8l_potential_step", "d8l_age_history", "d8l_age_potential",
          "d8l_command_latency",
        ]
      } else {
        [
          "d8l_client_phase", "d8l_client_service11", "d8l_service_credit4", "d8l_client_credit",
        ]
      },
    )
    for
      (path, digest) in (if full {
        [
          (
            "formal-dut.sv", "045c9fa8e059502a205ffdbe27751593afe01da76e8c64204b683de7d418a64a",
          ),
          (
            "source-set.lcfs", "c5c81201bca7fa16249bc77f455eaaadaf67041a2da94b1f5d6df6ae1eee7345",
          ),
          (
            "properties.lcfp", "344f0f869c3a34a0f64859b93ffd52675f485b93c669c628e7926fbc5d0f36cf",
          ),
        ]
      } else {
        [
          (
            "formal-dut.sv", "62d831f5960c33677444c3352138aa869dfd0458339b17d64e0a9de231f81304",
          ),
          (
            "source-set.lcfs", "387673527f12298e5ea79e4bc1a8a56f4516adeb7bea8f340ac416777fbbf37a",
          ),
          (
            "properties.lcfp", "0c426d7ecec636bc0be5fcda83dee28e8bdf9a0041e365c7e9086b073d08c59f",
          ),
        ]
      }) {
      assert_eq(
        sha256_hex(direct8_completion_test_artifact(prior, path)),
        digest,
      )
    }
    guard @formal_core.parse_proof_task(
        direct8_completion_test_artifact(prior, id + "-prove.lcft"),
      )
      is Unbounded(parent) else {
      fail("parent proof required")
    }
    guard @formal_core.parse_proof_task(
        direct8_completion_test_artifact(
          bundle,
          direct8_service_phase_id + "-prove.lcft",
        ),
      )
      is Unbounded(task) else {
      fail("service phase proof required")
    }
    assert_eq(task.assumptions(), parent.assumptions())
    assert_eq(task.induction(), parent.induction())
    for
      path in [
        "design.lcir", "names.lcnm", "formal-harness.sv", "arbiter-bindings.lcab",
      ] {
      assert_eq(
        direct8_completion_test_artifact(bundle, path),
        direct8_completion_test_artifact(prior, path),
      )
    }
  }
  assert_eq(
    regenerate_formal_artifacts(
      direct8_completion_test_artifact(bundle, "source-set.lcfs"),
    ),
    bundle.artifacts,
  )
}

///|
test "service carry checks waiting idle and granted ages for both clients" {
  // Exhaustive observer boundary checks, not reachable-device witnesses.
  for index in 0..<2 {
    for phase in 0..<3 {
      for age in 1..<=4 {
        let arbiter = Direct8ArbiterNative::new()
        arbiter.active = phase != 1
        arbiter.age = if phase == 1 { 0 } else { age }
        let watch = arbiter.watches[index]
        watch.active = true
        watch.granted = phase == 2
        watch.age = if phase == 1 {
          5
        } else if phase == 2 {
          age + 5
        } else {
          age
        }
        let frame : Map[String, UInt64] = {
          "r_state": if phase == 1 {
            0UL
          } else {
            2UL
          },
          "r_owner": (if phase == 2 { index } else { 1 - index }).to_uint64(),
          "e_response_accept": if age == 4 {
            1UL
          } else {
            0UL
          },
          "e_grant": if phase == 1 {
            1UL
          } else {
            0UL
          },
          "e_choose_engine": index.to_uint64(),
        }
        let read : (String) -> UInt64 raise = name => {
          frame.get(name).unwrap_or(0UL)
        }
        direct8_service_credit_native(read, arbiter)
        assert_true(watch.age <= 9 && watch.age < 11)
        watch.age += 1
        try direct8_service_credit_native(read, arbiter) catch {
          BadFairEdge(label) => assert_eq(label, "d8l_client_credit")
          error => fail("unexpected excess credit failure: \{error}")
        } noraise {
          _ => fail("excess waiting/idle/granted credit must fail")
        }
      }
    }
  }
}

///|
test "all command bounds compose acceptance age and inclusive Done without wrap" {
  // Independent age/rank algebra; actual DUT trajectories remain separate.
  for (engine, done, bound) in [(0, 4UL, 1666), (1, 3UL, 99), (2, 4UL, 898)] {
    let observer = Direct8LatencyNative::new()
    let frame : Map[String, UInt64] = Map([("q_engine_accept_\{engine}", 1UL)])
    let read : (String) -> UInt64 raise = name => frame.get(name).unwrap_or(0UL)
    observer.observe(read, [0, 0, 0])
    frame["q_engine_accept_\{engine}"] = 0UL
    frame["q_engine_state_\{engine}"] = 1UL
    let ranks = [0, 0, 0]
    ranks[engine] = bound - 1
    observer.observe(read, ranks)
    assert_eq(observer.ages[engine], 2)
    frame["q_engine_state_\{engine}"] = done
    ranks[engine] = 0
    observer.observe(read, ranks)
    assert_false(observer.active[engine])
    for mutation in 0..<4 {
      let check = Direct8LatencyNative::new()
      check.active[engine] = true
      check.ages[engine] = if mutation == 2 {
        bound + 1
      } else if mutation == 3 {
        1
      } else {
        bound
      }
      frame["q_engine_state_\{engine}"] = if mutation == 1 || mutation == 3 {
        1UL
      } else {
        done
      }
      ranks[engine] = if mutation == 1 {
        1
      } else if mutation == 3 {
        bound
      } else {
        0
      }
      try check.observe(read, ranks) catch {
        BadFairEdge(label) => assert_eq(label, "d8l_age_potential")
        error => fail("unexpected command age failure: \{error}")
      } noraise {
        _ => assert_eq(mutation, 0)
      }
    }
  }
}
