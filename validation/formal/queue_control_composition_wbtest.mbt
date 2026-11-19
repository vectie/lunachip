///|
fn queue_control_composition_artifact(
  bundle : QueueFormalBundle,
  path : String,
) -> String raise {
  guard bundle.artifacts().filter(item => item.path() == path) is [artifact] else {
    fail("missing/repeated composition artifact: " + path)
  }
  artifact.content()
}

///|
fn queue_control_composition_addition() -> String {
  let history_alias =
    #|  wire [3:0] lc_g_public_outstanding = lc_queue_outstanding;
    #|
  let events =
    #|  wire lc_queue_public_count_step_valid = lc_reset
    #|    || ((!lc_queue_retire || lc_queue_outstanding != 4'd0)
    #|      && (!lc_queue_admit || lc_queue_retire || lc_queue_outstanding < 4'd7));
    #|
  history_alias + queue_control_invariant_source() + events
}

///|
fn queue_control_composition_restore(source : String) -> String raise {
  // Deliberately exact and single-occurrence: no broad whitespace, assertion,
  // state, host-assumption, or nested-memory normalization is permitted.
  let addition = queue_control_composition_addition()
  let prefix = "  wire lc_retirement_event_ownership = (lc_reset || ("
  let suffix = "))\n    && (!lc_queue_sampled || lc_raw_invariant_ok)\n    && lc_queue_public_count_step_valid;\n"
  assert_eq(source.split(addition).count(), 2)
  assert_eq(source.split(prefix).count(), 2)
  assert_eq(source.split(suffix).count(), 2)
  source
  .replace(old=addition, new="")
  .replace(
    old=prefix,
    new="  wire lc_retirement_event_ownership = lc_reset || (",
  )
  .replace(old=suffix, new=");\n")
}

///|
test "queue composition binds every local root to the unchanged actual observation" {
  let view = @flux_tile.queued_concurrent_queue_formal_fixture()
  let design = @ir.Design::single(
    "QueuedConcurrentQueueConservationPilot",
    view.hardware(),
  )
  let before = @ir_codec.serialize(design)
  let plan = queue_control_discover(view)
  let expected : Array[(@flux_tile.QueueConservationRole, @ir.SignalType)] = []
  for lane in 0..<4 {
    expected.push((FifoOccupancy(lane), @wire.uint(2)))
    expected.push((FifoResponseValid(lane), @wire.bits(1)))
  }
  for
    role in [
      @flux_tile.QueueConservationRole::HeadState,
      HeadEntry,
      RetirementReadPointer,
      RetirementWritePointer,
      RetirementOccupancy,
    ] {
    expected.push((role, @wire.uint(if role is HeadState { 2 } else { 5 })))
  }
  for entry in 0..<3 {
    expected.push((EntryValid(entry), @wire.bits(1)))
  }
  assert_eq(view.observations().length(), 115)
  assert_eq(plan.roots.length(), 16)
  assert_eq(expected.length(), 16)
  assert_eq(
    plan.roots
    .iter()
    .fold(init=0, (sum, root) => sum + root.signal_type.width().bits()),
    37,
  )
  let emitted = @rtl.emit_design(design)
  let dut = queue_formal_dut(view, emitted)
  let bundle = generate_queue_formal_bundle(Conservation)
  let harness = queue_control_composition_artifact(bundle, "formal-harness.sv")
  let invariant = queue_control_invariant_source()
  for (role, signal_type) in expected {
    let name = queue_role_name(role)
    guard view.observations().filter(item => item.role() == role)
      is [observation] else {
      fail("missing/repeated actual observation")
    }
    guard plan.roots.filter(root => root.name == name) is [root] else {
      fail("missing/repeated exact control root")
    }
    assert_eq(root.node, observation.node())
    assert_eq(root.signal_type, signal_type)
    assert_eq(observation.signal_type(), signal_type)
    guard view.hardware().node(root.node) is Some(node) &&
      node.kind() is Register(spec) else {
      fail("control root is not the original production register")
    }
    assert_eq(node.signal_type(), signal_type)
    assert_eq(root.spec, spec)
    let identifier = emitted_node_identifier(emitted, root.node.ordinal())
    assert_eq(
      dut.source
      .split("assign lc_formal_observe_\{name} = \{identifier};")
      .count(),
      2,
    )
    assert_eq(
      harness.split(".lc_formal_observe_\{name}(lc_o_\{name})").count(),
      2,
    )
    assert_true(invariant.contains("lc_o_" + name))
  }
  assert_eq(@ir_codec.serialize(design), before)
  assert_eq(queue_control_composition_artifact(bundle, "design.lcir"), before)
  assert_eq(
    queue_control_composition_artifact(bundle, "formal-dut.sv"),
    dut.source,
  )
}

///|
test "composition removes exactly to the two accepted original full harnesses" {
  // Retained accepted full harness digests, not a duplicated old generator.
  // This checks every old ghost update, mutation and host check byte-for-byte.
  for
    (fixture, digest) in [
      (
        QueueFormalFixture::Conservation,
        "b4a74128cc034a60e16f3ab0626b64a889685dfb97a22e4f525265ee806b9a90",
      ),
      (
        NegativePopulation,
        "9133ed3e740da4f82d4d6bd42b97206073a0a283597ed39bbeefaa58c2427f13",
      ),
    ] {
    let bundle = generate_queue_formal_bundle(fixture)
    let source = queue_control_composition_artifact(bundle, "formal-harness.sv")
    let restored = queue_control_composition_restore(source)
    assert_eq(sha256_hex(restored), digest)
    assert_true(source != restored)
    assert_false(sha256_hex(source) == digest)
    assert_false(restored.contains("lc_raw_invariant_ok"))
    assert_false(restored.contains("lc_queue_public_count_step_valid"))
  }
}

///|
test "all six queue profiles retain DUT memory labels properties and task contracts" {
  // Source-contract regression only: this is not a whole-device engine result.
  let view = @flux_tile.queued_concurrent_queue_formal_fixture()
  let design = @ir.Design::single(
    "QueuedConcurrentQueueConservationPilot",
    view.hardware(),
  )
  let emitted = @rtl.emit_design(design)
  let dut = queue_formal_dut(view, emitted)
  let memory_assertions = dut.production_source
    .split("\n")
    .filter(line => line.contains("_bounds: assert ("))
    .map(line => line.to_owned())
    .to_array()
  assert_true(memory_assertions.length() > 0)
  let bundles = standard_queue_formal_bundles()
  assert_eq(bundles.length(), 6)
  for index, bundle in bundles {
    assert_eq(
      bundle.fixture(),
      [
        QueueFormalFixture::Conservation,
        NegativePopulation,
        RetirementRecords,
        NegativeHeldPayload,
        PacketProvenance,
        NegativePacketProvenance,
      ][index],
    )
    let harness = queue_control_composition_artifact(
      bundle, "formal-harness.sv",
    )
    ignore(queue_control_composition_restore(harness))
    assert_eq(
      queue_control_composition_artifact(bundle, "design.lcir"),
      @ir_codec.serialize(design),
    )
    assert_eq(
      queue_control_composition_artifact(bundle, dut.production_filename),
      dut.production_source,
    )
    let adapter = queue_control_composition_artifact(bundle, "formal-dut.sv")
    assert_eq(adapter, dut.source)
    assert_eq(
      adapter
      .split("\n")
      .filter(line => line.contains("_bounds: assert ("))
      .map(line => line.to_owned())
      .to_array(),
      memory_assertions,
    )
    let (exported, legal, assertions, covers) = queue_property_export(
      bundle.fixture(),
    )
    assert_eq(
      queue_control_composition_artifact(bundle, "properties.lcfp"),
      exported.manifest(),
    )
    assert_eq(legal.length(), 4)
    assert_eq(
      assertions.length(),
      if index < 2 {
        3
      } else if index < 4 {
        6
      } else {
        7
      },
    )
    assert_eq(
      covers.length(),
      if index < 2 {
        1
      } else if index < 4 {
        2
      } else {
        3
      },
    )
    assert_eq(
      exported.property_manifest().properties()[0:4].map(item => item.name()),
      [
        "initial_joint_reset", "host_descriptor_stable_until_accept", "host_response_stable_until_accept",
        "host_response_flushed_during_reset",
      ],
    )
    let positive = queue_positive_profile(bundle.fixture())
    assert_eq(bundle.tasks().length(), if positive { 2 } else { 1 })
    for task_index, gate in bundle.tasks() {
      assert_eq(gate.bound(), 256)
      assert_eq(gate.timeout_seconds(), 600)
      guard gate.task() is Bounded(task) else {
        fail("composition changed a queue task class")
      }
      assert_eq(task.engine(), "smtbmc-bitwuzla")
      assert_eq(task.assumptions(), legal)
      assert_eq(
        task.mode(),
        if task_index == 0 {
          BoundedSafety
        } else {
          BoundedCover
        },
      )
      let selected = if task_index == 1 {
        [covers[covers.length() - 1]]
      } else if positive {
        assertions.iter().to_array()
      } else {
        [bundle.expected_failure()]
      }
      // Check the exact selected roster independently of canonical label order.
      // The external artifact comparison also preserves the task bytes.
      assert_eq(task.properties().length(), selected.length())
      for label in selected {
        assert_true(task.properties().contains(label))
      }
      guard task.timing_contract() is Some(timing) else {
        fail("composition removed queue clock timing")
      }
      assert_eq(timing.global_timestep().steps(), 2)
      assert_eq(timing.clocks().length(), 1)
      assert_eq(timing.clocks()[0].edge(), Rising)
      assert_eq(timing.legal_transition_assumptions(), legal)
      assert_eq(timing.fairness_assumptions().length(), 0)
      assert_eq(timing.coincidence_policy(), AtomicGlobalPreState)
    }
  }
}

///|
test "contiguous relation rejects population-only ring and later reset cannot bypass it" {
  let invariant = queue_control_invariant_source()
  // r0,w2,R1 with only entry0 live has a free write slot and correct population,
  // but is not a cyclic interval. Reserving there would later overwrite live0.
  let bad = "(lc_o_retirement_read_pointer == 5'd0 && lc_o_retirement_occupancy == 5'd1 && lc_o_retirement_write_pointer == 5'd2 && lc_entry_valid_mask == 3'd1)"
  let good = "(lc_o_retirement_read_pointer == 5'd0 && lc_o_retirement_occupancy == 5'd1 && lc_o_retirement_write_pointer == 5'd1 && lc_entry_valid_mask == 3'd1)"
  assert_false(invariant.contains(bad))
  assert_true(invariant.contains(good))
  let mask = 1
  let retirement_population = 1
  assert_eq(
    (mask & 1) + ((mask >> 1) & 1) + ((mask >> 2) & 1),
    retirement_population,
  )
  assert_eq(mask & (1 << 2), 0)
  let monitor = queue_monitor_source(Conservation)
  assert_true(monitor.contains(queue_control_composition_addition()))
  assert_true(
    monitor.contains(
      "))\n    && (!lc_queue_sampled || lc_raw_invariant_ok)\n    && lc_queue_public_count_step_valid;\n",
    ),
  )
  assert_true(monitor.contains("logic lc_queue_sampled = 1'b0;"))
  assert_true(monitor.contains("lc_queue_sampled <= 1'b1;"))
  assert_false(monitor.contains("lc_queue_sampled <= 1'b0;"))
  // Truth table of the exact new predicate, not a replacement RTL evaluator.
  // Once sampled, invalid state is rejected even with current reset asserted.
  for reset in [false, true] {
    let old_checks = true
    let sampled = true
    let raw_invariant = false
    let event_valid = true
    assert_false(
      (reset || old_checks) && (!sampled || raw_invariant) && event_valid,
    )
  }
  // Current public under/overflow is a conclusion, not a ghost repair. Even
  // simultaneous admission cannot authorize retirement from an empty history.
  for outstanding in 0..<8 {
    for admit in [false, true] {
      for retire in [false, true] {
        let event_valid = (!retire || outstanding != 0) &&
          (!admit || retire || outstanding < 7)
        let expected = if retire {
          outstanding > 0
        } else if admit {
          outstanding < 7
        } else {
          true
        }
        assert_eq(event_valid, expected)
      }
    }
  }
}
