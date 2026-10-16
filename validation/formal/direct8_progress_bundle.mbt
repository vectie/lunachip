///|
fn generate_direct8_progress_artifacts() -> ReadOnlyArray[FormalBundleArtifact] raise {
  let hardware = @flux_tile.queued_concurrent_tile(
    rows=8,
    columns=8,
    max_reduction=16,
    host_bytes=4096UL,
    queue_depth=3,
  )
  // Keep the original canonical design identity, not an extracted transaction model.
  let design = @ir.Design::single(
    "QueuedConcurrentDirect8CompletionPilot", hardware,
  )
  let design_ir = @ir_codec.serialize(design)
  guard hardware.domains() is [domain] else {
    fail("direct8 progress requires the original single clock")
  }
  let emitted = @rtl.emit_design(design)
  let names = emitted.manifest().to_canonical_text()
  let dut = direct8_completion_dut(hardware, emitted)
  let (exported, legal, fairness, assertions, covers) = direct_completion_export_definitions(
    direct8_progress_definitions(),
  )
  assert_true(
    covers.is_empty() &&
    legal.length() == 4 &&
    fairness.length() == 3 &&
    assertions.length() == 8,
  )
  let all_assumptions = legal.iter().to_array()
  for label in fairness {
    all_assumptions.push(label)
  }
  let assumptions = ReadOnlyArray::from_array(all_assumptions)
  let harness = direct8_completion_harness(
    Eventual,
    dut,
    direct8_progress_source() + exported.source(),
  )
  let properties = exported.manifest()
  let source_set = "LUNACHIP-PHASE6-FORMAL-SOURCE-SET 1\nFAMILY flux-tile-direct8-progress\nFIXTURE \{direct8_progress_id}\nTOP lc_formal_direct_completion_top\n" +
    "DUT original-plain-direct-queued-concurrent rows8 columns8 K16 host4096 queue-depth3 slots2\n" +
    "OBSERVATIONS original-public-pins-only-no-debug-port-cut-or-abstract-engine\n" +
    "RESET original-initial-joint-synchronous-reset-only-no-memory-erasure\n" +
    "ASSUMPTIONS original-seven-public-R2-H2-C2-no-internal-progress-premise\n" +
    "CONCLUSIONS request-stability-serial-ownership-DUT-response-readiness-offer-drain-R2-reply-drain-H2-service-drain3-owner-history-age-history\n" +
    "AGES independent-saturating-offer-and-accepted-request-timers-not-frozen-by-response-offer-inclusive-ACK\n" +
    "COMPOSITION public-offer-to-response-ACK-only-arbiter-grant-loader-store-compute-queue-dependency-composition-still-required\n" +
    "COMPLETION-DEADLINE original11718-unchanged-not-selected-or-proved-by-this-component\n" +
    "INDUCTION depth12-global-steps-not-a-reduced-completion-BMC-bound\n" +
    "ADDRESS-KNOWNNESS two-state-formal-all-binary\nMEMORY original38-arrays8960-storage-bits-unknown-INIT-and-read-INIT\n" +
    "IR design.lcir sha256 \{sha256_hex(design_ir)}\nSOURCE formal-dut.sv sha256 \{sha256_hex(dut.source)}\n" +
    "PRODUCTION-UNCOMPILED \{dut.production_filename} sha256 \{sha256_hex(dut.production_source)}\n" +
    "SOURCE formal-harness.sv sha256 \{sha256_hex(harness)}\nPROPERTIES properties.lcfp sha256 \{sha256_hex(properties)}\nNAMES names.lcnm sha256 \{sha256_hex(names)}\nEND\n"
  let source = checked_artifact("source-set.lcfs", sha256_hex(source_set))
  let timing = direct_completion_timing_contract(domain.id(), legal, fairness)
  let proof = @formal_core.UnboundedProofTask::checked(
    direct8_progress_id + "-prove",
    source,
    formal_tool(),
    "smtbmc-bitwuzla",
    @formal_core.InductionMethod::k_induction(12),
    assumptions,
    assertions,
  ).with_timing_contract(timing)
  let task : GateTask = {
    name: direct8_progress_id + "-prove",
    task: Unbounded(proof),
    task_class: UnboundedSafetyTask,
    bound: 12,
    timeout_seconds: 600,
    expected_status: "pass",
  }
  let tasks : ReadOnlyArray[GateTask] = [task]
  validate_task_bindings(tasks, assumptions, assertions, [])
  let job = direct_completion_job_json(dut, harness, tasks)
  let execution = flux_tile_execution_manifest(
    task, "none", job, properties, source_set,
  )
  let mapping = "BOUND-MAPPING 256-global-steps-128-dut-clocks\n"
  dependency_require_marker(execution, mapping)
  [
    { path: "design.lcir", content: design_ir, },
    { path: dut.production_filename, content: dut.production_source, },
    { path: dut.filename, content: dut.source, },
    { path: "names.lcnm", content: names, },
    { path: "formal-harness.sv", content: harness, },
    { path: "properties.lcfp", content: properties, },
    { path: "source-set.lcfs", content: source_set, },
    { path: "job.json", content: job, },
    { path: task.name() + ".lcft", content: task.task().to_canonical_text(), },
    {
      path: task.name() + ".lcfg",
      content: execution.replace(
        old=mapping,
        new="BOUND-MAPPING induction-depth12-global-steps-6-dut-clocks-not-completion-deadline\n",
      ),
    },
  ]
}

///|
/// Export the original direct8 transport progress component, not the full
/// completion theorem. Unknown IDs return None; generation is not a proof.
///
/// ```mbt check
/// test {
///   assert_eq(@formal.direct8_progress_artifacts_from_id("unknown"), None)
/// }
/// ```
pub fn direct8_progress_artifacts_from_id(
  id : String,
) -> ReadOnlyArray[FormalBundleArtifact]? raise {
  if id == direct8_progress_id {
    Some(generate_direct8_progress_artifacts())
  } else {
    None
  }
}
