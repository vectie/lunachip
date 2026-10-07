///|
fn direct_completion_test_artifact(
  bundle : DirectCompletionFormalBundle,
  path : String,
) -> String raise {
  guard bundle.artifacts().filter(item => item.path() == path) is [artifact] else {
    fail("missing or repeated direct completion artifact: " + path)
  }
  artifact.content()
}

///|
// Inspect complete single-point predicates, not a large list of incidental
// formatting fragments. A missing/repeated predicate fails independently.
fn direct_completion_test_predicate(
  source : String,
  name : String,
) -> String raise {
  guard source.split("  wire lc_" + name + " = ").to_array() is [_, tail] else {
    fail("missing or repeated completion predicate: " + name)
  }
  guard tail.split(";").to_array() is [predicate, _, ..] else {
    fail("unterminated completion predicate: " + name)
  }
  predicate.to_owned()
}

///|
test "direct completion bundles bind one unchanged canonical direct device and named generated inputs" {
  let bundles = standard_direct_completion_formal_bundles()
  assert_eq(bundles.map(bundle => bundle.fixture()), [
    Eventual,
    UsefulStore,
    NegativeDeadline,
  ])
  let view = @flux_tile.queued_concurrent_queue_formal_fixture()
  let ordinary = @flux_tile.queued_concurrent_tile(
    rows=1,
    columns=1,
    max_reduction=2,
    host_bytes=1024UL,
    queue_depth=3,
  )
  assert_eq(view.hardware(), ordinary)
  let canonical = @ir_codec.serialize(
    @ir.Design::single("QueuedConcurrentQueueConservationPilot", ordinary),
  )
  assert_eq(
    sha256_hex(canonical),
    "35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc",
  )
  let emitted = @rtl.emit_design(
    @ir.Design::single("QueuedConcurrentQueueConservationPilot", ordinary),
  )
  guard emitted.modules() is [dut] else {
    fail("expected one unchanged production module")
  }
  for bundle in bundles {
    assert_eq(
      bundle,
      generate_direct_completion_formal_bundle(bundle.fixture()),
    )
    assert_eq(
      DirectCompletionFixture::from_id(bundle.fixture().id()),
      Some(bundle.fixture()),
    )
    assert_eq(bundle.top_identifier(), "lc_formal_direct_completion_top")
    assert_eq(direct_completion_test_artifact(bundle, "design.lcir"), canonical)
    assert_eq(
      direct_completion_test_artifact(bundle, "production-" + dut.filename()),
      dut.source(),
    )
    assert_eq(
      direct_completion_test_artifact(bundle, "job.json"),
      bundle.job_json(),
    )
    let source_set = direct_completion_test_artifact(bundle, "source-set.lcfs")
    let harness = direct_completion_test_artifact(bundle, "formal-harness.sv")
    let properties = direct_completion_test_artifact(bundle, "properties.lcfp")
    for
      (name, content) in [
        ("design.lcir", canonical),
        (
          "formal-dut.sv",
          direct_completion_test_artifact(bundle, "formal-dut.sv"),
        ),
        ("formal-harness.sv", harness),
        ("properties.lcfp", properties),
      ] {
      assert_true(
        source_set.contains("\{name} sha256 \{sha256_hex(content)}\n"),
      )
    }
    assert_true(
      source_set.contains(
        "PRODUCTION-UNCOMPILED production-\{dut.filename()} sha256 \{sha256_hex(dut.source())}\n",
      ),
    )
    assert_eq(source_set.split("OBSERVATION ").count(), 116)
    let observed_dut = direct_completion_test_artifact(bundle, "formal-dut.sv")
    for observation in view.observations() {
      let name = queue_role_name(observation.role())
      guard emitted
        .manifest()
        .mappings()
        .filter(mapping => {
          mapping.kind() is Node &&
          mapping.module_ordinal() == emitted.manifest().top_module_ordinal() &&
          mapping.local_ordinal() == observation.node().ordinal()
        })
        is [mapping] else {
        fail("missing original observation emitter identity")
      }
      assert_true(
        observed_dut.contains(
          "assign lc_formal_observe_\{name} = \{mapping.identifier()};",
        ),
      )
      assert_true(harness.contains(".lc_formal_observe_\{name}(lc_o_\{name})"))
      assert_true(
        source_set.contains(
          "OBSERVATION \{name} node \{observation.node().ordinal()} width \{observation.signal_type().width().bits()} type \{queue_signal_type_name(observation.signal_type())}\n",
        ),
      )
    }
    let public_inputs = ordinary
      .nodes()
      .filter(node => {
        match node.kind() {
          Input(name) => name != "clock" && name != "reset"
          _ => false
        }
      })
    assert_eq(public_inputs.length(), 11)
    assert_eq(harness.split("(* anyseq *)").count(), public_inputs.length() + 2)
    assert_false(harness.contains("cut_n"))
    assert_true(
      source_set.contains(
        "CLAIM-BOUNDARY generated-inputs-only-until-actual-engine-evidence-direct1x1-K2-only-not8x8-fetched-reset-fault-or-full-Phase6-completion",
      ),
    )
    assert_true(
      bundle.job_json().contains("\"bound\": 640, \"timeout_seconds\": 600"),
    )
    let paths = bundle.artifacts().map(item => item.path())
    assert_eq(paths.length(), 7 + 2 * bundle.tasks().length())
    for path in paths {
      assert_eq(paths.filter(other => other == path).length(), 1)
      assert_false(path.has_prefix("/"))
    }
  }
  assert_eq(
    DirectCompletionFixture::from_id("phase6-flux-tile-direct-q3-eventual"),
    None,
  )
  assert_eq(DirectCompletionFixture::from_id(""), None)
}

///|
test "direct completion selects explicit legal fairness and conclusion labels at the full declared horizon" {
  let bundles = standard_direct_completion_formal_bundles()
  let expected_names = [
    "dc_initial_only_reset", "dc_host_descriptor_stable", "dc_host_owned_success_response",
    "dc_host_response_stable", "dc_host_request_ready_r2", "dc_host_response_offer_h2",
    "dc_host_completion_ready_c2", "dc_ordinal_history", "dc_request_stable", "dc_completion_stable",
    "dc_transport_serial_owned", "dc_response_readiness", "dc_watched_retirement_deadline",
    "dc_watched_terminal_cover", "dc_watched_retirement_cover", "dc_useful_store_cover",
  ]
  let view = @flux_tile.queued_concurrent_queue_formal_fixture()
  guard view.hardware().domains() is [domain] else {
    fail("expected original single domain")
  }
  for bundle in bundles {
    let useful = bundle.fixture() is UsefulStore
    let negative = bundle.fixture() is NegativeDeadline
    let plan = @formal_core.parse_formal_property_manifest(
      direct_completion_test_artifact(bundle, "properties.lcfp"),
    )
    let properties = plan.properties()
    assert_eq(properties[:16].map(item => item.name()), expected_names)
    assert_eq(properties.length(), if useful { 17 } else { 16 })
    let legal = properties[:4].map(item => item.stable_name())
    if useful {
      assert_eq(properties[16].name(), "dc_public_producer_sequence")
      assert_eq(properties[16].kind(), Assumption)
      legal.push(properties[16].stable_name())
    }
    let fairness = properties[4:7].map(item => item.stable_name())
    let assumptions = legal.copy()
    for label in fairness {
      assumptions.push(label)
    }
    assert_eq(assumptions.length(), if useful { 8 } else { 7 })
    for index, property in properties {
      assert_eq(property.id().ordinal(), index)
      assert_eq(
        property.kind(),
        if index < 7 || index == 16 {
          Assumption
        } else if index < 13 {
          Assertion
        } else {
          Cover
        },
      )
      assert_eq(property.disable(), NeverDisabled)
      assert_eq(
        property.domain().clock(),
        @property.PropertySignal::named(bundle.top_identifier(), "clock"),
      )
    }
    assert_eq(bundle.tasks().length(), if useful || negative { 1 } else { 3 })
    assert_eq(
      bundle.expected_failure(),
      if negative {
        properties[12].stable_name()
      } else {
        "none"
      },
    )
    for ordinal, task in bundle.tasks() {
      assert_eq(task.bound(), 640)
      assert_eq(task.timeout_seconds(), 600)
      assert_true(task.name().has_prefix(bundle.fixture().id()))
      guard task.task() is Bounded(bounded) else {
        fail("completion inputs must be bounded only")
      }
      assert_eq(bounded.bound().cycles(), 640)
      assert_eq(bounded.assumptions().length(), assumptions.length())
      for label in assumptions {
        assert_eq(
          bounded.assumptions().filter(item => item == label).length(),
          1,
        )
      }
      assert_eq(bounded.engine(), "smtbmc-bitwuzla")
      assert_eq(
        bounded.artifact().sha256(),
        sha256_hex(direct_completion_test_artifact(bundle, "source-set.lcfs")),
      )
      guard bounded.timing_contract() is Some(timing) else {
        fail("missing explicit completion timing")
      }
      assert_eq(timing.global_timestep().steps(), 2)
      assert_eq(timing.legal_transition_assumptions().length(), legal.length())
      for label in legal {
        assert_eq(
          timing
          .legal_transition_assumptions()
          .filter(item => item == label)
          .length(),
          1,
        )
      }
      assert_eq(timing.fairness_assumptions().length(), fairness.length())
      for label in fairness {
        assert_eq(
          timing.fairness_assumptions().filter(item => item == label).length(),
          1,
        )
      }
      assert_eq(timing.coincidence_policy(), AtomicGlobalPreState)
      guard timing.clocks() is [clock] else { fail("wrong clock roster") }
      assert_eq(clock.domain(), domain.id())
      assert_eq(clock.edge(), Rising)
      assert_eq(
        clock.signal(),
        @property.PropertySignal::named(bundle.top_identifier(), "clock"),
      )
      let safety = !useful && ordinal == 0
      assert_eq(
        bounded.mode(),
        if safety {
          BoundedSafety
        } else {
          BoundedCover
        },
      )
      assert_eq(task.expected_status(), if negative { "fail" } else { "pass" })
      let selected = if negative {
        [properties[12].stable_name()]
      } else if safety {
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
      assert_eq(
        @formal_core.parse_proof_task(
          direct_completion_test_artifact(bundle, task.name() + ".lcft"),
        ),
        task.task(),
      )
      let execution = direct_completion_test_artifact(
        bundle,
        task.name() + ".lcfg",
      )
      assert_true(
        execution.contains("BOUND-MAPPING 640-global-steps-320-dut-clocks\n"),
      )
      assert_true(
        execution.contains("SELECTED-ASSUMPTIONS \{assumptions.length()}\n"),
      )
      assert_true(
        execution.contains("SELECTED-PROPERTIES \{selected.length()}\n"),
      )
      assert_true(
        execution.contains(
          "EXPECTED-FAILURE \{if negative { bundle.expected_failure() } else { "none" }}\n",
        ),
      )
      assert_true(
        execution.contains(
          "JOB job.json sha256 \{sha256_hex(bundle.job_json())}\n",
        ),
      )
    }
  }
}

///|
test "direct completion deadline sensitivity changes only checked deadline with genuine public ordinal histories" {
  let positive = generate_direct_completion_formal_bundle(Eventual)
  let negative = generate_direct_completion_formal_bundle(NegativeDeadline)
  let source = direct_completion_test_artifact(positive, "formal-harness.sv")
  let changed = direct_completion_test_artifact(negative, "formal-harness.sv")
  let original_line = "  wire [7:0] lc_dc_checked_deadline = 8'd252;\n"
  let changed_line = "  wire [7:0] lc_dc_checked_deadline = (lc_dc_saved_packet == LC_DC_LOAD_A ? 8'd1 : 8'd252);\n"
  assert_eq(source.split(original_line).count(), 2)
  assert_eq(changed.split(changed_line).count(), 2)
  assert_eq(changed.replace(old=changed_line, new=original_line), source)
  for path in ["design.lcir", "formal-dut.sv", "properties.lcfp"] {
    assert_eq(
      direct_completion_test_artifact(positive, path),
      direct_completion_test_artifact(negative, path),
    )
  }
  assert_eq(
    direct_completion_test_predicate(source, "dc_host_response_offer_h2"),
    "lc_reset || !lc_dc_host_owned\n    || lc_dc_response_offered || lc_dc_response_age < 2'd2 || lc_memory_response_valid",
  )
  assert_false(
    direct_completion_test_predicate(source, "dc_host_response_offer_h2").contains(
      "response_ready",
    ),
  )
  assert_true(
    source.contains(
      "lc_dc_response_age <= 2'd1;\n        lc_dc_response_offered <= 1'b0;",
    ),
  )
  assert_true(
    source.contains(
      "if (lc_memory_response_valid) lc_dc_response_offered <= 1'b1;",
    ),
  )
  assert_true(
    source.contains(
      "lc_dc_response_hold <= lc_memory_response_valid && !lc_memory_response_ready;",
    ),
  )
  assert_eq(
    direct_completion_test_predicate(source, "dc_response_readiness"),
    "lc_reset || !lc_dc_host_owned || lc_memory_response_ready",
  )
  assert_eq(
    direct_completion_test_predicate(source, "dc_watch"),
    "!lc_reset && !lc_dc_taken && lc_dc_select\n    && lc_dc_post_reset_edges < 6'd32 && lc_dc_admit",
  )
  assert_eq(
    direct_completion_test_predicate(source, "dc_ordinal_retire"),
    "lc_dc_active && lc_dc_older == 4'd0 && lc_dc_retire",
  )
  assert_eq(
    direct_completion_test_predicate(source, "dc_watched_retirement_deadline"),
    "lc_reset || !lc_dc_active\n    || lc_dc_ordinal_retire || lc_dc_age < lc_dc_checked_deadline",
  )
  assert_true(
    source.contains(
      "lc_dc_older <= lc_dc_outstanding - (lc_dc_retire ? 4'd1 : 4'd0);",
    ),
  )
  assert_true(
    source.contains(
      "lc_dc_saved_packet <= lc_dc_packet;\n        lc_dc_age <= 8'd1;",
    ),
  )
  assert_true(
    source.contains("if (lc_dc_age < 8'd255) lc_dc_age <= lc_dc_age + 8'd1;"),
  )
  assert_true(
    source.contains(
      "if (lc_dc_older != 4'd0) lc_dc_older <= lc_dc_older - 4'd1;",
    ),
  )
  assert_true(source.contains("assign lc_reset = !lc_dc_seen_edge;"))
  assert_eq(source.split("lc_dc_seen_edge <=").count(), 2)
  assert_eq(source.split(": assume (").count(), 8)
  assert_eq(changed.split(": assume (").count(), 8)
  assert_eq(direct_completion_deadline(), 7 * (4 + 28 + 2 + 2))
  assert_true(32 + 252 + 1 < 640 / 2)
}

///|
test "direct completion useful Store is a separate legal duplicate ID producer with actual paired traffic witnesses" {
  let bundle = generate_direct_completion_formal_bundle(UsefulStore)
  let source = direct_completion_test_artifact(bundle, "formal-harness.sv")
  assert_eq(source.split(": assume (").count(), 9)
  assert_eq(
    direct_completion_test_predicate(source, "dc_public_producer_sequence"),
    "lc_descriptor_valid == (!lc_reset && lc_dc_sequence_admitted < 3'd4)\n    && (!lc_descriptor_valid || lc_dc_packet == lc_dc_sequence_packet)",
  )
  let cover = direct_completion_test_predicate(source, "dc_useful_store_cover")
  assert_true(
    cover.contains("lc_dc_ordinal_retire && lc_dc_saved_packet == LC_DC_STORE"),
  )
  assert_true(cover.contains("lc_dc_sequence_exact && lc_dc_sequence_success"))
  assert_true(
    cover.contains(
      "lc_dc_sequence_admitted == 3'd4 && lc_dc_sequence_retired == 3'd3",
    ),
  )
  assert_true(cover.contains("lc_dc_useful_read_addresses == 4'd15"))
  assert_true(
    cover.contains(
      "lc_dc_useful_read_accepts == 3'd4 && lc_dc_useful_read_acks == 3'd4",
    ),
  )
  assert_true(
    cover.contains("lc_dc_useful_write_seen && lc_dc_useful_write_ack_seen"),
  )
  assert_true(cover.contains("lc_completion_fault == 4'd0"))
  for operation in ["read", "write"] {
    let accept = direct_completion_test_predicate(
      source,
      "dc_useful_" + operation + "_accept",
    )
    assert_true(accept.has_prefix("lc_dc_request_accept && !lc_dc_host_owned"))
    if operation == "read" {
      assert_true(
        accept.contains(
          "!lc_memory_request_write && lc_memory_request_bytes == 3'd1",
        ),
      )
      assert_true(
        accept.contains(
          "lc_memory_request_mask == 4'd1 && lc_memory_request_data == 32'd0",
        ),
      )
      for address in [32, 33, 64, 65] {
        assert_true(
          accept.contains("lc_memory_request_address == 32'd\{address}"),
        )
      }
    } else {
      assert_true(
        accept.contains(
          "lc_memory_request_write && lc_memory_request_address == 32'd128",
        ),
      )
      assert_true(
        accept.contains(
          "lc_memory_request_bytes == 3'd4 && lc_memory_request_mask == 4'd15",
        ),
      )
    }
    let ack = direct_completion_test_predicate(
      source,
      "dc_useful_" + operation + "_ack",
    )
    assert_true(ack.has_prefix("lc_dc_response_accept && lc_dc_host_owned"))
    assert_true(ack.contains("lc_dc_useful_owned_good_" + operation))
    assert_true(
      ack.contains(
        "lc_memory_response_tag == lc_dc_host_tag && lc_memory_response_fault == 2'd0",
      ),
    )
    assert_true(
      source.contains(
        "lc_dc_useful_owned_good_\{operation} <= lc_dc_useful_\{operation}_accept;",
      ),
    )
  }
  let engines = direct_completion_test_predicate(source, "dc_useful_engines")
  for engine in 0..<3 {
    let count = if engine == 0 { 2 } else { 1 }
    assert_true(
      engines.contains(
        "(lc_dc_engine_accept_count_\{engine} == 3'd\{count} && lc_dc_engine_collect_count_\{engine} == 3'd\{count})",
      ),
    )
    assert_true(
      source.contains(
        "if (lc_o_engine_accept_\{engine} && lc_dc_engine_accept_count_\{engine} < 3'd5)",
      ),
    )
    let collectors = direct_completion_test_predicate(
      source,
      "dc_engine_collect_" + engine.to_string(),
    )
    assert_eq(
      collectors,
      [
        for entry in 0..<3 => "lc_o_entry_collector_\{entry}_\{engine}"
      ].join(" || "),
    )
  }
  let shapes : Array[(UInt, UInt, UInt, UInt, UInt)] = [
    (1, 2, 0, 32, 2),
    (2, 1, 0, 64, 1),
    (1, 1, 2, 0, 0),
    (1, 1, 0, 128, 4),
  ]
  for index, (rows, columns, reduction, base, stride) in shapes {
    let lanes = direct_completion_packet(index)
    let bytes : Array[Byte] = []
    for lane in lanes {
      for shift in 0..<8 {
        bytes.push((lane >> (8 * shift)).to_byte())
      }
    }
    let encoded = Bytes::from_array(bytes)
    let decoded = @slotted_descriptor.decode(encoded)
    assert_eq(decoded.encode(), encoded)
    assert_eq(decoded.id, 73U)
    assert_eq(
      (
        decoded.rows,
        decoded.columns,
        decoded.reduction,
        decoded.base,
        decoded.stride,
      ),
      (rows, columns, reduction, base, stride),
    )
    assert_eq((decoded.a_slot, decoded.b_slot, decoded.c_slot), (0U, 0U, 0U))
    assert_true(
      match (index, decoded.opcode) {
        (0, LoadA) | (1, LoadB) | (2, MatMul) | (3, StoreC) => true
        _ => false
      },
    )
    assert_true(
      base + (rows - 1) * stride + columns * (if index == 3 { 4U } else { 1U }) <=
      1024U,
    )
    assert_true(
      source.contains(
        "LC_DC_SEQUENCE_\{index} = " +
        direct_completion_packet_literal(index) +
        ";",
      ),
    )
  }
  // Validate the intended compute shape independently. The formal response
  // data remains symbolic; this does not claim numerical Store correctness.
  assert_eq(
    @flux_tile.matmul_int8_oracle(
      [2, 3],
      [5, 7],
      rows=1,
      columns=1,
      reduction=2,
    ),
    [31],
  )
  try direct_completion_packet(4) catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("wrong canonical packet index rejection")
  } noraise {
    _ => fail("unknown canonical packet index accepted")
  }
}
