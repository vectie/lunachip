///|
fn fetched_useful_source_set(
  canonical : String,
  production : FluxTileFormalDut,
  dut : FluxTileFormalDut,
  harness : String,
  properties : String,
  names : String,
) -> String {
  "LUNACHIP-PHASE6-FORMAL-SOURCE-SET 1\n" +
  "FAMILY flux-tile-fetched-useful-store\nFIXTURE \{fetched_useful_id()}\nTOP lc_formal_fetched_useful_top\n" +
  "DUT original-fetched-concurrent-1x1-k2 host-bytes1024 ring-depth4 queue-depth2\n" +
  "OBSERVATIONS all-original-public-pins-only-name-manifest\nCUTS none\nMUTATION none\n" +
  "GLOBAL-TIMESTEP engine-steps 2\nCLOCK-CONTRACT one-toggle-per-global-step-one-rising-edge-per-two-steps\n" +
  "PILOT-BOUND global-steps 1024 dut-clocks 512\nCOINCIDENCE atomic-global-pre-state\n" +
  "RESET first-sampled-joint-reset-then-never-reset\n" +
  "HOST separate-directed-public-configbase0-origin0-publish4-R1-H1-C1-owned-success-held-next-PRE-response\n" +
  "HOST-IMAGE common-accepted-address-byte-map-descriptors0..127-A256..257-B512..513-Store768..771\n" +
  "PACKETS canonical-descriptor0.2-all-ID73-LoadA1x2-LoadB2x1-MatMul1x1K2-Store1x1-all-slots0\n" +
  "NO-PREMISE private-progress-engine-accept-ownership-lease-release-terminal-response-readiness-or-memory-zero\n" +
  "CONCLUSIONS original-eight-public-conditions-plus-public-history-write-address-mask-and-ordinal-success-identity\n" +
  "COVER exact132-good-read-accepts-and-owned-ACKs-distinct128-descriptor-and4-operand-addresses-one4byte-write768-mask15-owned-ACK-four-ordinal-success-retirements-progress2,2,0,4-consumer4\n" +
  "NUMERIC-WITNESS cover-only-signed-A[-3,7]-B[5,-2]-one-Stored-word-minus29-not-universal-arithmetic-proof\n" +
  "BUDGET candidate-search-only-128descriptorbytes-times3-steady-DUT-edges-plus-setup-operands-compute-Store-retirement-within512-needs-actual-cover-qualification\n" +
  "CLAIM-BOUNDARY generated-inputs-only-directed-fetched-useful-safety-and-cover-not-general-R2-completion-fairness-8x8-dependency-or-Phase6-closure\n" +
  "ORIGINAL-SYMBOLIC-AND-NEGATIVE-OBLIGATIONS unchanged-not-replaced-or-implicitly-closed\n" +
  "COMPARISONS formal-only-pointwise-Boolean-adapter-production-four-state-unchanged-requires-qualified-helper-body-reuse-or-SAT\n" +
  "IR design.lcir sha256 \{sha256_hex(canonical)}\n" +
  "PRODUCTION-UNCOMPILED production-\{production.filename} sha256 \{sha256_hex(production.source)}\n" +
  "SOURCE \{dut.filename} sha256 \{sha256_hex(dut.source)}\n" +
  "SOURCE formal-harness.sv sha256 \{sha256_hex(harness)}\n" +
  "PROPERTIES properties.lcfp sha256 \{sha256_hex(properties)}\nNAMES names.lcnm sha256 \{sha256_hex(names)}\nEND\n"
}

///|
fn generate_fetched_useful_bundle() -> FetchedUsefulBundle raise {
  let design = flux_tile_formal_design()
  let canonical = @ir_codec.serialize(design)
  if sha256_hex(canonical) !=
    "d47c7cccaa7dc7d8021b0fabc6a4eb7d4977bb53c1c5fa06416bbbb5e531cf79" {
    raise InvalidFormalBundleIdentity(
      "fetched useful exact ordinary source drift",
    )
  }
  guard design.top_module() is Some(hardware) else { raise MissingTopModule }
  guard hardware.domains() is [domain] else {
    raise InvalidFormalBundleIdentity("fetched useful one clock")
  }
  let emitted = @rtl.emit_design(design)
  let production = flux_tile_formal_dut(hardware, emitted)
  let (source, _) = dependency_boolean_helpers(hardware, production.source)
  let dut : FluxTileFormalDut = {
    identifier: production.identifier,
    filename: "formal-dut.sv",
    source,
    ports: production.ports,
  }
  let (exported, assumptions, assertions, covers) = fetched_useful_property_export()
  let harness = fetched_useful_harness(dut, exported.source())
  let properties = exported.manifest()
  let names = emitted.manifest().to_canonical_text()
  let source_set = fetched_useful_source_set(
    canonical, production, dut, harness, properties, names,
  )
  let tasks = fetched_useful_tasks(
    checked_artifact("source-set.lcfs", sha256_hex(source_set)),
    fetched_useful_timing(domain.id(), assumptions),
    assumptions,
    assertions,
    covers,
  )
  validate_task_bindings(tasks, assumptions, assertions, covers)
  let job = fetched_useful_job(dut, harness, tasks)
  let artifacts : Array[FormalBundleArtifact] = [
    { path: "design.lcir", content: canonical, },
    { path: "production-" + production.filename, content: production.source, },
    { path: dut.filename, content: dut.source, },
    { path: "formal-harness.sv", content: harness, },
    { path: "properties.lcfp", content: properties, },
    { path: "source-set.lcfs", content: source_set, },
    { path: "names.lcnm", content: names, },
    { path: "job.json", content: job, },
  ]
  for task in tasks {
    artifacts.push({
      path: task.name() + ".lcft",
      content: task.task().to_canonical_text(),
    })
    artifacts.push({
      path: task.name() + ".lcfg",
      content: fetched_useful_execution(task, job, properties, source_set),
    })
  }
  { artifacts: ReadOnlyArray::from_array(artifacts), }
}
