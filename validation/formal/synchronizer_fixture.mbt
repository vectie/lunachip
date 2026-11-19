///|
fn synchronizer_design() -> @ir.Design raise {
  let builder = @wire.ModuleBuilder::new("FormalThreeStageSynchronizer")
  let source_clock = builder.input("source_clock", @wire.clock())
  let source_domain = builder.rising_edge(source_clock)
  let source_input = builder.input("source", @wire.bits(1))
  let destination_clock = builder.input("destination_clock", @wire.clock())
  let destination_domain = builder.rising_edge(destination_clock)
  let reset_signal = builder.input("reset", @wire.reset())
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  builder.input_timing(source_input, SampledIn(source_domain.id()))
  builder.input_timing(reset_signal, SampledIn(destination_domain.id()))
  let source = builder.register_in(source_domain, source_input)
  let synchronized = builder.bit_synchronizer(
    "synchronizer",
    source,
    destination_domain,
    3,
    source_domain~,
    reset~,
  )
  let output = builder.output("synchronized", @wire.bits(1))
  builder.output_timing(output, ProducedIn(destination_domain.id()))
  builder.connect(output, synchronized)
  @ir.Design::single("phase5-formal-three-stage-synchronizer", builder.finish())
}

///|
fn emitted_node_identifier(
  emitted : @rtl.EmittedDesign,
  ordinal : Int32,
) -> String raise FormalGateError {
  let top = emitted.manifest().top_module_ordinal()
  let mut found : String? = None
  for mapping in emitted.manifest().mappings() {
    if mapping.module_ordinal() == top &&
      mapping.kind() == Node &&
      mapping.local_ordinal() == ordinal {
      if found is Some(_) {
        raise DuplicatePort(kind="node", name="\{ordinal}")
      }
      found = Some(mapping.identifier())
    }
  }
  guard found is Some(identifier) else {
    raise MissingPort(kind="node", name="\{ordinal}")
  }
  identifier
}

///|
fn synchronizer_property_export() -> (
  @formal_core.FormalExport,
  ReadOnlyArray[String],
  ReadOnlyArray[String],
  ReadOnlyArray[String],
  ReadOnlyArray[String],
) raise FormalGateError {
  let path = "lc_formal_synchronizer_top"
  let observer = named_signal(path, "formal_step_clock")
  let domain = @formal_core.ObservationDomain::rising_pre_edge(observer) catch {
    error => raise FormalContract(error)
  }
  let definitions : Array[(String, @formal_core.FormalPropertyKind, String)] = [
    (
      "source_clock_transition_legal",
      Assumption,
      "source_clock_transition_legal",
    ),
    (
      "destination_clock_transition_legal",
      Assumption,
      "destination_clock_transition_legal",
    ),
    ("source_clock_fair", Assumption, "source_clock_fair"),
    ("destination_clock_fair", Assumption, "destination_clock_fair"),
    (
      "pipeline_matches_previous_destination_samples",
      Assertion,
      "pipeline_matches_previous_destination_samples",
    ),
    (
      "synchronous_reset_clears_all_stages",
      Assertion,
      "synchronous_reset_clears_all_stages",
    ),
    (
      "output_changes_only_on_destination_edge",
      Assertion,
      "output_changes_only_on_destination_edge",
    ),
    (
      "stable_source_converges_within_three_destination_edges",
      Assertion,
      "stable_source_converges_within_three_destination_edges",
    ),
    ("coincident_source_destination_edge", Cover, "coincident_edge"),
  ]
  let properties : Array[@formal_core.FormalProperty] = []
  for index, definition in definitions {
    let (name, kind, predicate) = definition
    properties.push(
      checked_formal_property(
        property_id(index),
        name,
        kind,
        named_signal(path, predicate),
        domain,
        NeverDisabled,
      ),
    )
  }
  let plan = @formal_core.FormalPropertyPlan::checked(properties) catch {
    error => raise FormalContract(error)
  }
  let bindings : Array[@formal_core.FormalSignalBinding] = []
  let bind = fn(
    signal : @property.PropertySignal,
    identifier : String,
  ) raise FormalGateError {
    bindings.push(
      @formal_core.FormalSignalBinding::checked(signal, identifier) catch {
        error => raise FormalContract(error)
      },
    )
  }
  bind(observer, "lc_formal_step_clock")
  for _, definition in definitions {
    let (_, _, predicate) = definition
    bind(named_signal(path, predicate), "lc_\{predicate}")
  }
  let property_export = @formal_core.export_yosys_clocked_properties(
    plan, bindings,
  ) catch {
    error => raise FormalContract(error)
  }
  let legal : Array[String] = []
  let fairness : Array[String] = []
  let assertions : Array[String] = []
  let covers : Array[String] = []
  for index, property in property_export.properties() {
    let (name, _, _) = definitions[index]
    match name {
      "source_clock_transition_legal" | "destination_clock_transition_legal" =>
        legal.push(property.stable_name())
      "source_clock_fair" | "destination_clock_fair" =>
        fairness.push(property.stable_name())
      "coincident_source_destination_edge" =>
        covers.push(property.stable_name())
      _ => assertions.push(property.stable_name())
    }
  }
  (
    property_export,
    ReadOnlyArray::from_array(legal),
    ReadOnlyArray::from_array(fairness),
    ReadOnlyArray::from_array(assertions),
    ReadOnlyArray::from_array(covers),
  )
}

///|
fn synchronizer_expected_failure(
  fixture : SynchronizerFormalFixture,
  properties : @formal_core.FormalPropertyManifest,
) -> String raise FormalGateError {
  let expected_name = match fixture {
    ValidSynchronizer => return "none"
    BrokenSynchronizerPipeline =>
      "pipeline_matches_previous_destination_samples"
    BrokenSynchronizerDestinationEdge =>
      "output_changes_only_on_destination_edge"
    BrokenSynchronizerConvergence =>
      "stable_source_converges_within_three_destination_edges"
  }
  for property in properties.properties() {
    if property.name() == expected_name {
      return property.stable_name()
    }
  }
  raise InvalidSynchronizerBundle(
    "synchronizer property manifest omitted its expected stable label",
  )
}

///|
fn synchronizer_harness(
  fixture : SynchronizerFormalFixture,
  emitted : @rtl.EmittedDesign,
  dut : SynchronizerFormalDut,
  property_source : String,
) -> String raise FormalGateError {
  let source_clock = port_identifier(emitted, InputPort, "source_clock")
  let source = port_identifier(emitted, InputPort, "source")
  let destination_clock = port_identifier(
    emitted,
    InputPort,
    "destination_clock",
  )
  let reset = port_identifier(emitted, InputPort, "reset")
  let synchronized = port_identifier(emitted, OutputPort, "synchronized")
  let pipeline_predicate = if fixture is BrokenSynchronizerPipeline {
    "lc_pipeline_base && !(lc_seen_destination_edge && !lc_reset_sampled)"
  } else {
    "lc_pipeline_base"
  }
  let destination_edge_predicate = if fixture
    is BrokenSynchronizerDestinationEdge {
    "lc_destination_edge_base && !(lc_seen_destination_edge && !lc_last_destination_rise)"
  } else {
    "lc_destination_edge_base"
  }
  let convergence_predicate = if fixture is BrokenSynchronizerConvergence {
    "lc_convergence_base && (lc_stable_destination_edges < 3)"
  } else {
    "lc_convergence_base"
  }
  let out = StringBuilder()
  out.write_string("`default_nettype none\n")
  out.write_string(
    "// Generated Phase 5 timed three-stage synchronizer harness.\n",
  )
  out.write_string("module lc_formal_synchronizer_top;\n")
  out.write_string("  logic lc_formal_step_clock = 1'b0;\n")
  out.write_string(
    "  always @($global_clock) lc_formal_step_clock <= ~lc_formal_step_clock;\n",
  )
  out.write_string("  (* anyseq *) logic lc_requested_source_clock;\n")
  out.write_string("  (* anyseq *) logic lc_requested_destination_clock;\n")
  out.write_string("  (* anyseq *) logic lc_requested_source_value;\n")
  out.write_string("  logic lc_scheduled_source_clock = 1'b0;\n")
  out.write_string("  logic lc_scheduled_destination_clock = 1'b0;\n")
  out.write_string("  logic lc_scheduled_source_value = 1'b0;\n")
  out.write_string("  logic lc_source_clock = 1'b0;\n")
  out.write_string("  logic lc_destination_clock = 1'b0;\n")
  out.write_string("  logic lc_reset = 1'b1;\n")
  out.write_string("  logic [2:0] lc_source_idle_steps = 3'd0;\n")
  out.write_string("  logic [2:0] lc_destination_idle_steps = 3'd0;\n")
  out.write_string("  logic lc_last_source_rise = 1'b0;\n")
  out.write_string("  logic lc_last_destination_rise = 1'b0;\n")
  out.write_string(
    "  wire lc_requested_source_rise = !lc_source_clock && lc_requested_source_clock;\n",
  )
  out.write_string(
    "  wire lc_requested_destination_rise = !lc_destination_clock && lc_requested_destination_clock;\n",
  )
  out.write_string(
    "  wire lc_source_clock_transition_legal = !(lc_source_clock && lc_requested_source_clock);\n",
  )
  out.write_string(
    "  wire lc_destination_clock_transition_legal = !(lc_destination_clock && lc_requested_destination_clock);\n",
  )
  out.write_string(
    "  wire lc_source_clock_fair = (lc_source_idle_steps < 3) || lc_requested_source_rise;\n",
  )
  out.write_string(
    "  wire lc_destination_clock_fair = (lc_destination_idle_steps < 3) || lc_requested_destination_rise;\n",
  )
  out.write_string("  always_ff @(posedge lc_formal_step_clock) begin\n")
  out.write_string(
    "    lc_scheduled_source_clock <= lc_requested_source_clock;\n",
  )
  out.write_string(
    "    lc_scheduled_destination_clock <= lc_requested_destination_clock;\n",
  )
  out.write_string(
    "    lc_scheduled_source_value <= lc_requested_source_value;\n",
  )
  out.write_string("  end\n")
  out.write_string("  always_ff @(negedge lc_formal_step_clock) begin\n")
  out.write_string(
    "    lc_last_source_rise <= !lc_source_clock && lc_scheduled_source_clock;\n",
  )
  out.write_string(
    "    lc_last_destination_rise <= !lc_destination_clock && lc_scheduled_destination_clock;\n",
  )
  out.write_string("    lc_source_clock <= lc_scheduled_source_clock;\n")
  out.write_string(
    "    lc_destination_clock <= lc_scheduled_destination_clock;\n",
  )
  out.write_string(
    "    if (!lc_source_clock && lc_scheduled_source_clock) lc_source_idle_steps <= 3'd0;\n",
  )
  out.write_string(
    "    else if (lc_source_idle_steps != 3'd7) lc_source_idle_steps <= lc_source_idle_steps + 3'd1;\n",
  )
  out.write_string(
    "    if (!lc_destination_clock && lc_scheduled_destination_clock) lc_destination_idle_steps <= 3'd0;\n",
  )
  out.write_string(
    "    else if (lc_destination_idle_steps != 3'd7) lc_destination_idle_steps <= lc_destination_idle_steps + 3'd1;\n",
  )
  out.write_string("  end\n")
  out.write_string(
    "  always_ff @(posedge lc_destination_clock) if (lc_reset) lc_reset <= 1'b0;\n\n",
  )
  out.write_string("  logic lc_synchronized;\n")
  for index, _ in dut.stage_ports {
    out.write_string("  wire lc_stage\{index};\n")
  }
  out.write_string("  wire lc_source_value;\n")
  out.write_string("  \{dut.identifier()} lc_dut (\n")
  out.write_string("    .\{source_clock}(lc_source_clock),\n")
  out.write_string("    .\{source}(lc_scheduled_source_value),\n")
  out.write_string("    .\{destination_clock}(lc_destination_clock),\n")
  out.write_string("    .\{reset}(lc_reset),\n")
  out.write_string("    .\{synchronized}(lc_synchronized),\n")
  for index, port in dut.stage_ports {
    out.write_string("    .\{port}(lc_stage\{index}),\n")
  }
  out.write_string("    .\{dut.source_port}(lc_source_value)\n")
  out.write_string("  );\n")
  out.write_string("  logic lc_reference_stage0 = 1'b0;\n")
  out.write_string("  logic lc_reference_stage1 = 1'b0;\n")
  out.write_string("  logic lc_reference_stage2 = 1'b0;\n")
  out.write_string("  logic lc_tracked_source = 1'b0;\n")
  out.write_string("  logic [2:0] lc_stable_destination_edges = 3'd0;\n")
  out.write_string("  logic lc_seen_destination_edge = 1'b0;\n")
  out.write_string("  logic lc_reset_sampled = 1'b0;\n")
  out.write_string("  always_ff @(posedge lc_destination_clock) begin\n")
  out.write_string("    lc_seen_destination_edge <= 1'b1;\n")
  out.write_string("    lc_reset_sampled <= lc_reset;\n")
  out.write_string("    if (lc_reset) begin\n")
  out.write_string("      lc_reference_stage0 <= 1'b0;\n")
  out.write_string("      lc_reference_stage1 <= 1'b0;\n")
  out.write_string("      lc_reference_stage2 <= 1'b0;\n")
  out.write_string("      lc_tracked_source <= lc_source_value;\n")
  out.write_string("      lc_stable_destination_edges <= 3'd0;\n")
  out.write_string("    end else begin\n")
  out.write_string("      lc_reference_stage0 <= lc_source_value;\n")
  out.write_string("      lc_reference_stage1 <= lc_reference_stage0;\n")
  out.write_string("      lc_reference_stage2 <= lc_reference_stage1;\n")
  out.write_string("      if (lc_source_value == lc_tracked_source) begin\n")
  out.write_string(
    "        if (lc_stable_destination_edges != 3'd7) lc_stable_destination_edges <= lc_stable_destination_edges + 3'd1;\n",
  )
  out.write_string("      end else begin\n")
  out.write_string("        lc_tracked_source <= lc_source_value;\n")
  out.write_string("        lc_stable_destination_edges <= 3'd1;\n")
  out.write_string("      end\n")
  out.write_string("    end\n")
  out.write_string("  end\n")
  out.write_string("  logic lc_previous_output = 1'b0;\n")
  out.write_string(
    "  always_ff @(posedge lc_formal_step_clock) lc_previous_output <= lc_synchronized;\n",
  )
  out.write_string(
    "  wire lc_pipeline_base = !lc_seen_destination_edge || ((lc_stage0 == lc_reference_stage0) && (lc_stage1 == lc_reference_stage1) && (lc_stage2 == lc_reference_stage2));\n",
  )
  out.write_string(
    "  wire lc_reset_base = !lc_reset_sampled || ((lc_stage0 == 1'b0) && (lc_stage1 == 1'b0) && (lc_stage2 == 1'b0));\n",
  )
  out.write_string(
    "  wire lc_destination_edge_base = !lc_seen_destination_edge || lc_last_destination_rise || (lc_synchronized == lc_previous_output);\n",
  )
  out.write_string(
    "  wire lc_convergence_base = (lc_stable_destination_edges < 3) || (lc_synchronized == lc_tracked_source);\n",
  )
  out.write_string(
    "  wire lc_pipeline_matches_previous_destination_samples = \{pipeline_predicate};\n",
  )
  out.write_string(
    "  wire lc_synchronous_reset_clears_all_stages = lc_reset_base;\n",
  )
  out.write_string(
    "  wire lc_output_changes_only_on_destination_edge = \{destination_edge_predicate};\n",
  )
  out.write_string(
    "  wire lc_stable_source_converges_within_three_destination_edges = \{convergence_predicate};\n",
  )
  out.write_string(
    "  wire lc_coincident_edge = lc_seen_destination_edge && !lc_reset_sampled && lc_last_source_rise && lc_last_destination_rise;\n\n",
  )
  out.write_string(property_source)
  out.write_string("endmodule\n`default_nettype wire\n")
  out.to_string()
}

///|
fn synchronizer_source_set(
  fixture : SynchronizerFormalFixture,
  design_ir : String,
  dut : SynchronizerFormalDut,
  harness : String,
  property_manifest : String,
) -> String {
  "LUNACHIP-PHASE5-FORMAL-SOURCE-SET 1\n" +
  "FAMILY bit-synchronizer\n" +
  "FIXTURE \{fixture.id()}\n" +
  "TOP lc_formal_synchronizer_top\n" +
  "CLOCK-CONTRACT bounded-fair-pulses\n" +
  "GLOBAL-TIMESTEP engine-steps 2\n" +
  "COINCIDENCE atomic-global-pre-state\n" +
  "CLAIM-BOUNDARY digital-two-state-bounded-no-metastability-mtbf-placement-or-timing\n" +
  "ADDRESS-KNOWNNESS two-state-formal-all-binary\n" +
  "IR design.lcir sha256 \{sha256_hex(design_ir)}\n" +
  "SOURCE \{dut.filename()} sha256 \{sha256_hex(dut.source())}\n" +
  "SOURCE formal-harness.sv sha256 \{sha256_hex(harness)}\n" +
  "PROPERTIES properties.lcfp sha256 \{sha256_hex(property_manifest)}\n" +
  "END\n"
}

///|
fn synchronizer_timing_contract(
  source_domain : @ir.ClockDomainId,
  destination_domain : @ir.ClockDomainId,
  legal : ReadOnlyArray[String],
  fairness : ReadOnlyArray[String],
) -> @formal_core.FormalTimingContract raise FormalGateError {
  let path = "lc_formal_synchronizer_top"
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
fn synchronizer_tasks(
  fixture : SynchronizerFormalFixture,
  source_artifact : @formal_core.ArtifactRef,
  timing : @formal_core.FormalTimingContract,
  assumptions : ReadOnlyArray[String],
  assertions : ReadOnlyArray[String],
  covers : ReadOnlyArray[String],
) -> ReadOnlyArray[GateTask] raise FormalGateError {
  let tool = formal_tool()
  let tasks : Array[GateTask] = []
  let bmc_name = "\{fixture.id()}-bmc"
  let bmc = @formal_core.BoundedProofTask::checked(
    bmc_name,
    source_artifact,
    tool,
    "smtbmc-bitwuzla",
    BoundedSafety,
    @formal_core.ProofBound::checked(48),
    assumptions,
    assertions,
  ).with_timing_contract(timing) catch {
    error => raise FormalContract(error)
  }
  tasks.push({
    name: bmc_name,
    task: Bounded(bmc),
    task_class: BoundedSafetyTask,
    bound: 48,
    timeout_seconds: 300,
    expected_status: if fixture is ValidSynchronizer {
      "pass"
    } else {
      "fail"
    },
  })
  if fixture is ValidSynchronizer {
    let cover_name = "valid-synchronizer-cover"
    let cover = @formal_core.BoundedProofTask::checked(
      cover_name,
      source_artifact,
      tool,
      "smtbmc-bitwuzla",
      BoundedCover,
      @formal_core.ProofBound::checked(24),
      assumptions,
      covers,
    ).with_timing_contract(timing) catch {
      error => raise FormalContract(error)
    }
    tasks.push({
      name: cover_name,
      task: Bounded(cover),
      task_class: BoundedCoverTask,
      bound: 24,
      timeout_seconds: 300,
      expected_status: "pass",
    })
  }
  ReadOnlyArray::from_array(tasks)
}

///|
fn synchronizer_job_json(
  dut : SynchronizerFormalDut,
  harness : String,
  tasks : ReadOnlyArray[GateTask],
) -> String {
  let out = StringBuilder()
  out.write_string("{\n")
  out.write_string(
    "  \"$schema\": \"https://lunachip.dev/schema/yosys-job-v1.json\",\n",
  )
  out.write_string("  \"schema_version\": \"lunachip.yosys-job/v1\",\n")
  out.write_string("  \"top_module\": \"lc_formal_synchronizer_top\",\n")
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
fn synchronizer_execution_manifest(
  task : GateTask,
  expected_failure : String,
  job_manifest : String,
  property_manifest : String,
  source_identity : String,
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
  let task_expected_failure = if task.task_class() is BoundedCoverTask {
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
  selections.to_string() +
  "EXPECTED-STATUS \{task.expected_status()}\n" +
  "EXPECTED-FAILURE \{task_expected_failure}\n" +
  "RUNNER scripts/phase4-yosys-run.sh oci formal \{task.name()} BUNDLE OUTPUT\n" +
  "END\n"
}

///|
/// Generate one isolated timed, three-stage synchronizer formal bundle.
pub fn generate_synchronizer_bundle(
  fixture : SynchronizerFormalFixture,
) -> SynchronizerFormalBundle raise {
  let design = synchronizer_design()
  let design_ir = @ir_codec.serialize(design)
  guard design.top_module() is Some(hardware_module) else {
    raise MissingTopModule
  }
  guard hardware_module.domains() is [source_domain, destination_domain] else {
    raise InvalidSynchronizerBundle(
      "formal synchronizer must expose exactly two clock domains",
    )
  }
  let emitted = @rtl.emit_design(design)
  let production_dut = top_emitted_module(emitted)
  let dut = synchronizer_formal_dut(design, emitted, production_dut)
  let (property_export, legal, fairness, assertions, covers) = synchronizer_property_export()
  let harness = synchronizer_harness(
    fixture,
    emitted,
    dut,
    property_export.source(),
  )
  let property_manifest = property_export.manifest()
  let source_identity = synchronizer_source_set(
    fixture, design_ir, dut, harness, property_manifest,
  )
  let source_artifact = checked_artifact(
    "source-set.lcfs",
    sha256_hex(source_identity),
  )
  let assumption_values : Array[String] = []
  for label in legal {
    assumption_values.push(label)
  }
  for label in fairness {
    assumption_values.push(label)
  }
  let assumptions = ReadOnlyArray::from_array(assumption_values)
  let timing = synchronizer_timing_contract(
    source_domain.id(),
    destination_domain.id(),
    legal,
    fairness,
  )
  let tasks = synchronizer_tasks(
    fixture, source_artifact, timing, assumptions, assertions, covers,
  )
  validate_task_bindings(tasks, assumptions, assertions, covers)
  let expected_failure = synchronizer_expected_failure(
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
      path: "\{task.name()}.lcft",
      content: task.task().to_canonical_text(),
    })
  }
  let manifest = synchronizer_job_json(dut, harness, tasks)
  artifacts.push({ path: "job.json", content: manifest, })
  for task in tasks {
    artifacts.push({
      path: "\{task.name()}.lcfg",
      content: synchronizer_execution_manifest(
        task, expected_failure, manifest, property_manifest, source_identity,
      ),
    })
  }
  {
    fixture,
    artifacts: ReadOnlyArray::from_array(artifacts),
    tasks,
    job_json: manifest,
    top_identifier: "lc_formal_synchronizer_top",
    expected_failure,
  }
}

///|
pub fn standard_synchronizer_formal_bundles() -> ReadOnlyArray[
  SynchronizerFormalBundle,
] raise {
  ReadOnlyArray::from_array([
    generate_synchronizer_bundle(ValidSynchronizer),
    generate_synchronizer_bundle(BrokenSynchronizerPipeline),
    generate_synchronizer_bundle(BrokenSynchronizerDestinationEdge),
    generate_synchronizer_bundle(BrokenSynchronizerConvergence),
  ])
}
