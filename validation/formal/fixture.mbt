///|
fn sha256_hex(text : String) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode(text)))
}

///|
fn fifo_design(fixture : FifoFormalFixture) -> @ir.Design raise {
  let module_name = match fixture {
    ValidFifo => "phase4_valid_fifo_dut"
    BrokenFifoData => "phase4_broken_fifo_data_dut"
    BrokenResponseProtocol => "phase4_broken_response_protocol_dut"
    BrokenBounds => "phase4_broken_bounds_dut"
  }
  let config = @memory.FifoConfig::new(
    module_name,
    UInt(@ir.Width::new(8)),
    2,
    PowerOfTwo,
  )
  let hardware_module = @memory.synchronous_fifo_module(config)
  @ir.Design::single(module_name, hardware_module)
}

///|
fn top_emitted_module(
  emitted : @rtl.EmittedDesign,
) -> @rtl.EmittedModule raise FormalGateError {
  let top = emitted.manifest().top_module_ordinal()
  let mut found : @rtl.EmittedModule? = None
  for hardware_module in emitted.modules() {
    if hardware_module.module_ordinal() == top {
      if found is Some(_) {
        raise DuplicateEmittedTop
      }
      found = Some(hardware_module)
    }
  }
  guard found is Some(hardware_module) else { raise MissingEmittedTop }
  hardware_module
}

///|
fn port_kind_name(kind : @rtl.SymbolKind) -> String {
  match kind {
    InputPort => "input"
    OutputPort => "output"
    Module => "module"
    Node => "node"
    Memory => "memory"
    AsyncFifoLane => "async-fifo-lane"
  }
}

///|
fn port_identifier(
  emitted : @rtl.EmittedDesign,
  kind : @rtl.SymbolKind,
  name : String,
) -> String raise FormalGateError {
  let top = emitted.manifest().top_module_ordinal()
  let mut found : String? = None
  for mapping in emitted.manifest().mappings() {
    if mapping.module_ordinal() == top &&
      mapping.kind() == kind &&
      mapping.source_name() == name {
      if found is Some(_) {
        raise DuplicatePort(kind=port_kind_name(kind), name~)
      }
      found = Some(mapping.identifier())
    }
  }
  guard found is Some(identifier) else {
    raise MissingPort(kind=port_kind_name(kind), name~)
  }
  identifier
}

///|
fn named_signal(
  path : String,
  name : String,
) -> @property.PropertySignal raise FormalGateError {
  @property.PropertySignal::named(path, name) catch {
    error => raise PropertyContract(error)
  }
}

///|
fn property_id(value : Int) -> @property.PropertyId raise FormalGateError {
  @property.PropertyId::new(value) catch {
    error => raise PropertyContract(error)
  }
}

///|
fn checked_formal_property(
  id : @property.PropertyId,
  name : String,
  kind : @formal_core.FormalPropertyKind,
  predicate : @property.PropertySignal,
  domain : @formal_core.ObservationDomain,
  disable : @formal_core.DisableBehavior,
) -> @formal_core.FormalProperty raise FormalGateError {
  @formal_core.FormalProperty::checked(
    id, name, kind, predicate, domain, disable,
  ) catch {
    error => raise FormalContract(error)
  }
}

///|
fn checked_assumption(
  id : @property.PropertyId,
  name : String,
  predicate : @property.PropertySignal,
  domain : @formal_core.ObservationDomain,
  disable : @formal_core.DisableBehavior,
) -> @formal_core.FormalProperty raise FormalGateError {
  @formal_core.FormalProperty::assumption(id, name, predicate, domain, disable) catch {
    error => raise FormalContract(error)
  }
}

///|
fn build_property_export(
  fixture : FifoFormalFixture,
) -> (
  @formal_core.FormalExport,
  ReadOnlyArray[String],
  ReadOnlyArray[String],
  ReadOnlyArray[String],
) raise FormalGateError {
  let path = "lc_formal_fifo_top"
  let clock = named_signal(path, "clock")
  let reset = named_signal(path, "reset")
  let domain = @formal_core.ObservationDomain::rising_pre_edge(clock) catch {
    error => raise FormalContract(error)
  }
  let disabled = @formal_core.DisableBehavior::when_known_high_asynchronous(
    reset,
  ) catch {
    error => raise FormalContract(error)
  }
  let properties : Array[@formal_core.FormalProperty] = []
  properties.push(
    checked_assumption(
      property_id(0),
      "reset_exactly_one_cycle",
      named_signal(path, "reset_protocol_ok"),
      domain,
      NeverDisabled,
    ),
  )
  if fixture is BrokenFifoData {
    properties.push(
      checked_assumption(
        property_id(1),
        "negative_fifo_schedule",
        named_signal(path, "negative_schedule_ok"),
        domain,
        disabled,
      ),
    )
  }
  let property_names : Array[String] = [
    "occupancy_within_capacity", "flags_match_occupancy", "ready_matches_contract",
    "response_valid_matches_pop", "fifo_data_order",
  ]
  let predicate_names = [
    "occupancy_bound_ok", "flags_ok", "ready_protocol_ok", "response_valid_ok", "data_order_ok",
  ]
  let property_base = if fixture is BrokenFifoData { 2 } else { 1 }
  for index, name in property_names {
    properties.push(
      checked_formal_property(
        property_id(property_base + index),
        name,
        Assertion,
        named_signal(path, predicate_names[index]),
        domain,
        disabled,
      ),
    )
  }
  let cover_name = "full_replacement_response_reachable"
  properties.push(
    checked_formal_property(
      property_id(property_base + property_names.length()),
      cover_name,
      Cover,
      named_signal(path, "cover_full_replacement"),
      domain,
      disabled,
    ),
  )
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
  bind(clock, "lc_clock")
  bind(reset, "lc_reset")
  bind(named_signal(path, "reset_protocol_ok"), "lc_reset_protocol_ok")
  if fixture is BrokenFifoData {
    bind(named_signal(path, "negative_schedule_ok"), "lc_negative_schedule_ok")
  }
  for predicate in predicate_names {
    bind(named_signal(path, predicate), "lc_\{predicate}")
  }
  bind(
    named_signal(path, "cover_full_replacement"),
    "lc_cover_full_replacement",
  )
  let property_export = @formal_core.export_yosys_clocked_properties(
    plan, bindings,
  ) catch {
    error => raise FormalContract(error)
  }
  let assumption_labels : Array[String] = []
  let safety_labels : Array[String] = []
  let cover_labels : Array[String] = []
  for exported in property_export.properties() {
    match exported.kind() {
      Assumption => assumption_labels.push(exported.stable_name())
      Assertion => safety_labels.push(exported.stable_name())
      Cover => cover_labels.push(exported.stable_name())
    }
  }
  (
    property_export,
    ReadOnlyArray::from_array(assumption_labels),
    ReadOnlyArray::from_array(safety_labels),
    ReadOnlyArray::from_array(cover_labels),
  )
}

///|
fn formal_harness(
  fixture : FifoFormalFixture,
  emitted : @rtl.EmittedDesign,
  dut : @rtl.EmittedModule,
  property_source : String,
) -> String raise FormalGateError {
  let clock = port_identifier(emitted, InputPort, "clock")
  let reset = port_identifier(emitted, InputPort, "reset")
  let push_valid = port_identifier(emitted, InputPort, "push_valid")
  let push_data = port_identifier(emitted, InputPort, "push_data")
  let pop_request = port_identifier(emitted, InputPort, "pop_request")
  let push_ready = port_identifier(emitted, OutputPort, "push_ready")
  let pop_ready = port_identifier(emitted, OutputPort, "pop_ready")
  let response_valid = port_identifier(emitted, OutputPort, "response_valid")
  let response_data = port_identifier(emitted, OutputPort, "response_data")
  let full = port_identifier(emitted, OutputPort, "full")
  let empty = port_identifier(emitted, OutputPort, "empty")
  let occupancy = port_identifier(emitted, OutputPort, "occupancy")
  let checked_data = if fixture is BrokenFifoData {
    "lc_dut_response_data ^ 8'h01"
  } else {
    "lc_dut_response_data"
  }
  let checked_valid = if fixture is BrokenResponseProtocol {
    "~lc_dut_response_valid"
  } else {
    "lc_dut_response_valid"
  }
  let checked_occupancy = if fixture is BrokenBounds {
    "2'b11"
  } else {
    "lc_dut_occupancy"
  }
  let negative_schedule = if fixture is BrokenFifoData {
    "  wire lc_negative_schedule_ok = (lc_formal_cycle == 4'd1) ? (lc_push_valid && !lc_pop_request) :\n    ((lc_formal_cycle == 4'd2) ? (!lc_push_valid && lc_pop_request) : 1'b1);\n"
  } else {
    ""
  }
  let out = StringBuilder()
  out.write_string("`default_nettype none\n")
  out.write_string("// Generated Phase 4 FIFO formal harness.\n")
  out.write_string(
    "// One exact reset edge is assumed; reset cannot remain asserted.\n",
  )
  out.write_string("module lc_formal_fifo_top;\n")
  out.write_string("  logic lc_clock = 1'b0;\n")
  out.write_string("  always @($global_clock) begin\n")
  out.write_string("    lc_clock <= ~lc_clock;\n")
  out.write_string("  end\n")
  out.write_string("  (* anyseq *) logic lc_reset;\n")
  out.write_string("  (* anyseq *) logic lc_push_valid;\n")
  out.write_string("  (* anyseq *) logic [7:0] lc_push_data;\n")
  out.write_string("  (* anyseq *) logic lc_pop_request;\n")
  out.write_string("  logic lc_dut_push_ready;\n")
  out.write_string("  logic lc_dut_pop_ready;\n")
  out.write_string("  logic lc_dut_response_valid;\n")
  out.write_string("  logic [7:0] lc_dut_response_data;\n")
  out.write_string("  logic lc_dut_full;\n")
  out.write_string("  logic lc_dut_empty;\n")
  out.write_string("  logic [1:0] lc_dut_occupancy;\n")
  out.write_string("  logic [3:0] lc_formal_cycle = 4'd0;\n")
  out.write_string("  always_ff @(posedge lc_clock) begin\n")
  out.write_string(
    "    if (lc_formal_cycle != 4'hf) lc_formal_cycle <= lc_formal_cycle + 4'd1;\n",
  )
  out.write_string("  end\n")
  out.write_string(
    "  wire lc_reset_protocol_ok = (lc_formal_cycle == 4'd0) ? lc_reset : !lc_reset;\n",
  )
  out.write_string(negative_schedule)
  out.write_string("\n  \{dut.identifier()} lc_dut (\n")
  out.write_string("    .\{clock}(lc_clock),\n")
  out.write_string("    .\{reset}(lc_reset),\n")
  out.write_string("    .\{push_valid}(lc_push_valid),\n")
  out.write_string("    .\{push_data}(lc_push_data),\n")
  out.write_string("    .\{pop_request}(lc_pop_request),\n")
  out.write_string("    .\{push_ready}(lc_dut_push_ready),\n")
  out.write_string("    .\{pop_ready}(lc_dut_pop_ready),\n")
  out.write_string("    .\{response_valid}(lc_dut_response_valid),\n")
  out.write_string("    .\{response_data}(lc_dut_response_data),\n")
  out.write_string("    .\{full}(lc_dut_full),\n")
  out.write_string("    .\{empty}(lc_dut_empty),\n")
  out.write_string("    .\{occupancy}(lc_dut_occupancy)\n")
  out.write_string("  );\n\n")
  out.write_string(
    "  wire lc_push_fire = lc_push_valid && lc_dut_push_ready;\n",
  )
  out.write_string("  wire lc_pop_fire = lc_pop_request && lc_dut_pop_ready;\n")
  out.write_string("  logic [7:0] lc_reference_memory [0:1];\n")
  out.write_string("  logic lc_reference_read_pointer;\n")
  out.write_string("  logic lc_reference_write_pointer;\n")
  out.write_string("  logic [1:0] lc_reference_count;\n")
  out.write_string("  logic lc_expected_valid;\n")
  out.write_string("  logic [7:0] lc_expected_data;\n")
  out.write_string("  always_ff @(posedge lc_clock) begin\n")
  out.write_string("    if (lc_reset) begin\n")
  out.write_string("      lc_reference_read_pointer <= 1'b0;\n")
  out.write_string("      lc_reference_write_pointer <= 1'b0;\n")
  out.write_string("      lc_reference_count <= 2'd0;\n")
  out.write_string("      lc_expected_valid <= 1'b0;\n")
  out.write_string("    end else begin\n")
  out.write_string("      lc_expected_valid <= lc_pop_fire;\n")
  out.write_string("      if (lc_push_fire) begin\n")
  out.write_string(
    "        lc_reference_memory[lc_reference_write_pointer] <= lc_push_data;\n",
  )
  out.write_string(
    "        lc_reference_write_pointer <= ~lc_reference_write_pointer;\n",
  )
  out.write_string("      end\n")
  out.write_string("      if (lc_pop_fire) begin\n")
  out.write_string(
    "        lc_expected_data <= lc_reference_memory[lc_reference_read_pointer];\n",
  )
  out.write_string(
    "        lc_reference_read_pointer <= ~lc_reference_read_pointer;\n",
  )
  out.write_string("      end\n")
  out.write_string("      case ({lc_push_fire, lc_pop_fire})\n")
  out.write_string(
    "        2'b10: lc_reference_count <= lc_reference_count + 2'd1;\n",
  )
  out.write_string(
    "        2'b01: lc_reference_count <= lc_reference_count - 2'd1;\n",
  )
  out.write_string(
    "        default: lc_reference_count <= lc_reference_count;\n",
  )
  out.write_string("      endcase\n")
  out.write_string("    end\n")
  out.write_string("  end\n\n")
  out.write_string("  wire lc_checked_response_valid = \{checked_valid};\n")
  out.write_string("  wire [7:0] lc_checked_response_data = \{checked_data};\n")
  out.write_string(
    "  wire [1:0] lc_checked_occupancy = \{checked_occupancy};\n",
  )
  out.write_string(
    "  wire lc_occupancy_bound_ok = (lc_checked_occupancy <= 2'd2);\n",
  )
  out.write_string(
    "  wire lc_flags_ok = (lc_dut_empty == (lc_dut_occupancy == 2'd0)) &&\n",
  )
  out.write_string("    (lc_dut_full == (lc_dut_occupancy == 2'd2)) &&\n")
  out.write_string("    (lc_dut_occupancy == lc_reference_count);\n")
  out.write_string(
    "  wire lc_ready_protocol_ok = (lc_dut_pop_ready == !lc_dut_empty) &&\n",
  )
  out.write_string(
    "    (lc_dut_push_ready == (!lc_dut_full || lc_pop_fire));\n",
  )
  out.write_string(
    "  wire lc_response_valid_ok = (lc_checked_response_valid == lc_expected_valid);\n",
  )
  out.write_string("  wire lc_data_order_ok = !lc_checked_response_valid ||\n")
  out.write_string("    (lc_checked_response_data == lc_expected_data);\n")
  out.write_string(
    "  wire lc_cover_full_replacement = lc_dut_full && lc_push_fire &&\n",
  )
  out.write_string("    lc_pop_fire && lc_checked_response_valid;\n\n")
  out.write_string(property_source)
  out.write_string("endmodule\n`default_nettype wire\n")
  out.to_string()
}

///|
fn source_set_identity(
  fixture : FifoFormalFixture,
  design_ir : String,
  dut : @rtl.EmittedModule,
  harness : String,
  property_manifest : String,
) -> String {
  "LUNACHIP-PHASE4-FORMAL-SOURCE-SET 1\n" +
  "FIXTURE \{fixture.id()}\n" +
  "TOP lc_formal_fifo_top\n" +
  "ADDRESS-KNOWNNESS two-state-formal-all-binary\n" +
  "IR design.lcir sha256 \{sha256_hex(design_ir)}\n" +
  "SOURCE \{dut.filename()} sha256 \{sha256_hex(dut.source())}\n" +
  "SOURCE formal-harness.sv sha256 \{sha256_hex(harness)}\n" +
  "PROPERTIES properties.lcfp sha256 \{sha256_hex(property_manifest)}\n" +
  "END\n"
}

///|
fn formal_tool() -> @formal_core.FormalTool raise FormalGateError {
  @formal_core.FormalTool::checked(
    "Yosys/SymbiYosys/Bitwuzla", "Yosys 0.68; SBY v0.68; Bitwuzla 0.9.1",
  ) catch {
    error => raise FormalContract(error)
  }
}

///|
fn checked_artifact(
  name : String,
  digest : String,
) -> @formal_core.ArtifactRef raise FormalGateError {
  @formal_core.ArtifactRef::checked(name, digest) catch {
    error => raise FormalContract(error)
  }
}

///|
fn gate_tasks(
  fixture : FifoFormalFixture,
  source_artifact : @formal_core.ArtifactRef,
  assumptions : ReadOnlyArray[String],
  safety_properties : ReadOnlyArray[String],
  cover_properties : ReadOnlyArray[String],
) -> ReadOnlyArray[GateTask] raise FormalGateError {
  let tool = formal_tool()
  let tasks : Array[GateTask] = []
  match fixture {
    ValidFifo => {
      let bmc_bound = @formal_core.ProofBound::checked(16) catch {
        error => raise FormalContract(error)
      }
      let bmc = @formal_core.BoundedProofTask::checked(
        "valid-fifo-bmc",
        source_artifact,
        tool,
        "smtbmc-bitwuzla",
        BoundedSafety,
        bmc_bound,
        assumptions,
        safety_properties,
      ) catch {
        error => raise FormalContract(error)
      }
      tasks.push({
        name: "valid-fifo-bmc",
        task: Bounded(bmc),
        task_class: BoundedSafetyTask,
        bound: 16,
        timeout_seconds: 300,
        expected_status: "pass",
      })
      let induction = @formal_core.InductionMethod::k_induction(12) catch {
        error => raise FormalContract(error)
      }
      let prove = @formal_core.UnboundedProofTask::checked(
        "valid-fifo-prove",
        source_artifact,
        tool,
        "smtbmc-bitwuzla",
        induction,
        assumptions,
        ReadOnlyArray::from_array(safety_properties[0:4].to_owned()),
      ) catch {
        error => raise FormalContract(error)
      }
      tasks.push({
        name: "valid-fifo-prove",
        task: Unbounded(prove),
        task_class: UnboundedSafetyTask,
        bound: 12,
        timeout_seconds: 300,
        expected_status: "pass",
      })
      let cover_bound = @formal_core.ProofBound::checked(16) catch {
        error => raise FormalContract(error)
      }
      let cover = @formal_core.BoundedProofTask::checked(
        "valid-fifo-cover",
        source_artifact,
        tool,
        "smtbmc-bitwuzla",
        BoundedCover,
        cover_bound,
        assumptions,
        cover_properties,
      ) catch {
        error => raise FormalContract(error)
      }
      tasks.push({
        name: "valid-fifo-cover",
        task: Bounded(cover),
        task_class: BoundedCoverTask,
        bound: 16,
        timeout_seconds: 300,
        expected_status: "pass",
      })
    }
    BrokenFifoData | BrokenResponseProtocol | BrokenBounds => {
      let task_name = "\{fixture.id()}-bmc"
      let bmc_bound = @formal_core.ProofBound::checked(12) catch {
        error => raise FormalContract(error)
      }
      let bmc = @formal_core.BoundedProofTask::checked(
        task_name,
        source_artifact,
        tool,
        "smtbmc-bitwuzla",
        BoundedSafety,
        bmc_bound,
        assumptions,
        safety_properties,
      ) catch {
        error => raise FormalContract(error)
      }
      tasks.push({
        name: task_name,
        task: Bounded(bmc),
        task_class: BoundedSafetyTask,
        bound: 12,
        timeout_seconds: 300,
        expected_status: "fail",
      })
    }
  }
  ReadOnlyArray::from_array(tasks)
}

///|
fn same_names(
  actual : ReadOnlyArray[String],
  expected : ReadOnlyArray[String],
) -> Bool {
  actual.length() == expected.length() &&
  actual.all(name => expected.contains(name))
}

///|
fn validate_task_bindings(
  tasks : ReadOnlyArray[GateTask],
  assumptions : ReadOnlyArray[String],
  safety_properties : ReadOnlyArray[String],
  cover_properties : ReadOnlyArray[String],
) -> Unit raise FormalGateError {
  for task in tasks {
    let (task_assumptions, task_properties) = match task.task() {
      Bounded(value) => (value.assumptions(), value.properties())
      Unbounded(value) => (value.assumptions(), value.properties())
    }
    if !same_names(task_assumptions, assumptions) {
      raise TaskPropertyBindingMismatch(task.name())
    }
    let properties_match = match task.task_class() {
      BoundedCoverTask =>
        !task_properties.is_empty() &&
        task_properties.all(name => cover_properties.contains(name))
      BoundedSafetyTask => same_names(task_properties, safety_properties)
      UnboundedSafetyTask =>
        same_names(
          task_properties,
          ReadOnlyArray::from_array(safety_properties[0:4].to_owned()),
        )
    }
    if !properties_match {
      raise TaskPropertyBindingMismatch(task.name())
    }
  }
}

///|
fn job_mode(task_class : GateTaskClass) -> String {
  match task_class {
    BoundedSafetyTask => "bmc"
    UnboundedSafetyTask => "prove"
    BoundedCoverTask => "cover"
  }
}

///|
fn job_claim(task_class : GateTaskClass) -> String {
  match task_class {
    BoundedSafetyTask => "bounded-safety-up-to-bound"
    UnboundedSafetyTask => "unbounded-safety-if-base-and-induction-pass"
    BoundedCoverTask => "reachability-within-bound"
  }
}

///|
fn job_json(
  dut : @rtl.EmittedModule,
  harness : String,
  tasks : ReadOnlyArray[GateTask],
) -> String {
  let out = StringBuilder()
  out.write_string("{\n")
  out.write_string(
    "  \"$schema\": \"https://lunachip.dev/schema/yosys-job-v1.json\",\n",
  )
  out.write_string("  \"schema_version\": \"lunachip.yosys-job/v1\",\n")
  out.write_string("  \"top_module\": \"lc_formal_fifo_top\",\n")
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
fn execution_manifest(
  task : GateTask,
  fixture : FifoFormalFixture,
  safety_properties : ReadOnlyArray[String],
  job_manifest : String,
  property_manifest : String,
  source_identity : String,
) -> String {
  let expected_failure = match fixture {
    ValidFifo => "none"
    BrokenBounds => safety_properties[0]
    BrokenResponseProtocol => safety_properties[3]
    BrokenFifoData => safety_properties[4]
  }
  let selected_assumptions = match task.task() {
    Bounded(value) => value.assumptions()
    Unbounded(value) => value.assumptions()
  }
  let selected_properties = match task.task() {
    Bounded(value) => value.properties()
    Unbounded(value) => value.properties()
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
  "LUNACHIP-PHASE4-FORMAL-EXECUTION 1\n" +
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
  selections.to_string() +
  "EXPECTED-STATUS \{task.expected_status()}\n" +
  "EXPECTED-FAILURE \{expected_failure}\n" +
  "RUNNER scripts/phase4-yosys-run.sh oci formal \{task.name()} BUNDLE OUTPUT\n" +
  "END\n"
}

///|
/// Generate a content-addressed formal bundle from the public FIFO component.
pub fn generate_fifo_bundle(
  fixture : FifoFormalFixture,
) -> FifoFormalBundle raise {
  let design = fifo_design(fixture)
  let design_ir = @ir_codec.serialize(design)
  guard design.top_module() is Some(_) else { raise MissingTopModule }
  let emitted = @rtl.emit_design(design)
  let dut = top_emitted_module(emitted)
  let (property_export, assumptions, safety_properties, cover_properties) = build_property_export(
    fixture,
  )
  let harness = formal_harness(fixture, emitted, dut, property_export.source())
  let property_manifest = property_export.manifest()
  let source_identity = source_set_identity(
    fixture, design_ir, dut, harness, property_manifest,
  )
  let source_artifact = checked_artifact(
    "source-set.lcfs",
    sha256_hex(source_identity),
  )
  let tasks = gate_tasks(
    fixture, source_artifact, assumptions, safety_properties, cover_properties,
  )
  validate_task_bindings(
    tasks, assumptions, safety_properties, cover_properties,
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
  let manifest = job_json(dut, harness, tasks)
  artifacts.push({ path: "job.json", content: manifest, })
  for task in tasks {
    artifacts.push({
      path: "\{task.name()}.lcfg",
      content: execution_manifest(
        task, fixture, safety_properties, manifest, property_manifest, source_identity,
      ),
    })
  }
  {
    fixture,
    artifacts: ReadOnlyArray::from_array(artifacts),
    tasks,
    job_json: manifest,
    top_identifier: "lc_formal_fifo_top",
  }
}

///|
pub fn standard_fifo_formal_bundles() -> ReadOnlyArray[FifoFormalBundle] raise {
  ReadOnlyArray::from_array([
    generate_fifo_bundle(ValidFifo),
    generate_fifo_bundle(BrokenFifoData),
    generate_fifo_bundle(BrokenResponseProtocol),
    generate_fifo_bundle(BrokenBounds),
  ])
}
