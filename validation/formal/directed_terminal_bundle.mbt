///|
fn directed_terminal_source_set(
  design_ir : String,
  dut : FluxTileFormalDut,
  harness : String,
  properties : String,
) -> String {
  "LUNACHIP-PHASE6-FORMAL-SOURCE-SET 1\n" +
  "FAMILY flux-tile-directed-first-terminal\n" +
  "FIXTURE phase6-flux-tile-directed-first-terminal\n" +
  "TOP lc_formal_flux_tile_top\n" +
  "DUT fetched-concurrent-1x1-k2 host-bytes 1024 ring-depth 4 queue-depth 2\n" +
  "OBSERVATIONS public-pins-only-name-manifest\n" +
  "MUTATION none\n" +
  "GLOBAL-TIMESTEP engine-steps 2\n" +
  "CLOCK-CONTRACT one-toggle-per-global-step-one-rising-edge-per-two-steps\n" +
  "PILOT-BOUND global-steps 256 dut-clocks 128\n" +
  "COINCIDENCE atomic-global-pre-state\n" +
  "RESET first-edge-joint-reset-then-no-reset\n" +
  "HOST directed-config512-origin0-one-published-fence-id1\n" +
  "HOST-RESPONSE actual-request-owned-immediate-matching-tag-status0-fixed-byte-image\n" +
  "HOST-READY request-and-completion-always-one\n" +
  "PACKET descriptor0.2-fence-id1-zero-unused-and-reserved-fields\n" +
  "FENCE-IMAGE address513-byte2-address514-byte4-address516-byte1-otherwise-byte0\n" +
  "COVER actual-retirement-after-32-ordered-read-requests-and-32-owned-acknowledgements\n" +
  "DUT-PROGRESS-ASSUMPTIONS none\n" +
  "FAIRNESS none-directed-fixed-environment-not-eventual-completion-proof\n" +
  "ORIGINAL-SYMBOLIC-TASKS unchanged-and-not-replaced\n" +
  "CLAIM-BOUNDARY directed-fetched-fence-reachability-only-no-safety-dependency-liveness-write-or-product-proof\n" +
  "ADDRESS-KNOWNNESS two-state-formal-all-binary\n" +
  "IR design.lcir sha256 \{sha256_hex(design_ir)}\n" +
  "SOURCE \{dut.filename} sha256 \{sha256_hex(dut.source)}\n" +
  "SOURCE formal-harness.sv sha256 \{sha256_hex(harness)}\n" +
  "PROPERTIES properties.lcfp sha256 \{sha256_hex(properties)}\n" +
  "END\n"
}

///|
fn directed_terminal_task(
  source : @formal_core.ArtifactRef,
  timing : @formal_core.FormalTimingContract,
  legal : ReadOnlyArray[String],
  cover : String,
) -> GateTask raise FormalGateError {
  let name = "phase6-flux-tile-directed-first-terminal-cover-successful-fence"
  let tool = formal_tool()
  let bounded = @formal_core.BoundedProofTask::checked(
    name,
    source,
    tool,
    "smtbmc-bitwuzla",
    BoundedCover,
    @formal_core.ProofBound::checked(256),
    legal,
    [cover],
  ).with_timing_contract(timing) catch {
    error => raise FormalContract(error)
  }
  {
    name,
    task: Bounded(bounded),
    task_class: BoundedCoverTask,
    bound: 256,
    timeout_seconds: 600,
    expected_status: "pass",
  }
}

///|
// This private specialization is reached only through the explicit additive
// DirectedFirstTerminal variant. The standard three pilots remain unchanged.
fn generate_directed_terminal_bundle() -> FluxTileFormalBundle raise {
  let fixture : FluxTileFormalFixture = DirectedFirstTerminal
  let design = flux_tile_formal_design()
  let design_ir = @ir_codec.serialize(design)
  guard design.top_module() is Some(hardware) else { raise MissingTopModule }
  guard hardware.domains() is [domain] else {
    raise InvalidFormalBundleIdentity(
      "directed terminal fixture must have one clock domain",
    )
  }
  let emitted = @rtl.emit_design(design)
  let dut = flux_tile_formal_dut(hardware, emitted)
  let (exported, legal, cover) = directed_terminal_property_export()
  let harness = directed_terminal_harness(dut, exported.source())
  let properties = exported.manifest()
  let source_set = directed_terminal_source_set(
    design_ir, dut, harness, properties,
  )
  let source = checked_artifact("source-set.lcfs", sha256_hex(source_set))
  let timing = flux_tile_timing_contract(domain.id(), legal)
  let gate = directed_terminal_task(source, timing, legal, cover)
  let name = gate.name()
  let tasks = ReadOnlyArray::from_array([gate])
  validate_task_bindings(tasks, legal, [], [cover])
  let artifacts : Array[FormalBundleArtifact] = [
    { path: "design.lcir", content: design_ir, },
    { path: dut.filename, content: dut.source, },
    { path: "formal-harness.sv", content: harness, },
    { path: "properties.lcfp", content: properties, },
    { path: "source-set.lcfs", content: source_set, },
    { path: name + ".lcft", content: gate.task().to_canonical_text(), },
  ]
  let job = flux_tile_job_json(dut, harness, tasks)
  artifacts.push({ path: "job.json", content: job, })
  artifacts.push({
    path: name + ".lcfg",
    content: flux_tile_execution_manifest(
      gate, "none", job, properties, source_set,
    ),
  })
  {
    fixture,
    artifacts: ReadOnlyArray::from_array(artifacts),
    tasks,
    job_json: job,
    top_identifier: "lc_formal_flux_tile_top",
    expected_failure: "none",
  }
}
