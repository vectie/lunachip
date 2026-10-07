///|
fn direct_completion_source_set(
  fixture : DirectCompletionFixture,
  view : @flux_tile.QueueConservationFixture,
  design_ir : String,
  dut : QueueFormalDut,
  harness : String,
  properties : String,
) -> String {
  let observations = StringBuilder()
  for reference in view.observations() {
    observations.write_string(
      "OBSERVATION \{queue_role_name(reference.role())} node \{reference.node().ordinal()} width \{reference.signal_type().width().bits()} type \{queue_signal_type_name(reference.signal_type())}\n",
    )
  }
  let profile = match fixture {
    Eventual =>
      "symbolic-raw-direct-descriptors-any-caller-ID-including-duplicates"
    UsefulStore =>
      "separate-named-public-four-packet-producer-LoadA-LoadB-MatMul-Store-all-callerID73"
    NegativeDeadline =>
      "identical-symbolic-positive-host-premises-and-ordinal-watch"
  }
  let mutation = if fixture is NegativeDeadline {
    "checked-deadline-only-canonical-saved-legal-1x2-LoadA-1-otherwise252-raw-history-unchanged"
  } else {
    "none"
  }
  "LUNACHIP-PHASE6-FORMAL-SOURCE-SET 1\n" +
  "FAMILY flux-tile-direct-completion\n" +
  "FIXTURE \{fixture.id()}\nTOP lc_formal_direct_completion_top\n" +
  "DUT direct-queued-concurrent-1x1-k2 host-bytes 1024 queue-depth 3\n" +
  "OBSERVATIONS exact-115-typed-existing-node-refs-name-manifest-no-new-IR\n" +
  observations.to_string() +
  "MUTATION \{mutation}\n" +
  "GLOBAL-TIMESTEP engine-steps 2\n" +
  "CLOCK-CONTRACT one-toggle-per-global-step-one-rising-edge-per-two-steps\n" +
  "PILOT-BOUND global-steps 640 dut-clocks 320\n" +
  "COINCIDENCE atomic-global-pre-state\n" +
  "RESET deterministic-one-initial-synchronous-joint-reset-edge-then-never-asserted\n" +
  "HOST \{profile}\n" +
  "LEGAL producer-held-public256-and-owned-matching-success-response-held-public66-no-unsolicited-duplicate-or-early-response\n" +
  "FAIRNESS R2-ready-opportunities-e-through-e+1 H2-response-OFFER-a+1-through-a+2-held-until-actual-accept C2-e-through-e+1-all-retirements\n" +
  "NO-PREMISE DUT-request-persistence-response-ready-dependency-ready-engine-accept-lease-release-terminal-or-core-progress\n" +
  "CONCLUSIONS checked-public-counts-ordinal-history-request-completion-stability-bus-ownership-DUT-response-readiness-and-selected-deadline\n" +
  "WATCH symbolic-public-admission-on-post-reset-edges1-through32-save-public256-predecessors-from-public-admit-retire-no-ID-or-ticket-selection\n" +
  "DEADLINE candidate252-DUT-rising-edges-inclusive-e0+252-ordinal-ACK-wins-never-horizon-disabled\n" +
  "DERIVATION R2-H2-C2 T6-L28-S16-M8-E28 D7*(4+28+2+2)=252-proposed-not-numerical-or-engine-proof\n" +
  "COVERS watched-ordinal-terminal-offer-and-retirement-separate-successful-four-command-Store-write-matching-ACK-and-retirement\n" +
  "NEGATIVE-QUALIFICATION actual-canonical-public-LoadA-admission-next-rising-PRE-age1-active-and-no-ordinal-ACK-sole-selected-deadline-failure\n" +
  "CLAIM-BOUNDARY generated-inputs-only-until-actual-engine-evidence-direct1x1-K2-only-not8x8-fetched-reset-fault-or-full-Phase6-completion\n" +
  "SUPPORT-GATE independent-FIFO-packet-ownership-dependency-arbitration-cursor-lease-compute-terminal-supporting-invariants-still-required-not-assumed\n" +
  "USEFUL-WORK actual-four-paired-good-read-accepts-and-ACKs-loader2-compute1-storer1-accept-and-collector-witnesses-Store-write-ACK-successful-ordered-retirements-no-numerical-result-proof\n" +
  "ADDRESS-KNOWNNESS two-state-formal-all-binary\n" +
  "COMPARISONS adapter-only-pointwise-Boolean-eq-lt-helpers-production-four-state-unchanged\n" +
  "EQUIVALENCE require-pinned-pointwise-SAT-and-negated-miter-control-before-device-task\n" +
  "IR design.lcir sha256 \{sha256_hex(design_ir)}\n" +
  "PRODUCTION-UNCOMPILED \{dut.production_filename} sha256 \{sha256_hex(dut.production_source)}\n" +
  "SOURCE \{dut.filename} sha256 \{sha256_hex(dut.source)}\n" +
  "SOURCE formal-harness.sv sha256 \{sha256_hex(harness)}\n" +
  "PROPERTIES properties.lcfp sha256 \{sha256_hex(properties)}\nEND\n"
}

///|
/// Generate an isolated direct 1x1/K2/q3 completion task family, not results.
/// H bounds response offers only; DUT response readiness is a conclusion.
/// The useful Store cover has its own explicit producer premise, and cannot
/// establish arbitrary-admission liveness or numerical Store correctness.
///
/// ```mbt check
/// test {
///   let bundle = @formal.generate_direct_completion_formal_bundle(
///     NegativeDeadline,
///   )
///   assert_eq(bundle.tasks().length(), 1)
///   assert_eq(bundle.tasks()[0].bound(), 640)
/// }
/// ```
pub fn generate_direct_completion_formal_bundle(
  fixture : DirectCompletionFixture,
) -> DirectCompletionFormalBundle raise {
  let view = @flux_tile.queued_concurrent_queue_formal_fixture()
  let hardware = view.hardware()
  let design = @ir.Design::single(
    "QueuedConcurrentQueueConservationPilot", hardware,
  )
  let design_ir = @ir_codec.serialize(design)
  if sha256_hex(design_ir) !=
    "35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc" ||
    direct_completion_deadline() != 252 {
    raise InvalidFormalBundleIdentity(
      "direct completion: fixed 1x1/K2/q3 source or allowance drift",
    )
  }
  guard hardware.domains() is [domain] else {
    raise InvalidFormalBundleIdentity(
      "direct completion: single original clock domain",
    )
  }
  let dut = queue_formal_dut(view, @rtl.emit_design(design))
  let (exported, legal, fairness, assertions, covers) = direct_completion_property_export(
    fixture,
  )
  let all_assumptions = legal.iter().to_array()
  for label in fairness {
    all_assumptions.push(label)
  }
  let assumptions = ReadOnlyArray::from_array(all_assumptions)
  let harness = direct_completion_harness(fixture, dut, exported.source())
  let properties = exported.manifest()
  let source_set = direct_completion_source_set(
    fixture, view, design_ir, dut, harness, properties,
  )
  let source = checked_artifact("source-set.lcfs", sha256_hex(source_set))
  let timing = direct_completion_timing_contract(domain.id(), legal, fairness)
  let mut expected_failure = "none"
  if fixture is NegativeDeadline {
    guard exported
      .properties()
      .filter(item => item.source_name() == "dc_watched_retirement_deadline")
      is [property] else {
      raise InvalidFormalBundleIdentity(
        "direct completion: missing selected deadline assertion",
      )
    }
    expected_failure = property.stable_name()
  }
  let tasks = direct_completion_tasks(
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
      content: direct_completion_execution_manifest(
        task, expected_failure, job, properties, source_set,
      ),
    })
  }
  {
    fixture,
    artifacts: ReadOnlyArray::from_array(artifacts),
    tasks,
    job_json: job,
    top_identifier: "lc_formal_direct_completion_top",
    expected_failure,
  }
}

///|
pub fn standard_direct_completion_formal_bundles() -> ReadOnlyArray[
  DirectCompletionFormalBundle,
] raise {
  ReadOnlyArray::from_array([
    generate_direct_completion_formal_bundle(Eventual),
    generate_direct_completion_formal_bundle(UsefulStore),
    generate_direct_completion_formal_bundle(NegativeDeadline),
  ])
}
