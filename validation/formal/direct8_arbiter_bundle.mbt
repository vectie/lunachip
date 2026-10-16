///|
fn generate_direct8_arbiter_artifacts() -> ReadOnlyArray[FormalBundleArtifact] raise {
  let fixture = direct8_arbiter_fixture()
  let hardware = fixture.hardware()
  let design = @ir.Design::single(
    "QueuedConcurrentDirect8CompletionPilot", hardware,
  )
  let design_ir = @ir_codec.serialize(design)
  guard hardware.domains() is [domain] else {
    fail("original single clock required")
  }
  let emitted = @rtl.emit_design(design)
  let names = emitted.manifest().to_canonical_text()
  let parent = direct8_progress_with_fifo_support(
    hardware,
    emitted,
    direct8_completion_dut(hardware, emitted),
  )
  let (public_export, legal, fairness, public_assertions, _) = direct_completion_export_definitions(
    direct8_progress_definitions(),
  )
  let internal_export = direct8_arbiter_property_export(
    port_identifier(emitted, InputPort, "clock"),
  )
  let (overlay, report) = direct8_arbiter_overlay(
    fixture, emitted, internal_export,
  )
  let dut = direct8_arbiter_dut(parent, overlay)
  let predicates = public_export
    .property_manifest()
    .properties()
    .iter()
    .to_array()
  let selected = public_assertions.iter().to_array()
  for item in internal_export.property_manifest().properties() {
    predicates.push(item)
  }
  for item in internal_export.properties() {
    selected.push(item.stable_name())
  }
  let assertions = ReadOnlyArray::from_array(selected)
  let properties = @formal_core.FormalPropertyManifest::from_plan(
    @formal_core.FormalPropertyPlan::checked(predicates),
  ).to_canonical_text()
  let all_assumptions = legal.iter().to_array()
  for label in fairness {
    all_assumptions.push(label)
  }
  let assumptions = ReadOnlyArray::from_array(all_assumptions)
  assert_eq((assumptions.length(), assertions.length()), (7, 22))
  let harness = direct8_completion_harness(
    Eventual,
    dut,
    direct8_progress_source() + public_export.source(),
  )
  let source_set = "LUNACHIP-PHASE6-FORMAL-SOURCE-SET 1\nFAMILY flux-tile-direct8-progress\nFIXTURE \{direct8_arbiter_id}\nTOP lc_formal_direct_completion_top\n" +
    "DUT original-direct8-rows8-columns8-K16-host4096-q3-no-port-or-equation-change\n" +
    "OBSERVATIONS original-equation-discovered-arbiter-and115-queue-node-references-proof-only-local-aliases\n" +
    "ASSUMPTIONS original-seven-public-R2-H2-C2-no-client-persistence-or-internal-progress-premise\n" +
    "CONCLUSIONS original-eight-public-progress-plus14-grant-snapshot-routing-preference-T6-persistent-client-2T-and-local-head-Done-collector-properties\n" +
    "SUPPORT original-eight-FIFO-pointer-range-conclusions\n" +
    "PERSISTENCE request-withdrawal-before-local-acceptance-cancels-only-client-watch-never-granted-transaction-or-accepted-request-age\n" +
    "COMPOSITION original11718-still-required-engine-persistence-cursors-capture-leases-entry-ownership-and-six-predecessor-rank-not-proved-here\n" +
    "INDUCTION depth32-global-steps-not-a-reduced-completion-BMC\n" +
    "ADDRESS-KNOWNNESS two-state-formal-all-binary\nMEMORY original38-arrays8960-storage-bits-unknown-INIT-and-read-INIT\n" +
    "IR design.lcir sha256 \{sha256_hex(design_ir)}\nSOURCE formal-dut.sv sha256 \{sha256_hex(dut.source)}\n" +
    "PRODUCTION-UNCOMPILED \{dut.production_filename} sha256 \{sha256_hex(dut.production_source)}\n" +
    "SOURCE formal-harness.sv sha256 \{sha256_hex(harness)}\nPROPERTIES properties.lcfp sha256 \{sha256_hex(properties)}\n" +
    "BINDINGS arbiter-bindings.lcab sha256 \{sha256_hex(report)}\nNAMES names.lcnm sha256 \{sha256_hex(names)}\nEND\n"
  let proof = @formal_core.UnboundedProofTask::checked(
    direct8_arbiter_id + "-prove",
    checked_artifact("source-set.lcfs", sha256_hex(source_set)),
    formal_tool(),
    "smtbmc-bitwuzla",
    @formal_core.InductionMethod::k_induction(32),
    assumptions,
    assertions,
  ).with_timing_contract(
    direct_completion_timing_contract(domain.id(), legal, fairness),
  )
  let task : GateTask = {
    name: direct8_arbiter_id + "-prove",
    task: Unbounded(proof),
    task_class: UnboundedSafetyTask,
    bound: 32,
    timeout_seconds: 600,
    expected_status: "pass",
  }
  let tasks : ReadOnlyArray[GateTask] = [task]
  validate_task_bindings(tasks, assumptions, assertions, [])
  let job = direct_completion_job_json(dut, harness, tasks)
  let execution = flux_tile_execution_manifest(
    task, "none", job, properties, source_set,
  )
  let old_mapping = "BOUND-MAPPING 256-global-steps-128-dut-clocks\n"
  dependency_require_marker(execution, old_mapping)
  [
    { path: "design.lcir", content: design_ir, },
    { path: dut.production_filename, content: dut.production_source, },
    { path: dut.filename, content: dut.source, },
    { path: "names.lcnm", content: names, },
    { path: "formal-harness.sv", content: harness, },
    { path: "properties.lcfp", content: properties, },
    { path: "arbiter-bindings.lcab", content: report, },
    { path: "source-set.lcfs", content: source_set, },
    { path: "job.json", content: job, },
    { path: task.name() + ".lcft", content: task.task().to_canonical_text(), },
    {
      path: task.name() + ".lcfg",
      content: execution.replace(
        old=old_mapping,
        new="BOUND-MAPPING induction-depth32-global-steps-16-dut-clocks-not-completion-deadline\n",
      ),
    },
  ]
}
