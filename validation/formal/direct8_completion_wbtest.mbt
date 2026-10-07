///|
fn direct8_completion_test_artifact(
  bundle : Direct8CompletionBundle,
  path : String,
) -> String raise {
  guard bundle.artifacts.filter(item => item.path() == path) is [artifact] else {
    fail("missing/repeated direct8 artifact: " + path)
  }
  artifact.content()
}

///|
fn direct8_completion_test_tasks(
  bundle : Direct8CompletionBundle,
) -> ReadOnlyArray[@formal_core.BoundedProofTask] raise {
  bundle.artifacts
  .filter(item => item.path().has_suffix(".lcft"))
  .map(item => {
    guard @formal_core.parse_proof_task(item.content()) is Bounded(task) else {
      fail("bounded direct8 encoded task required")
    }
    assert_eq(item.path(), task.name() + ".lcft")
    task
  })
}

///|
test "direct8 completion derives its own full watch-tail budget and legal repeated-ID packets" {
  let budget = direct8_completion_budget()
  assert_eq(
    (budget.transaction, budget.load, budget.store, budget.compute),
    (6, 1666, 898, 99),
  )
  assert_eq((budget.engine, budget.deadline), (1666, 11718))
  assert_eq(
    (budget.watch_window, budget.required_global_steps, budget.global_steps),
    (32, 23502, 23552),
  )
  assert_eq((budget.age_width, budget.age_max), (14, 16383))
  assert_true(
    1 + budget.watch_window + budget.deadline < budget.global_steps / 2,
  )
  assert_true(budget.age_max > budget.deadline)
  assert_eq(direct_completion_deadline(), 252)
  let shapes : Array[(UInt, UInt, UInt, UInt, UInt)] = [
    (8U, 16U, 0U, 256U, 16U),
    (16U, 8U, 0U, 512U, 8U),
    (8U, 8U, 16U, 0U, 0U),
    (8U, 8U, 0U, 1024U, 32U),
  ]
  for index in 0..<4 {
    let bytes : Array[Byte] = []
    for lane in direct8_completion_packet(index) {
      for offset in 0..<8 {
        bytes.push(((lane >> (8 * offset)) & 255UL).to_byte())
      }
    }
    let encoded = Bytes::from_array(bytes)
    let packet = @slotted_descriptor.decode(encoded)
    assert_eq(packet.encode(), encoded)
    assert_eq(packet.id, 73U)
    assert_eq(
      (
        packet.rows,
        packet.columns,
        packet.reduction,
        packet.base,
        packet.stride,
      ),
      shapes[index],
    )
    assert_eq((packet.a_slot, packet.b_slot, packet.c_slot), (0U, 0U, 0U))
  }
  for fixture in [Eventual, UsefulStore, NegativeDeadline] {
    assert_eq(
      direct8_completion_from_id(direct8_completion_id(fixture)),
      Some(fixture),
    )
    assert_eq(
      DirectCompletionFixture::from_id(direct8_completion_id(fixture)),
      None,
    )
    assert_eq(direct8_completion_from_id(fixture.id()), None)
  }
}

///|
// Pin all three previously sealed complete harnesses: parameterization is not
// permission to alter the established1x1 source, host premises or task bytes.
test "direct8 parameterization preserves all sealed direct1 harness and task artifacts" {
  for
    (fixture, expected) in [
      (
        Eventual,
        "cd54beb2255a23bd761add7ace2086ec9c7384a52e085aa44e5de6fba9d63d64",
      ),
      (
        UsefulStore,
        "ebfb257cab7b24f628ee259ab9d6bb6bbc5ed3db31461b6c8ca2fd59257c223e",
      ),
      (
        NegativeDeadline,
        "e63969da2f53c5cc123253b3f34cde4462b0ef3a27ffe4f1ce34a1220666d5a6",
      ),
    ] {
    let bundle = generate_direct_completion_formal_bundle(fixture)
    assert_eq(
      sha256_hex(direct_completion_test_artifact(bundle, "formal-harness.sv")),
      expected,
    )
    assert_eq(
      sha256_hex(direct_completion_test_artifact(bundle, "formal-dut.sv")),
      "b81ca96190670c59fa630b13430180c48f227cf8a4931256b8d356eb5d1cfef5",
    )
    for task in bundle.tasks() {
      assert_eq(task.bound(), 640)
      assert_true(task.name().has_prefix(fixture.id()))
    }
  }
}

///|
test "direct8 bundles bind original plain public device and deadline-only causal negative" {
  let positive = generate_direct8_completion_bundle(Eventual)
  let negative = generate_direct8_completion_bundle(NegativeDeadline)
  let hardware = @flux_tile.queued_concurrent_tile(
    rows=8,
    columns=8,
    max_reduction=16,
    host_bytes=4096UL,
    queue_depth=3,
  )
  let design = @ir.Design::single(
    "QueuedConcurrentDirect8CompletionPilot", hardware,
  )
  let emitted = @rtl.emit_design(design)
  guard emitted.modules() is [production] else {
    fail("plain original single module")
  }
  let dut = direct8_completion_dut(hardware, emitted)
  assert_eq(dut.observation_ports.length(), 0)
  assert_eq(dut.ports.length(), dependency_public_ports().length())
  for (role, width, input) in dependency_public_ports() {
    guard dut.ports.filter(port => port.role == role) is [port] else {
      fail("exact public port binding")
    }
    assert_eq((port.width, port.input), (width, input))
    assert_eq(
      port.identifier,
      port_identifier(emitted, if input { InputPort } else { OutputPort }, role),
    )
  }
  assert_eq(
    direct8_completion_test_artifact(positive, "design.lcir"),
    @ir_codec.serialize(design),
  )
  assert_eq(
    direct8_completion_test_artifact(positive, dut.production_filename),
    production.source(),
  )
  assert_eq(
    direct8_completion_test_artifact(positive, "formal-dut.sv"),
    dut.source,
  )
  assert_eq(
    direct8_completion_test_artifact(positive, "names.lcnm"),
    emitted.manifest().to_canonical_text(),
  )
  let source = direct8_completion_test_artifact(positive, "formal-harness.sv")
  let changed = direct8_completion_test_artifact(negative, "formal-harness.sv")
  let raw_line = "  wire [13:0] lc_dc_checked_deadline = 14'd11718;\n"
  let negative_line = "  wire [13:0] lc_dc_checked_deadline = (lc_dc_saved_packet == LC_DC_LOAD_A ? 14'd1 : 14'd11718);\n"
  assert_eq(source.split(raw_line).count(), 2)
  assert_eq(changed.split(negative_line).count(), 2)
  assert_eq(changed.replace(old=negative_line, new=raw_line), source)
  for path in ["design.lcir", "formal-dut.sv", "names.lcnm", "properties.lcfp"] {
    assert_eq(
      direct8_completion_test_artifact(positive, path),
      direct8_completion_test_artifact(negative, path),
    )
  }
  assert_true(source.contains(direct_completion_host_source()))
  assert_false(source.contains("lc_o_"))
  assert_true(source.contains("logic [13:0] lc_dc_age = 14'd0;"))
  assert_true(
    source.contains(
      "if (lc_dc_age < 14'd16383) lc_dc_age <= lc_dc_age + 14'd1;",
    ),
  )
  assert_true(
    source.contains(
      "lc_dc_saved_packet <= lc_dc_packet;\n        lc_dc_age <= 14'd1;",
    ),
  )
  assert_true(
    source.contains(
      "lc_dc_older <= lc_dc_outstanding - (lc_dc_retire ? 4'd1 : 4'd0);",
    ),
  )
  assert_eq(
    direct_completion_test_predicate(source, "dc_watch"),
    direct_completion_test_predicate(
      direct_completion_monitor_source(false),
      "dc_watch",
    ),
  )
  for
    name in [
      "dc_ordinal_history", "dc_request_stable", "dc_completion_stable", "dc_transport_serial_owned",
      "dc_response_readiness", "dc_watched_retirement_deadline",
    ] {
    let direct1 = direct_completion_host_source() +
      direct_completion_monitor_source(false)
    assert_eq(
      direct_completion_test_predicate(source, name),
      direct_completion_test_predicate(direct1, name),
    )
  }
  for
    name in [
      "dc_host_request_ready_r2", "dc_host_response_offer_h2", "dc_host_completion_ready_c2",
    ] {
    assert_eq(
      direct_completion_test_predicate(source, name),
      direct_completion_test_predicate(direct_completion_host_source(), name),
    )
  }
  assert_false(
    direct_completion_test_predicate(source, "dc_host_response_offer_h2").contains(
      "response_ready",
    ),
  )
  assert_eq(source.split(": assume (").count(), 8)
  assert_eq(changed.split(": assume (").count(), 8)
}

///|
test "direct8 five tasks preserve named premises PRE clock and entire23552 global obligation" {
  let mut count = 0
  for fixture in [Eventual, UsefulStore, NegativeDeadline] {
    let bundle = generate_direct8_completion_bundle(fixture)
    let plan = @formal_core.parse_formal_property_manifest(
      direct8_completion_test_artifact(bundle, "properties.lcfp"),
    )
    let properties = plan.properties()
    let useful = fixture is UsefulStore
    let negative = fixture is NegativeDeadline
    let source_set = direct8_completion_test_artifact(bundle, "source-set.lcfs")
    let job = direct8_completion_test_artifact(bundle, "job.json")
    let top = "lc_formal_direct_completion_top"
    assert_true(
      source_set.contains("FIXTURE \{direct8_completion_id(fixture)}\n"),
    )
    assert_true(source_set.contains("TOP \{top}\n"))
    assert_true(job.contains("\"top_module\": \"\{top}\""))
    assert_eq(properties.length(), if useful { 17 } else { 16 })
    assert_eq(properties[7:13].map(item => item.name()), [
      "dc_ordinal_history", "dc_request_stable", "dc_completion_stable", "dc_transport_serial_owned",
      "dc_response_readiness", "dc_watched_retirement_deadline",
    ])
    let tasks = direct8_completion_test_tasks(bundle)
    assert_eq(tasks.length(), if useful || negative { 1 } else { 3 })
    for ordinal, bounded in tasks {
      count += 1
      let name = bounded.name()
      let safety = !useful && ordinal == 0
      let mode = if safety { "bmc" } else { "cover" }
      let claim = if safety {
        "bounded-safety-up-to-bound"
      } else {
        "reachability-within-bound"
      }
      let expected = if negative { "fail" } else { "pass" }
      assert_true(name.has_prefix(direct8_completion_id(fixture)))
      assert_eq(
        bounded.mode(),
        if safety {
          BoundedSafety
        } else {
          BoundedCover
        },
      )
      assert_true(
        job.contains(
          "\"name\": \"\{name}\", \"mode\": \"\{mode}\", \"claim\": \"\{claim}\", \"bound\": 23552, \"timeout_seconds\": 600, \"engine\": \"smtbmc\", \"solver\": \"bitwuzla\", \"expect\": \"\{expected}\"",
        ),
      )
      assert_eq(bounded.bound().cycles(), 23552)
      assert_eq(bounded.assumptions().length(), if useful { 8 } else { 7 })
      for property in properties.filter(item => item.kind() is Assumption) {
        assert_eq(
          bounded
          .assumptions()
          .filter(label => label == property.stable_name())
          .length(),
          1,
        )
      }
      let selected = if negative {
        [properties[12].stable_name()]
      } else if !useful && ordinal == 0 {
        properties[7:13].map(item => item.stable_name())
      } else {
        [properties[if useful { 15 } else { 12 + ordinal }].stable_name()]
      }
      assert_eq(bounded.properties().length(), selected.length())
      for label in selected {
        assert_eq(
          bounded.properties().filter(item => item == label).length(),
          1,
        )
      }
      guard bounded.timing_contract() is Some(timing) else {
        fail("exact clock contract required")
      }
      assert_eq(timing.global_timestep().steps(), 2)
      assert_eq(timing.coincidence_policy(), AtomicGlobalPreState)
      assert_eq(timing.fairness_assumptions().length(), 3)
      assert_eq(
        timing.legal_transition_assumptions().length(),
        if useful {
          5
        } else {
          4
        },
      )
      guard timing.clocks() is [clock] else { fail("single direct8 clock") }
      assert_eq(clock.edge(), Rising)
      assert_eq(clock.signal(), @property.PropertySignal::named(top, "clock"))
      for property in properties {
        assert_eq(property.disable(), NeverDisabled)
        assert_eq(property.domain().clock(), clock.signal())
      }
      assert_eq(
        @formal_core.parse_proof_task(
          direct8_completion_test_artifact(bundle, name + ".lcft"),
        ),
        Bounded(bounded),
      )
      let execution = direct8_completion_test_artifact(bundle, name + ".lcfg")
      assert_true(
        execution.contains(
          "BOUND-MAPPING 23552-global-steps-11776-dut-clocks\n",
        ),
      )
      assert_true(
        execution.contains("SELECTED-PROPERTIES \{selected.length()}\n"),
      )
      assert_true(
        execution.contains("JOB job.json sha256 \{sha256_hex(job)}\n"),
      )
    }
    assert_true(source_set.contains("FAMILY flux-tile-direct8-completion\n"))
    assert_true(
      source_set.contains(
        "NO-FETCHED-RING direct-public-descriptor-admission-not-ring4-publication\n",
      ),
    )
    assert_true(
      source_set.contains("generated-inputs-only-not-proof-or-receipt"),
    )
    for
      path in [
        "design.lcir", "formal-dut.sv", "formal-harness.sv", "properties.lcfp", "names.lcnm",
      ] {
      assert_true(
        source_set.contains(
          "\{path} sha256 \{sha256_hex(direct8_completion_test_artifact(bundle, path))}\n",
        ),
      )
    }
  }
  assert_eq(count, 5)
}

///|
test "direct8 useful Store observes all256 read and64 word write owned pairs without internal progress premises" {
  let bundle = generate_direct8_completion_bundle(UsefulStore)
  let source = direct8_completion_test_artifact(bundle, "formal-harness.sv")
  assert_eq(source.split(": assume (").count(), 9)
  let cover = direct_completion_test_predicate(source, "dc_useful_store_cover")
  for
    clause in [
      "lc_dc_ordinal_retire && lc_dc_saved_packet == LC_DC_STORE && lc_dc_age <= 14'd11718",
      "lc_dc_sequence_admitted == 3'd4 && lc_dc_sequence_retired == 3'd3", "(&lc_dc_useful_read_addresses) && (&lc_dc_useful_read_ack_addresses)",
      "(&lc_dc_useful_write_addresses) && (&lc_dc_useful_write_ack_addresses)", "lc_dc_useful_read_accepts == 9'd256 && lc_dc_useful_read_acks == 9'd256",
      "lc_dc_useful_write_accepts == 7'd64 && lc_dc_useful_write_acks == 7'd64",
      "lc_completion_bytes_completed == 32'd256 && lc_completion_fault_address == 32'd0",
    ] {
    assert_true(cover.contains(clause))
  }
  for operation in ["read", "write"] {
    let ack = direct_completion_test_predicate(
      source,
      "dc_useful_" + operation + "_ack",
    )
    assert_true(ack.contains("lc_dc_response_accept && lc_dc_host_owned"))
    assert_true(ack.contains("lc_dc_useful_owned_good_" + operation))
    assert_true(
      ack.contains(
        "lc_memory_response_tag == lc_dc_host_tag && lc_memory_response_fault == 2'd0",
      ),
    )
    assert_true(
      source.contains(
        "lc_dc_useful_\{operation}_ack_addresses[lc_dc_useful_owned_\{operation}_index] <= 1'b1;",
      ),
    )
  }
  assert_false(source.contains("lc_dc_useful_engines"))
  assert_false(source.contains("lc_o_"))
  assert_eq(
    direct_completion_test_predicate(source, "dc_public_producer_sequence"),
    direct_completion_test_predicate(
      direct_completion_useful_source(),
      "dc_public_producer_sequence",
    ),
  )
}
