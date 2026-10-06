///|
fn queue_formal_artifact(
  bundle : @formal.QueueFormalBundle,
  path : String,
) -> String raise {
  let selected = bundle.artifacts().filter(item => item.path() == path)
  assert_eq(selected.length(), 1)
  selected[0].content()
}

///|
fn queue_formal_expected_binding(
  role : @flux_tile.QueueConservationRole,
) -> (String, @ir.SignalType) raise {
  let (name, width, unsigned) = match role {
    FifoPushValid(i) => ("fifo_push_valid_\{i}", 1, false)
    FifoPushReady(i) => ("fifo_push_ready_\{i}", 1, false)
    FifoPopRequest(i) => ("fifo_pop_request_\{i}", 1, false)
    FifoPopReady(i) => ("fifo_pop_ready_\{i}", 1, false)
    FifoResponseValid(i) => ("fifo_response_valid_\{i}", 1, false)
    FifoResponseData(i) => ("fifo_response_data_\{i}", 64, false)
    FifoOccupancy(i) => ("fifo_occupancy_\{i}", 2, true)
    FifoFull(i) => ("fifo_full_\{i}", 1, false)
    FifoEmpty(i) => ("fifo_empty_\{i}", 1, false)
    HeadLane(i) => ("head_lane_\{i}", 64, false)
    HeadState => ("head_state", 2, true)
    HeadEntry => ("head_entry", 5, true)
    HeadTicket => ("head_ticket", 32, true)
    NextTicket => ("next_ticket", 32, true)
    HeadReserve => ("head_reserve", 1, false)
    HeadPop => ("head_pop", 1, false)
    HeadCapture => ("head_capture", 1, false)
    HeadIssue => ("head_issue", 1, false)
    HeadFinish => ("head_finish", 1, false)
    HeadReject => ("head_reject", 1, false)
    HeadFence => ("head_fence", 1, false)
    HeadLocalFault => ("head_local_fault", 4, true)
    RetirementReadPointer => ("retirement_read_pointer", 5, true)
    RetirementWritePointer => ("retirement_write_pointer", 5, true)
    RetirementOccupancy => ("retirement_occupancy", 5, true)
    RetirementFire => ("retirement_fire", 1, false)
    RetirementValid => ("retirement_valid", 1, false)
    RetirementId => ("retirement_id", 32, true)
    RetirementFault => ("retirement_fault", 4, true)
    RetirementProgress => ("retirement_progress", 32, true)
    RetirementAddress => ("retirement_address", 32, true)
    EntryValid(i) => ("entry_valid_\{i}", 1, false)
    EntryTerminal(i) => ("entry_terminal_\{i}", 1, false)
    EntryTicket(i) => ("entry_ticket_\{i}", 32, true)
    EntryId(i) => ("entry_id_\{i}", 32, true)
    EntryFault(i) => ("entry_fault_\{i}", 4, true)
    EntryProgress(i) => ("entry_progress_\{i}", 32, true)
    EntryAddress(i) => ("entry_address_\{i}", 32, true)
    EntryAllocate(i) => ("entry_allocate_\{i}", 1, false)
    EntryAcknowledge(i) => ("entry_acknowledge_\{i}", 1, false)
    EntryLocalTerminal(i) => ("entry_local_terminal_\{i}", 1, false)
    EntryCollector(i, e) => ("entry_collector_\{i}_\{e}", 1, false)
    EngineAccept(i) => ("engine_accept_\{i}", 1, false)
    EngineState(i) => ("engine_state_\{i}", if i == 1 { 2 } else { 3 }, true)
    EngineTicket(i) => ("engine_ticket_\{i}", 32, true)
    EngineTerminal(i) => ("engine_terminal_\{i}", 1, false)
    EngineFault(i) => ("engine_fault_\{i}", 4, true)
  }
  match role {
    FifoPushValid(i)
    | FifoPushReady(i)
    | FifoPopRequest(i)
    | FifoPopReady(i)
    | FifoResponseValid(i)
    | FifoResponseData(i)
    | FifoOccupancy(i)
    | FifoFull(i)
    | FifoEmpty(i)
    | HeadLane(i) => assert_true(i >= 0 && i < 4)
    EntryValid(i)
    | EntryTerminal(i)
    | EntryTicket(i)
    | EntryId(i)
    | EntryFault(i)
    | EntryProgress(i)
    | EntryAddress(i)
    | EntryAllocate(i)
    | EntryAcknowledge(i)
    | EntryLocalTerminal(i)
    | EngineAccept(i)
    | EngineState(i)
    | EngineTicket(i)
    | EngineTerminal(i)
    | EngineFault(i) => assert_true(i >= 0 && i < 3)
    EntryCollector(i, e) => {
      assert_true(i >= 0 && i < 3)
      assert_true(e >= 0 && e < 3)
    }
    _ => ()
  }
  (name, if unsigned { @wire.uint(width) } else { @wire.bits(width) })
}

///|
fn queue_formal_check_task(
  bundle : @formal.QueueFormalBundle,
  gate : @formal.GateTask,
  properties : @formal_core.FormalPropertyManifest,
  selected : ArrayView[String],
  cover~ : Bool,
  negative~ : Bool,
) -> Unit raise {
  assert_eq(gate.bound(), 256)
  assert_eq(gate.timeout_seconds(), 600)
  assert_eq(gate.expected_status(), if negative { "fail" } else { "pass" })
  assert_eq(
    gate.task_class(),
    if cover {
      BoundedCoverTask
    } else {
      BoundedSafetyTask
    },
  )
  assert_eq(
    @formal_core.parse_proof_task(gate.task().to_canonical_text()),
    gate.task(),
  )
  @formal.verify_task_property_binding(gate.task(), properties)
  guard gate.task() is Bounded(task) else {
    fail("queue supporting task must remain bounded")
  }
  assert_eq(task.mode(), if cover { BoundedCover } else { BoundedSafety })
  assert_eq(task.engine(), "smtbmc-bitwuzla")
  let source_set = queue_formal_artifact(bundle, "source-set.lcfs")
  let digest = @crypto.bytes_to_hex_string(
    @crypto.sha256(@utf8.encode(source_set)),
  )
  let encoded_name = @crypto.bytes_to_hex_string(
    @utf8.encode("source-set.lcfs"),
  )
  assert_true(
    gate
    .task()
    .to_canonical_text()
    .contains("ARTIFACT \{encoded_name} sha256 \{digest}\n"),
  )
  let mode = if cover { "cover" } else { "bmc" }
  let claim = if cover {
    "reachability-within-bound"
  } else {
    "bounded-safety-up-to-bound"
  }
  let expect = if negative { "fail" } else { "pass" }
  assert_true(
    bundle
    .job_json()
    .contains(
      "{\"name\": \"\{gate.name()}\", \"mode\": \"\{mode}\", \"claim\": \"\{claim}\", \"bound\": 256, \"timeout_seconds\": 600, \"engine\": \"smtbmc\", \"solver\": \"bitwuzla\", \"expect\": \"\{expect}\"}",
    ),
  )
  assert_eq(task.properties(), ReadOnlyArray::from_array(selected))
  let legal = ReadOnlyArray::from_array(
    properties.properties()[0:4].map(item => item.stable_name()),
  )
  assert_eq(task.assumptions(), legal)
  guard task.timing_contract() is Some(timing) else {
    fail("queue supporting task requires explicit clock timing")
  }
  assert_eq(timing.global_timestep().steps(), 2)
  assert_eq(timing.clocks().length(), 1)
  assert_eq(timing.clocks()[0].edge(), Rising)
  assert_eq(
    timing.clocks()[0].signal(),
    @property.PropertySignal::named("lc_formal_queue_top", "clock"),
  )
  assert_eq(timing.legal_transition_assumptions(), legal)
  assert_eq(timing.fairness_assumptions().length(), 0)
  assert_eq(timing.coincidence_policy(), AtomicGlobalPreState)
  assert_eq(
    queue_formal_artifact(bundle, gate.name() + ".lcft"),
    gate.task().to_canonical_text(),
  )
  let execution = queue_formal_artifact(bundle, gate.name() + ".lcfg")
  assert_true(
    execution.contains("BOUND-MAPPING 256-global-steps-128-dut-clocks\n"),
  )
  assert_true(execution.contains("TIMING-CONTRACT formal-task-schema-2\n"))
  assert_true(execution.contains("TIMEOUT-SECONDS 600\n"))
  assert_true(execution.contains("SELECTED-ASSUMPTIONS 4\n"))
  assert_true(execution.contains("SELECTED-PROPERTIES \{selected.length()}\n"))
  for index, label in selected {
    assert_true(execution.contains("P \{index} \{label}\n"))
  }
  for index, label in legal {
    assert_true(execution.contains("A \{index} \{label}\n"))
  }
}

///|
test "queue formal export binds actual typed nodes and isolates bounded population sensitivity" {
  // Source-contract checks only: generated tasks and expected statuses are not
  // proof, cover-witness or negative-control execution results.
  let bundles = @formal.standard_queue_formal_bundles()
  assert_eq(bundles.length(), 6)
  let valid = bundles[0]
  let negative = bundles[1]
  assert_eq(valid.fixture(), Conservation)
  assert_eq(negative.fixture(), NegativePopulation)
  // This test preserves the two original profiles; the additive record profiles
  // have their own complete export-contract test.
  for bundle in [valid, negative] {
    assert_eq(bundle, @formal.generate_queue_formal_bundle(bundle.fixture()))
    assert_eq(
      @formal.QueueFormalFixture::from_id(bundle.fixture().id()),
      Some(bundle.fixture()),
    )
    let paths = bundle.artifacts().map(item => item.path())
    assert_eq(
      paths.length(),
      if bundle.fixture() is Conservation {
        11
      } else {
        9
      },
    )
    for index, path in paths {
      assert_false(paths[0:index].contains(path))
    }
    assert_eq(queue_formal_artifact(bundle, "job.json"), bundle.job_json())
    assert_eq(
      @formal.regenerate_formal_artifacts(
        queue_formal_artifact(bundle, "source-set.lcfs"),
      ),
      bundle.artifacts(),
    )
  }
  assert_eq(valid.fixture().id(), "phase6-queue-conservation")
  assert_eq(negative.fixture().id(), "phase6-queue-negative-population")
  assert_eq(
    @formal.QueueFormalFixture::from_id("phase6-dependency-latest-writer"),
    None,
  )
  assert_eq(
    @formal.QueueFormalFixture::from_id("phase6-flux-tile-public-transport"),
    None,
  )
  for
    (family, id) in [
      ("flux-tile-dependency", valid.fixture().id()),
      ("flux-tile-public-transport", valid.fixture().id()),
      ("flux-tile-queue-conservation", "phase6-dependency-latest-writer"),
      ("flux-tile-queue-conservation", "phase6-flux-tile-public-transport"),
    ] {
    try
      @formal.regenerate_formal_artifacts(
        "LUNACHIP-PHASE6-FORMAL-SOURCE-SET 1\nFAMILY \{family}\nFIXTURE \{id}\n",
      )
    catch {
      @formal.InvalidFormalBundleIdentity(_) => ()
      _ => fail("unexpected cross-family registry rejection")
    } noraise {
      _ => fail("cross-family queue source set was accepted")
    }
  }
  let design = @ir_codec.parse(queue_formal_artifact(valid, "design.lcir"))
  assert_eq(design.name(), "QueuedConcurrentQueueConservationPilot")
  let view = @flux_tile.queued_concurrent_queue_formal_fixture()
  let expected_design = @ir.Design::single(
    "QueuedConcurrentQueueConservationPilot",
    view.hardware(),
  )
  // Canonical IR sorts outputs; ordinary emission retains construction order.
  assert_eq(
    queue_formal_artifact(valid, "design.lcir"),
    @ir_codec.serialize(expected_design),
  )
  assert_eq(@ir_codec.serialize(design), @ir_codec.serialize(expected_design))
  let emitted = @rtl.emit_design(expected_design)
  let production = emitted.modules()[0]
  let production_path = "production-" + production.filename()
  assert_eq(queue_formal_artifact(valid, production_path), production.source())
  assert_false(production.source().contains("lc_formal_observe_"))
  let adapter = queue_formal_artifact(valid, "formal-dut.sv")
  let harness = queue_formal_artifact(valid, "formal-harness.sv")
  let source_set = queue_formal_artifact(valid, "source-set.lcfs")
  let public_ports = emitted
    .manifest()
    .mappings()
    .filter(mapping => {
      mapping.module_ordinal() == emitted.manifest().top_module_ordinal() &&
      (mapping.kind() is InputPort || mapping.kind() is OutputPort)
    })
  assert_true(public_ports.length() > 0)
  for mapping in public_ports {
    assert_eq(
      harness
      .split(".\{mapping.identifier()}(lc_\{mapping.source_name()})")
      .length(),
      2,
    )
  }
  assert_eq(view.observations().length(), 115)
  assert_eq(source_set.split("OBSERVATION ").length(), 116)
  for index, reference in view.observations() {
    let (name, signal_type) = queue_formal_expected_binding(reference.role())
    assert_eq(reference.signal_type(), signal_type)
    for prior in view.observations()[0:index] {
      assert_true(prior.role() != reference.role())
    }
    guard view.hardware().node(reference.node()) is Some(node) else {
      fail("queue binding lacks its actual canonical node")
    }
    assert_eq(node.signal_type(), signal_type)
    let mappings = emitted
      .manifest()
      .mappings()
      .filter(mapping => {
        mapping.kind() is Node &&
        mapping.module_ordinal() == emitted.manifest().top_module_ordinal() &&
        mapping.local_ordinal() == reference.node().ordinal()
      })
    assert_eq(mappings.length(), 1)
    let assignment = "assign lc_formal_observe_\{name} = \{mappings[0].identifier()};"
    assert_eq(adapter.split(assignment).length(), 2)
    assert_eq(
      harness.split(".lc_formal_observe_\{name}(lc_o_\{name})").length(),
      2,
    )
    let kind = match signal_type {
      UInt(_) => "UInt"
      Bits(_) => "Bits"
      _ => fail("unexpected queue binding type")
    }
    assert_true(
      source_set.contains(
        "OBSERVATION \{name} node \{reference.node().ordinal()} width \{signal_type.width().bits()} type \{kind}\n",
      ),
    )
  }
  assert_eq(valid.top_identifier(), "lc_formal_queue_top")
  assert_true(valid.job_json().contains("formal-dut.sv"))
  assert_false(valid.job_json().contains(production_path))
  for
    required in [
      "FAMILY flux-tile-queue-conservation\n", "GLOBAL-TIMESTEP engine-steps 2\n",
      "CLOCK-CONTRACT one-toggle-per-global-step-one-rising-edge-per-two-steps\n",
      "PILOT-BOUND global-steps 256 dut-clocks 128\n", "FAIRNESS none\n", "RESET initial-joint-reset-later-symbolic-joint-peer-response-flush\n",
      "HOST symbolic-raw-descriptors-responses-including-malformed\n", "GHOST outstanding-from-public-descriptor-accept-and-public-completion-retire-only\n",
      "no-saved-packet-engine-ownership-leases-ticket-wrap-liveness-fetched-or-full-product-proof\n",
    ] {
    assert_true(source_set.contains(required))
  }
  let properties = @formal_core.parse_formal_property_manifest(
    queue_formal_artifact(valid, "properties.lcfp"),
  )
  assert_eq(properties.properties().map(item => item.name()), [
    "initial_joint_reset", "host_descriptor_stable_until_accept", "host_response_stable_until_accept",
    "host_response_flushed_during_reset", "lane_atomicity_and_response", "packet_population_conserved",
    "retirement_event_ownership", "reachable_full_refill_capture",
  ])
  for index, item in properties.properties() {
    assert_eq(item.domain().point(), PreEdge)
    assert_eq(
      item.predicate(),
      @property.PropertySignal::named("lc_formal_queue_top", item.name()),
    )
    assert_eq(
      item.domain().clock(),
      @property.PropertySignal::named("lc_formal_queue_top", "clock"),
    )
    assert_eq(
      item.kind(),
      if index < 4 {
        Assumption
      } else if index < 7 {
        Assertion
      } else {
        Cover
      },
    )
  }
  let assertions = properties.properties()[4:7].map(item => item.stable_name())
  let population = properties.properties()[5].stable_name()
  let cover = properties.properties()[7].stable_name()
  assert_eq(valid.expected_failure(), "none")
  assert_eq(valid.tasks().length(), 2)
  assert_eq(valid.tasks()[0].name(), "phase6-queue-conservation-bmc")
  assert_eq(
    valid.tasks()[1].name(),
    "phase6-queue-conservation-cover-full-refill-capture",
  )
  queue_formal_check_task(
    valid,
    valid.tasks()[0],
    properties,
    assertions,
    cover=false,
    negative=false,
  )
  queue_formal_check_task(
    valid,
    valid.tasks()[1],
    properties,
    [cover],
    cover=true,
    negative=false,
  )
  assert_eq(negative.tasks().length(), 1)
  assert_eq(negative.tasks()[0].name(), "phase6-queue-negative-population-bmc")
  assert_eq(negative.expected_failure(), population)
  queue_formal_check_task(
    negative,
    negative.tasks()[0],
    properties,
    [population],
    cover=false,
    negative=true,
  )
  for
    path in ["design.lcir", production_path, "formal-dut.sv", "properties.lcfp"] {
    assert_eq(
      queue_formal_artifact(negative, path),
      queue_formal_artifact(valid, path),
    )
  }
  let negative_harness = queue_formal_artifact(negative, "formal-harness.sv")
  let original = "  wire [4:0] lc_checked_retirement_population = lc_o_retirement_occupancy;\n"
  let changed = "  wire [4:0] lc_checked_retirement_population = lc_o_retirement_occupancy + (lc_mutate_population ? 5'd1 : 5'd0);\n"
  assert_eq(harness.split(original).length(), 2)
  assert_eq(negative_harness.split(changed).length(), 2)
  assert_eq(negative_harness.replace(old=changed, new=original), harness)
  assert_eq(harness.split(": assume (").length(), 5)
  assert_eq(harness.split(": assert (").length(), 4)
  assert_eq(harness.split(": cover (").length(), 2)
  assert_true(
    harness.contains("always @($global_clock) lc_clock <= ~lc_clock;"),
  )
  assert_true(harness.contains("always_ff @(posedge lc_clock)"))
  assert_true(harness.contains("lc_raw_population_relation"))
  assert_false(harness.contains("lc_dut."))
  for
    required in [
      "wire lc_queue_admit = lc_descriptor_valid && lc_descriptor_ready;", "wire lc_queue_retire = lc_completion_valid && lc_completion_ready;",
      "logic [3:0] lc_queue_outstanding = 4'd0;", "lc_queue_outstanding <= 4'd0;",
      "case ({lc_queue_admit, lc_queue_retire})", "2'b10: lc_queue_outstanding <= lc_queue_outstanding + 4'd1;",
      "2'b01: lc_queue_outstanding <= lc_queue_outstanding - 4'd1;", "default: lc_queue_outstanding <= lc_queue_outstanding;",
      "lc_expected_response_valid <= lc_o_head_pop;", "wire lc_mutate_population = !lc_reset && lc_queue_admission_seen\n    && lc_queue_reservation_seen && lc_o_retirement_occupancy != 5'd0\n    && lc_raw_population_relation;",
      "lc_previous_full_refill <= lc_o_fifo_occupancy_0 == 2'd3\n        && lc_queue_admit && lc_o_head_pop;",
      "wire lc_reachable_full_refill_capture = !lc_reset && lc_previous_full_refill\n    && lc_o_head_capture && lc_o_fifo_response_valid_0 && lc_o_fifo_response_valid_1 && lc_o_fifo_response_valid_2 && lc_o_fifo_response_valid_3;",
    ] {
    assert_true(harness.contains(required))
  }
  for entry in 0..<3 {
    assert_true(
      harness.contains(
        "(!lc_o_entry_acknowledge_\{entry} || (lc_o_entry_valid_\{entry} && lc_o_entry_terminal_\{entry}))",
      ),
    )
  }
  for item in properties.properties() {
    assert_true(harness.contains(item.stable_name() + ": "))
    assert_true(negative_harness.contains(item.stable_name() + ": "))
  }
}
