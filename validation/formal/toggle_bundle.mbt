///|
fn toggle_completion_bound(stages : Int32) -> Int32 {
  let maximum_clock_gap_intervals = 4
  let eventual_ready_destination_edges = stages + 1
  maximum_clock_gap_intervals * (stages + eventual_ready_destination_edges + 1)
}

///|
fn toggle_expected_failure(
  fixture : ToggleFormalFixture,
  properties : @formal_core.FormalPropertyManifest,
) -> String raise FormalGateError {
  let expected_name = match fixture {
    ValidToggleScalar2 | ValidToggleRecord3 | ValidToggleRecord4 =>
      return "none"
    BrokenToggleCapacity => "one_item_in_flight_capacity"
    BrokenToggleSourcePayload => "source_payload_stable_while_outstanding"
    BrokenToggleBackpressure => "destination_response_stable_under_backpressure"
    BrokenToggleDuplicate => "no_duplicate_acknowledge_or_consume"
    BrokenToggleDataIntegrity => "watched_transaction_data_integrity"
    BrokenToggleCompletion =>
      "watched_transaction_completes_under_bounded_clocks_and_eventual_ready"
  }
  for property in properties.properties() {
    if property.name() == expected_name {
      return property.stable_name()
    }
  }
  raise InvalidToggleHandshakeBundle(
    "toggle property manifest omitted its expected stable label",
  )
}

///|
fn toggle_timing_contract(
  source_domain : @ir.ClockDomainId,
  destination_domain : @ir.ClockDomainId,
  legal : ReadOnlyArray[String],
  fairness : ReadOnlyArray[String],
) -> @formal_core.FormalTimingContract raise FormalGateError {
  let path = "lc_formal_toggle_top"
  let source_signal = named_signal(path, "source_clock")
  let destination_signal = named_signal(path, "destination_clock")
  let source_clock = @formal_core.FormalClockBinding::checked(
    source_domain,
    source_signal,
    Rising,
  ) catch {
    error => raise FormalContract(error)
  }
  let destination_clock = @formal_core.FormalClockBinding::checked(
    destination_domain,
    destination_signal,
    Rising,
  ) catch {
    error => raise FormalContract(error)
  }
  @formal_core.FormalTimingContract::checked(
    @formal_core.GlobalFormalTimestep::checked(2),
    [source_clock, destination_clock],
    legal,
    fairness,
    AtomicGlobalPreState,
  ) catch {
    error => raise FormalContract(error)
  }
}

///|
fn toggle_tasks(
  fixture : ToggleFormalFixture,
  source_artifact : @formal_core.ArtifactRef,
  timing : @formal_core.FormalTimingContract,
  assumptions : ReadOnlyArray[String],
  assertions : ReadOnlyArray[String],
  covers : ReadOnlyArray[String],
  completion_bound : Int32,
) -> ReadOnlyArray[GateTask] raise FormalGateError {
  let tool = formal_tool()
  let tasks : Array[GateTask] = []
  // The completion mutant must first establish a watched transfer and then
  // retain it for the full completion age after coordinated reset/settling.
  // Keep the wider search local to that negative task.
  let bmc_bound = if fixture is BrokenToggleCompletion {
    completion_bound + 68
  } else {
    completion_bound + 32
  }
  let bmc_name = fixture.id() + "-bmc"
  let bmc = @formal_core.BoundedProofTask::checked(
    bmc_name,
    source_artifact,
    tool,
    "smtbmc-bitwuzla",
    BoundedSafety,
    @formal_core.ProofBound::checked(bmc_bound),
    assumptions,
    assertions,
  ).with_timing_contract(timing) catch {
    error => raise FormalContract(error)
  }
  tasks.push({
    name: bmc_name,
    task: Bounded(bmc),
    task_class: BoundedSafetyTask,
    bound: bmc_bound,
    timeout_seconds: 600,
    expected_status: if fixture.is_valid() {
      "pass"
    } else {
      "fail"
    },
  })
  if fixture is ValidToggleRecord3 {
    let cover_suffixes = ["coincident", "consume-refill", "watched"]
    for index, label in covers {
      let name = fixture.id() + "-cover-" + cover_suffixes[index]
      let cover_bound = if index == 0 { bmc_bound } else { 96 }
      let cover = @formal_core.BoundedProofTask::checked(
        name,
        source_artifact,
        tool,
        "smtbmc-bitwuzla",
        BoundedCover,
        @formal_core.ProofBound::checked(cover_bound),
        assumptions,
        [label],
      ).with_timing_contract(timing) catch {
        error => raise FormalContract(error)
      }
      tasks.push({
        name,
        task: Bounded(cover),
        task_class: BoundedCoverTask,
        bound: cover_bound,
        timeout_seconds: 600,
        expected_status: "pass",
      })
    }
  }
  ReadOnlyArray::from_array(tasks)
}

///|
fn toggle_source_set(
  fixture : ToggleFormalFixture,
  design_ir : String,
  dut : ToggleFormalDut,
  harness : String,
  property_manifest : String,
  completion_bound : Int32,
) -> String {
  "LUNACHIP-PHASE5-FORMAL-SOURCE-SET 1\n" +
  "FAMILY toggle-handshake\n" +
  "FIXTURE \{fixture.id()}\n" +
  "TOP lc_formal_toggle_top\n" +
  "PAYLOAD \{if fixture.has_record_payload() { "record-word8-tag3" } else { "scalar-word8" }}\n" +
  "SYNCHRONIZER-STAGES \{fixture.stage_count()}\n" +
  "CLOCK-CONTRACT bounded-fair-pulses\n" +
  "GLOBAL-TIMESTEP engine-steps 2\n" +
  "CLOCK-MAX-IDLE-INTERVALS 3\n" +
  "EVENTUAL-READY-MAX-DESTINATION-EDGES \{fixture.stage_count() + 1}\n" +
  "COMPLETION-BOUND scheduling-intervals \{completion_bound} formula 4*(stages+(stages+1)+1)\n" +
  "COINCIDENCE atomic-global-pre-state\n" +
  "RESET coordinated-idle-initialization-unilateral-reset-excluded\n" +
  "CLAIM-BOUNDARY digital-two-state-bounded-no-metastability-mtbf-placement-reset-recovery-or-timing\n" +
  "ADDRESS-KNOWNNESS two-state-formal-all-binary\n" +
  "IR design.lcir sha256 \{sha256_hex(design_ir)}\n" +
  "SOURCE \{dut.filename()} sha256 \{sha256_hex(dut.source())}\n" +
  "SOURCE formal-harness.sv sha256 \{sha256_hex(harness)}\n" +
  "PROPERTIES properties.lcfp sha256 \{sha256_hex(property_manifest)}\n" +
  "END\n"
}

///|
fn toggle_job_json(
  dut : ToggleFormalDut,
  harness : String,
  tasks : ReadOnlyArray[GateTask],
) -> String {
  let out = StringBuilder()
  out.write_string("{\n")
  out.write_string(
    "  \"$schema\": \"https://lunachip.dev/schema/yosys-job-v1.json\",\n",
  )
  out.write_string("  \"schema_version\": \"lunachip.yosys-job/v1\",\n")
  out.write_string("  \"top_module\": \"lc_formal_toggle_top\",\n")
  out.write_string("  \"sources\": [\n")
  out.write_string(
    "    {\"path\": \"\{dut.filename()}\", \"sha256\": \"\{sha256_hex(dut.source())}\"},\n",
  )
  out.write_string(
    "    {\"path\": \"formal-harness.sv\", \"sha256\": \"\{sha256_hex(harness)}\"}\n",
  )
  out.write_string("  ],\n  \"formal_tasks\": [\n")
  for index, task in tasks {
    out.write_string(
      "    {\"name\": \"\{task.name()}\", \"mode\": \"\{job_mode(task.task_class())}\", \"claim\": \"\{job_claim(task.task_class())}\", \"bound\": \{task.bound()}, \"timeout_seconds\": \{task.timeout_seconds()}, \"engine\": \"smtbmc\", \"solver\": \"bitwuzla\", \"expect\": \"\{task.expected_status()}\"}",
    )
    out.write_string(if index + 1 == tasks.length() { "\n" } else { ",\n" })
  }
  out.write_string("  ]\n}\n")
  out.to_string()
}

///|
fn toggle_execution_manifest(
  task : GateTask,
  expected_failure : String,
  job_manifest : String,
  property_manifest : String,
  source_identity : String,
  stages : Int32,
  completion_bound : Int32,
) -> String {
  let (selected_assumptions, selected_properties) = match task.task() {
    Bounded(value) => (value.assumptions(), value.properties())
    Unbounded(value) => (value.assumptions(), value.properties())
  }
  let selections = StringBuilder()
  selections.write_string(
    "SELECTED-ASSUMPTIONS \{selected_assumptions.length()}\n",
  )
  for index, label in selected_assumptions {
    selections.write_string("A \{index} \{label}\n")
  }
  selections.write_string(
    "SELECTED-PROPERTIES \{selected_properties.length()}\n",
  )
  for index, label in selected_properties {
    selections.write_string("P \{index} \{label}\n")
  }
  let failure = if task.task_class() is BoundedCoverTask {
    "none"
  } else {
    expected_failure
  }
  "LUNACHIP-PHASE5-FORMAL-EXECUTION 1\n" +
  "TASK \{task.name()} sha256 \{sha256_hex(task.task().to_canonical_text())}\n" +
  "JOB job.json sha256 \{sha256_hex(job_manifest)}\n" +
  "PROPERTIES properties.lcfp sha256 \{sha256_hex(property_manifest)}\n" +
  "SOURCE-SET source-set.lcfs sha256 \{sha256_hex(source_identity)}\n" +
  "MODE \{job_mode(task.task_class())}\n" +
  "CLAIM \{job_claim(task.task_class())}\n" +
  "BOUND \{task.bound()}\n" +
  "TIMEOUT-SECONDS \{task.timeout_seconds()}\n" +
  "ENGINE smtbmc\n" +
  "SOLVER bitwuzla\n" +
  "MULTICLOCK on\n" +
  "ADDRESS-KNOWNNESS two-state-formal-all-binary\n" +
  "TIMING-CONTRACT formal-task-schema-2\n" +
  "COMPLETION-BOUND-DERIVATION 4*(\{stages}+(\{stages}+1)+1)=\{completion_bound}-scheduling-intervals\n" +
  selections.to_string() +
  "EXPECTED-STATUS \{task.expected_status()}\n" +
  "EXPECTED-FAILURE \{failure}\n" +
  "RUNNER scripts/phase4-yosys-run.sh oci formal \{task.name()} BUNDLE OUTPUT\n" +
  "END\n"
}

///|
pub fn generate_toggle_formal_bundle(
  fixture : ToggleFormalFixture,
) -> ToggleFormalBundle raise {
  let built = toggle_formal_design(fixture)
  let design = built.design
  let design_ir = @ir_codec.serialize(design)
  guard design.top_module() is Some(hardware_module) else {
    raise MissingTopModule
  }
  guard hardware_module.domains() is [source_domain, destination_domain] else {
    raise InvalidToggleHandshakeBundle(
      "formal toggle handshake must expose exactly two domains",
    )
  }
  if built.primitive.request_stages().length() != fixture.stage_count() ||
    built.primitive.acknowledge_stages().length() != fixture.stage_count() {
    raise InvalidToggleHandshakeBundle("formal synchronizer depth drifted")
  }
  let emitted = @rtl.emit_design(design)
  let production_dut = top_emitted_module(emitted)
  let dut = toggle_formal_dut(fixture, design, emitted, production_dut)
  let (property_export, legal, fairness, assumptions, assertions, covers) = toggle_property_export()
  let completion_bound = toggle_completion_bound(fixture.stage_count())
  let harness = toggle_harness(
    fixture,
    emitted,
    dut,
    property_export.source(),
    completion_bound,
  )
  let property_manifest = property_export.manifest()
  let source_identity = toggle_source_set(
    fixture, design_ir, dut, harness, property_manifest, completion_bound,
  )
  let source_artifact = checked_artifact(
    "source-set.lcfs",
    sha256_hex(source_identity),
  )
  let timing = toggle_timing_contract(
    source_domain.id(),
    destination_domain.id(),
    legal,
    fairness,
  )
  let tasks = toggle_tasks(
    fixture, source_artifact, timing, assumptions, assertions, covers, completion_bound,
  )
  validate_task_bindings(tasks, assumptions, assertions, covers)
  let expected_failure = toggle_expected_failure(
    fixture,
    property_export.property_manifest(),
  )
  let artifacts : Array[FormalBundleArtifact] = [
    { path: "design.lcir", content: design_ir, },
    { path: dut.filename(), content: dut.source(), },
    { path: "formal-harness.sv", content: harness, },
    { path: "properties.lcfp", content: property_manifest, },
    { path: "source-set.lcfs", content: source_identity, },
  ]
  for task in tasks {
    artifacts.push({
      path: task.name() + ".lcft",
      content: task.task().to_canonical_text(),
    })
  }
  let manifest = toggle_job_json(dut, harness, tasks)
  artifacts.push({ path: "job.json", content: manifest, })
  for task in tasks {
    artifacts.push({
      path: task.name() + ".lcfg",
      content: toggle_execution_manifest(
        task,
        expected_failure,
        manifest,
        property_manifest,
        source_identity,
        fixture.stage_count(),
        completion_bound,
      ),
    })
  }
  {
    fixture,
    artifacts: ReadOnlyArray::from_array(artifacts),
    tasks,
    job_json: manifest,
    top_identifier: "lc_formal_toggle_top",
    expected_failure,
    completion_bound,
  }
}

///|
pub fn standard_toggle_formal_bundles() -> ReadOnlyArray[ToggleFormalBundle] raise {
  ReadOnlyArray::from_array([
    generate_toggle_formal_bundle(ValidToggleScalar2),
    generate_toggle_formal_bundle(ValidToggleRecord3),
    generate_toggle_formal_bundle(ValidToggleRecord4),
    generate_toggle_formal_bundle(BrokenToggleCapacity),
    generate_toggle_formal_bundle(BrokenToggleSourcePayload),
    generate_toggle_formal_bundle(BrokenToggleBackpressure),
    generate_toggle_formal_bundle(BrokenToggleDuplicate),
    generate_toggle_formal_bundle(BrokenToggleDataIntegrity),
    generate_toggle_formal_bundle(BrokenToggleCompletion),
  ])
}
