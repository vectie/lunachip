///|
test "queue control proof inputs contain six conclusions and only original startup reset" {
  let artifacts = generate_queue_control_proof_artifacts()
  fn content(path : String) -> String raise {
    guard artifacts.filter(artifact => artifact.path() == path) is [artifact] else {
      fail("missing queue proof input")
    }
    artifact.content()
  }
  let bridge = content("bridge.sv")
  assert_eq(bridge.split("(* anyseq *)").count() - 1, 8)
  assert_eq(bridge.split(": assume (").count() - 1, 1)
  assert_eq(bridge.split(": assert (").count() - 1, 6)
  for
    label in [
      "lc_queue_structure", "lc_queue_population", "lc_queue_public_count_bounds",
      "lc_queue_reset_zero", "lc_queue_established", "lc_queue_nonrising_hold",
    ] {
    assert_eq(bridge.split(label + ": assert (").count() - 1, 1)
  }
  assert_true(bridge.contains("logic lc_clock = 1'b0;"))
  assert_true(bridge.contains("always @($global_clock) lc_clock <= ~lc_clock;"))
  assert_true(
    bridge.contains(
      "lc_initial_joint_reset: assume ((lc_seen_edge || lc_reset) === 1'b1);",
    ),
  )
  assert_true(bridge.contains("!lc_previous_rising_reset || lc_all_reset_zero"))
  assert_true(bridge.contains("!lc_seen_edge || lc_raw_invariant_ok"))
  assert_true(bridge.contains("(!lc_previous_clock && lc_clock)"))
  assert_true(bridge.contains("wire [40:0] lc_current_pair"))
  assert_true(bridge.contains("logic [40:0] lc_previous_pair;"))
  assert_true(
    bridge.contains(
      "wire lc_admit = lc_descriptor_valid && lc_dut_descriptor_ready;",
    ),
  )
  assert_true(bridge.contains("wire lc_retire = lc_dut_retirement_fire;"))
  assert_true(bridge.contains(queue_control_invariant_source()))
  assert_false(bridge.contains("lc_g_public_outstanding <= lc_raw_population"))
  assert_false(bridge.contains("lc_o_head_state == 2'd3 && lc_o_entry_valid"))
  // Twelve cyclic intervals, not only a population count/free write slot.
  assert_eq(
    queue_control_invariant_source().split("lc_entry_valid_mask == 3'd").count() -
    1,
    12,
  )
  let negative = content("negative-reserve.sv")
  let original = "  wire [5:0] lc_checked_population = lc_raw_population;\n"
  let changed = "  wire [5:0] lc_checked_population = (lc_raw_population ^ (lc_genuine_reserve ? 6'd1 : 6'd0));\n"
  assert_eq(bridge.split(original).count() - 1, 1)
  assert_eq(negative.split(changed).count() - 1, 1)
  assert_eq(negative.replace(old=changed, new=original), bridge)
  assert_true(
    negative.contains(
      "wire lc_genuine_reserve = !lc_reset && lc_dut_head_reserve && lc_raw_invariant_ok;",
    ),
  )
  let inventory = content("bridge-inputs.txt")
  for artifact in artifacts {
    if artifact.path() != "bridge-inputs.txt" {
      assert_true(
        inventory.contains(
          "SOURCE \{artifact.path()} sha256 \{sha256_hex(artifact.content())}",
        ),
      )
    }
  }
  assert_true(
    inventory.contains(
      "INVARIANT sha256 \{sha256_hex(queue_control_invariant_source())}",
    ),
  )
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let production = @ir_codec.serialize(
    @ir.Design::single(
      "QueuedConcurrentQueueConservationPilot",
      fixture.hardware(),
    ),
  )
  assert_true(inventory.contains("PRODUCTION sha256 \{sha256_hex(production)}"))
}

///|
test "queue control independent public history matches structural invariant across free peers and reset" {
  let slice = queue_control_sequential(
    @flux_tile.queued_concurrent_queue_formal_fixture(),
  )
  let simulator = queue_control_test_prepare(slice)
  let plan = slice.plan
  let mut outstanding = 0UL
  let mut reserves = 0
  // Directed finite source check, not an inductive or external formal result.
  for cycle in 0..<256 {
    let reset = cycle == 37 || cycle == 137
    queue_control_test_put(
      simulator,
      plan,
      "reset",
      if reset {
        1UL
      } else {
        0UL
      },
    )
    queue_control_test_put(
      simulator,
      plan,
      "descriptor_valid",
      if cycle % 7 != 0 {
        1UL
      } else {
        0UL
      },
    )
    queue_control_test_put(
      simulator,
      plan,
      "completion_ready",
      if cycle % 5 < 3 {
        1UL
      } else {
        0UL
      },
    )
    queue_control_test_put(
      simulator,
      plan,
      "head_finish",
      if cycle % 6 < 4 {
        1UL
      } else {
        0UL
      },
    )
    queue_control_test_put(
      simulator,
      plan,
      "raw_poison",
      if cycle % 17 == 0 {
        1UL
      } else {
        0UL
      },
    )
    for entry in 0..<3 {
      queue_control_test_put(
        simulator,
        plan,
        "entry_terminal_\{entry}",
        if (cycle + entry) % 4 != 0 {
          1UL
        } else {
          0UL
        },
      )
    }
    simulator.settle()
    let descriptor_valid = cycle % 7 != 0
    let admit = descriptor_valid &&
      queue_control_test_get(simulator, "descriptor_ready") == 1UL
    let retire = queue_control_test_get(simulator, "retirement_fire") == 1UL
    let reserve = queue_control_test_get(simulator, "head_reserve") == 1UL
    if reserve {
      reserves += 1
    }
    if reset {
      outstanding = 0UL
      assert_false(admit || retire || reserve)
    } else {
      if retire {
        assert_true(outstanding > 0UL)
      }
      if admit && !retire {
        assert_true(outstanding < 7UL)
      }
      if admit != retire {
        outstanding = if admit { outstanding + 1UL } else { outstanding - 1UL }
      }
    }
    simulator.rising_edge("clock")
    let fifo = queue_control_test_get(simulator, "current_fifo_occupancy_0")
    let state = queue_control_test_get(simulator, "current_head_state")
    let response = queue_control_test_get(
      simulator, "current_fifo_response_valid_0",
    )
    queue_control_test_lanes(simulator, fifo, response)
    assert_true(fifo <= 3UL)
    assert_eq(response == 1UL, state == 1UL)
    assert_true(queue_control_test_get(simulator, "current_head_entry") < 3UL)
    let read = queue_control_test_get(
      simulator, "current_retirement_read_pointer",
    )
    let write = queue_control_test_get(
      simulator, "current_retirement_write_pointer",
    )
    let occupancy = queue_control_test_get(
      simulator, "current_retirement_occupancy",
    )
    assert_true(read < 3UL && write < 3UL && occupancy <= 3UL)
    assert_eq(write, (read + occupancy) % 3UL)
    for entry in 0..<3 {
      let mut expected = false
      for offset in 0..<3 {
        if offset.to_uint64() < occupancy &&
          (read + offset.to_uint64()) % 3UL == entry.to_uint64() {
          expected = true
        }
      }
      assert_eq(
        queue_control_test_get(simulator, "current_entry_valid_\{entry}") == 1UL,
        expected,
      )
    }
    let unreserved = if state == 1UL || state == 2UL { 1UL } else { 0UL }
    assert_eq(outstanding, fifo + occupancy + unreserved)
    assert_true(outstanding <= 7UL)
    if reset {
      for root in plan.roots {
        assert_eq(
          queue_control_test_get(simulator, "current_" + root.name),
          0UL,
        )
      }
    }
  }
  assert_true(reserves > 0)
}
