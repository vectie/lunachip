///|
fn direct8_completion_source_set(
  fixture : DirectCompletionFixture,
  design_ir : String,
  dut : QueueFormalDut,
  harness : String,
  properties : String,
  names : String,
) -> String {
  let out = StringBuilder()
  let budget = direct8_completion_budget()
  out.write_string(
    "LUNACHIP-PHASE6-FORMAL-SOURCE-SET 1\nFAMILY flux-tile-direct8-completion\nFIXTURE \{direct8_completion_id(fixture)}\nTOP lc_formal_direct_completion_top\n",
  )
  out.write_string(
    "DUT original-plain-direct-queued-concurrent rows 8 columns 8 K 16 host-bytes 4096 queue-depth 3 slots 2\nNO-FETCHED-RING direct-public-descriptor-admission-not-ring4-publication\nOBSERVATIONS public-only-all-original-pins-typed-original-IR-and-emitter-name-manifest-no-new-IR-debug-port-or-cut\n",
  )
  for port in dut.ports {
    out.write_string(
      "PORT \{port.role} width \{port.width} input \{port.input} identifier \{port.identifier}\n",
    )
  }
  let mutation = if fixture is NegativeDeadline {
    "checked-deadline-only-saved-canonical-legal-8x16-LoadA-1-otherwise11718"
  } else {
    "none"
  }
  let producer = if fixture is UsefulStore {
    "separate-named-public-four-packet-producer-LoadA8x16-LoadB16x8-MatMul8x8K16-Store8x8-all-ID73"
  } else {
    "symbolic-public256-any-caller-ID-including-duplicates"
  }
  out.write_string(
    "MUTATION \{mutation}\nGLOBAL-TIMESTEP engine-steps 2\nCLOCK-CONTRACT one-toggle-per-global-step-one-rising-edge-per-two-steps\nPILOT-BOUND global-steps \{budget.global_steps} dut-clocks \{budget.global_steps / 2}\nMINIMUM-WATCH-TAIL global-steps \{budget.required_global_steps} startup1-watch32-deadline11718\nCOINCIDENCE atomic-global-pre-state\nRESET deterministic-one-initial-synchronous-joint-reset-edge-then-never-asserted\nHOST \{producer}\n",
  )
  out.write_string(
    "LEGAL producer-held-public256-and-owned-matching-success-response-held-public66-no-unsolicited-duplicate-or-early-response\nFAIRNESS R2-ready-opportunities-e-through-e+1 H2-response-OFFER-a+1-through-a+2-held-until-actual-accept C2-e-through-e+1-all-retirements\nNO-PREMISE DUT-request-persistence-response-ready-dependency-ready-engine-accept-lease-release-terminal-or-core-progress\nCONCLUSIONS same-six-direct1-public-predicates-ordinal-history-request-completion-stability-bus-ownership-DUT-response-readiness-selected-deadline\nWATCH independent-public-admit-retire-ordinal-selected-first32-post-reset-edges-save-public256-not-ID-or-ticket-selection\nDEADLINE candidate11718-DUT-rising-edges-inclusive-ordinal-ACK-wins-age14-saturates16383-never-horizon-disabled\n",
  )
  out.write_string(
    "DERIVATION R2-H2-C2 T=R+H+2=\{budget.transaction} L=128*(2*T+1)+2=\{budget.load} S=64*(2*T+2)+2=\{budget.store} M=(16+8+8-2)+64+5=\{budget.compute} E=\{budget.engine} D=(2*q+1)*(4+E+C+2)=\{budget.deadline}\n",
  )
  out.write_string(
    "USEFUL-WORK public-four-identical-ID-admissions-three-prior-successful-ordinal-retirements-256-distinct-read-address-accepts-and-owned-success-ACKs-64-distinct-word-write-accepts-and-owned-success-ACKs-watched-successful-Store-retirement\nUSEFUL-ADDRESSES LoadA256-through383 LoadB512-through639 Store1024-through1279-word-aligned-mask15\nNEGATIVE-QUALIFICATION actual-canonical-public-8x16-LoadA-admission-next-rising-PRE-age1-active-no-watched-ACK-sole-selected-deadline-failure\nCLAIM-BOUNDARY generated-inputs-only-not-proof-or-receipt-not-numerical-result-not-internal-engine-ownership-not-fetched-completion-not-area-timing-or-physical-fit\nSUPPORT-GATE FIFO-packet-provenance-retirement-ownership-dependency-arbitration-cursor-lease-compute-terminal-supporting-obligations-still-open-not-assumed\nADDRESS-KNOWNNESS two-state-formal-all-binary\nCOMPARISONS formal-only-existing-pointwise-Boolean-helper-adapter-production-four-state-unchanged\nEQUIVALENCE require-pinned-exact-helper-body-reuse-or-pointwise-SAT-and-negative-control-before-device-task\n",
  )
  out.write_string(
    "IR design.lcir sha256 \{sha256_hex(design_ir)}\nPRODUCTION-UNCOMPILED \{dut.production_filename} sha256 \{sha256_hex(dut.production_source)}\nSOURCE \{dut.filename} sha256 \{sha256_hex(dut.source)}\nSOURCE formal-harness.sv sha256 \{sha256_hex(harness)}\nPROPERTIES properties.lcfp sha256 \{sha256_hex(properties)}\nNAMES names.lcnm sha256 \{sha256_hex(names)}\nEND\n",
  )
  out.to_string()
}

///|
// Inputs only. Registration and execution are separate parent-owned steps.
fn generate_direct8_completion_bundle(
  fixture : DirectCompletionFixture,
) -> Direct8CompletionBundle raise {
  let budget = direct8_completion_budget()
  if budget.watch_window != 32 ||
    budget.deadline != 11718 ||
    budget.global_steps != 23552 ||
    budget.required_global_steps != 23502 ||
    budget.age_width != 14 {
    raise InvalidFormalBundleIdentity(
      "direct8 completion allowance scope drift",
    )
  }
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
  let design_ir = @ir_codec.serialize(design)
  guard hardware.domains() is [domain] else {
    raise InvalidFormalBundleIdentity(
      "direct8 completion single original clock",
    )
  }
  let emitted = @rtl.emit_design(design)
  let names = emitted.manifest().to_canonical_text()
  let dut = direct8_completion_dut(hardware, emitted)
  let (exported, legal, fairness, assertions, covers) = direct_completion_property_export(
    fixture,
  )
  let all_assumptions = legal.iter().to_array()
  for label in fairness {
    all_assumptions.push(label)
  }
  let assumptions = ReadOnlyArray::from_array(all_assumptions)
  let harness = direct8_completion_harness(fixture, dut, exported.source())
  let properties = exported.manifest()
  let source_set = direct8_completion_source_set(
    fixture, design_ir, dut, harness, properties, names,
  )
  let source = checked_artifact("source-set.lcfs", sha256_hex(source_set))
  let timing = direct_completion_timing_contract(domain.id(), legal, fairness)
  let mut expected_failure = "none"
  if fixture is NegativeDeadline {
    guard exported
      .properties()
      .filter(item => item.source_name() == "dc_watched_retirement_deadline")
      is [property] else {
      raise InvalidFormalBundleIdentity("direct8 completion deadline selection")
    }
    expected_failure = property.stable_name()
  }
  let tasks = direct8_completion_tasks(
    fixture, source, timing, assumptions, assertions, covers, expected_failure,
  )
  let selected_safety : ReadOnlyArray[String] = if fixture is NegativeDeadline {
    [expected_failure]
  } else {
    assertions
  }
  validate_task_bindings(tasks, assumptions, selected_safety, covers)
  let artifacts : Array[FormalBundleArtifact] = [
    { path: "design.lcir", content: design_ir, },
    { path: dut.production_filename, content: dut.production_source, },
    { path: dut.filename, content: dut.source, },
    { path: "names.lcnm", content: names, },
    { path: "formal-harness.sv", content: harness, },
    { path: "properties.lcfp", content: properties, },
    { path: "source-set.lcfs", content: source_set, },
  ]
  for task in tasks {
    artifacts.push({
      path: task.name() + ".lcft",
      content: task.task().to_canonical_text(),
    })
  }
  let job = direct_completion_job_json(dut, harness, tasks)
  artifacts.push({ path: "job.json", content: job, })
  for task in tasks {
    artifacts.push({
      path: task.name() + ".lcfg",
      content: direct8_completion_execution_manifest(
        task, expected_failure, job, properties, source_set,
      ),
    })
  }
  { artifacts: ReadOnlyArray::from_array(artifacts), }
}
