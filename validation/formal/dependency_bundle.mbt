///|
fn dependency_tasks(
  fixture : DependencyFormalFixture,
  source : @formal_core.ArtifactRef,
  timing : @formal_core.FormalTimingContract,
  legal : ReadOnlyArray[String],
  assertions : ReadOnlyArray[String],
  covers : ReadOnlyArray[String],
  expected_failure : String,
) -> ReadOnlyArray[GateTask] raise FormalGateError {
  let tasks : Array[GateTask] = []
  let tool = formal_tool()
  let selected = if fixture is LatestWriter ||
    fixture is LatestWriterGenerationSupport {
    assertions
  } else {
    [expected_failure]
  }
  let safety_name = fixture.id() + "-bmc"
  let safety = @formal_core.BoundedProofTask::checked(
    safety_name,
    source,
    tool,
    "smtbmc-bitwuzla",
    BoundedSafety,
    @formal_core.ProofBound::checked(256),
    legal,
    selected,
  ).with_timing_contract(timing) catch {
    error => raise FormalContract(error)
  }
  tasks.push({
    name: safety_name,
    task: Bounded(safety),
    task_class: BoundedSafetyTask,
    bound: 256,
    timeout_seconds: 600,
    expected_status: if fixture is LatestWriter ||
      fixture is LatestWriterGenerationSupport {
      "pass"
    } else {
      "fail"
    },
  })
  if fixture is LatestWriter {
    let suffixes = [
      "failed-reload-mat4", "failed-mat-store5", "invalid-syntax-prior", "older-terminal-new-intent",
      "outer-inner-authorization",
    ]
    for index, label in covers {
      let name = fixture.id() + "-cover-" + suffixes[index]
      let cover = @formal_core.BoundedProofTask::checked(
        name,
        source,
        tool,
        "smtbmc-bitwuzla",
        BoundedCover,
        @formal_core.ProofBound::checked(256),
        legal,
        [label],
      ).with_timing_contract(timing) catch {
        error => raise FormalContract(error)
      }
      tasks.push({
        name,
        task: Bounded(cover),
        task_class: BoundedCoverTask,
        bound: 256,
        timeout_seconds: 600,
        expected_status: "pass",
      })
    }
  }
  ReadOnlyArray::from_array(tasks)
}

///|
fn dependency_source_set(
  fixture : DependencyFormalFixture,
  view : @flux_tile.QueuedConcurrentFormalFixture,
  design_ir : String,
  dut : DependencyFormalDut,
  harness : String,
  properties : String,
) -> String {
  let mutation = match fixture {
    LatestWriter | LatestWriterGenerationSupport => "none"
    NegativeFailedGeneration => "comparison-only-real-Failed-status-as-Success"
    NegativeNewIntentPriority =>
      "comparison-only-new-intent-ticket-as-matching-old-terminal-ticket"
    NegativeInnerIdentity =>
      "comparison-only-inner-reduction-bit0-on-actual-accept"
  }
  let observations = StringBuilder()
  for reference in view.observations() {
    observations.write_string(
      "OBSERVATION \{dependency_role_name(reference.role())} node \{reference.node().ordinal()} width \{reference.signal_type().width().bits()}\n",
    )
  }
  let support = if fixture is LatestWriterGenerationSupport {
    "SUPPORT all-boundary-18-field-generation-relation-assertion-not-assumption\n"
  } else {
    ""
  }
  "LUNACHIP-PHASE6-FORMAL-SOURCE-SET 1\n" +
  "FAMILY flux-tile-dependency\n" +
  "FIXTURE \{fixture.id()}\n" +
  "TOP lc_formal_dependency_top\n" +
  "DUT direct-queued-concurrent-1x1-k2 host-bytes 1024 queue-depth 3\n" +
  "OBSERVATIONS exact-48-typed-existing-node-refs-name-manifest-no-new-IR\n" +
  observations.to_string() +
  "MUTATION \{mutation}\n" +
  support +
  "GLOBAL-TIMESTEP engine-steps 2\n" +
  "CLOCK-CONTRACT one-toggle-per-global-step-one-rising-edge-per-two-steps\n" +
  "PILOT-BOUND global-steps 256 dut-clocks 128\n" +
  "COINCIDENCE atomic-global-pre-state\n" +
  "RESET initial-joint-reset-later-symbolic-joint-peer-response-flush\n" +
  "HOST symbolic-raw-descriptors-responses-including-malformed\n" +
  "FAIRNESS none\n" +
  "GHOST six-generations-raw-syntax-old-source-snapshot-terminal-ticket-match-new-intent-priority\n" +
  "ISSUE saved-outer-authorization-ticket-ABC-MNK-not-current-latest-writer\n" +
  "CLAIM-BOUNDARY bounded-dependency-authorization-only-no-FIFO-retirement-leases-ticket-wrap-liveness-or-full-product-proof\n" +
  "COVERS require-all-five-actual-witnesses-no-vacuous-pass\n" +
  "ADDRESS-KNOWNNESS two-state-formal-all-binary\n" +
  "COMPARISONS adapter-only-pointwise-Boolean-eq-lt-helpers-production-four-state-unchanged\n" +
  "EQUIVALENCE require-pinned-pointwise-SAT-and-negated-miter-control-before-device-task\n" +
  "IR design.lcir sha256 \{sha256_hex(design_ir)}\n" +
  "PRODUCTION-UNCOMPILED \{dut.production_filename} sha256 \{sha256_hex(dut.production_source)}\n" +
  "SOURCE \{dut.filename} sha256 \{sha256_hex(dut.source)}\n" +
  "SOURCE formal-harness.sv sha256 \{sha256_hex(harness)}\n" +
  "PROPERTIES properties.lcfp sha256 \{sha256_hex(properties)}\n" +
  "END\n"
}

///|
fn dependency_job_json(
  dut : DependencyFormalDut,
  harness : String,
  tasks : ReadOnlyArray[GateTask],
) -> String {
  let out = StringBuilder()
  out.write_string(
    "{\n  \"$schema\": \"https://lunachip.dev/schema/yosys-job-v1.json\",\n",
  )
  out.write_string("  \"schema_version\": \"lunachip.yosys-job/v1\",\n")
  out.write_string(
    "  \"top_module\": \"lc_formal_dependency_top\",\n  \"sources\": [\n",
  )
  out.write_string(
    "    {\"path\": \"\{dut.filename}\", \"sha256\": \"\{sha256_hex(dut.source)}\"},\n",
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
/// Generate a dependency-only bounded pilot, not formal-result evidence.
/// Each positive cover requires a retained witness. Negative failures concern
/// isolated monitor comparisons only. No fairness or liveness deadline exists.
/// Raw-head observation assumes that boundary, not FIFO atomicity or ownership.
pub fn generate_dependency_formal_bundle(
  fixture : DependencyFormalFixture,
) -> DependencyFormalBundle raise {
  let view = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let hardware = view.hardware()
  let design = @ir.Design::single("QueuedConcurrentDependencyPilot", hardware)
  let design_ir = @ir_codec.serialize(design)
  guard hardware.domains() is [domain] else {
    raise InvalidFormalBundleIdentity(
      "dependency fixture must have one clock domain",
    )
  }
  let emitted = @rtl.emit_design(design)
  let dut = dependency_formal_dut(view, emitted)
  let (exported, legal, assertions, covers) = dependency_property_export(
    fixture,
  )
  let harness = dependency_harness(fixture, dut, exported.source())
  let properties = exported.manifest()
  let source_set = dependency_source_set(
    fixture, view, design_ir, dut, harness, properties,
  )
  let source = checked_artifact("source-set.lcfs", sha256_hex(source_set))
  let timing = dependency_timing_contract(domain.id(), legal)
  let expected_failure = dependency_expected_failure(
    fixture,
    exported.property_manifest(),
  )
  let tasks = dependency_tasks(
    fixture, source, timing, legal, assertions, covers, expected_failure,
  )
  let selected_safety = if fixture is LatestWriter ||
    fixture is LatestWriterGenerationSupport {
    assertions
  } else {
    [expected_failure]
  }
  validate_task_bindings(tasks, legal, selected_safety, covers)
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
  let job = dependency_job_json(dut, harness, tasks)
  artifacts.push({ path: "job.json", content: job, })
  for task in tasks {
    // Reuse the existing phase-neutral execution selection contract verbatim.
    artifacts.push({
      path: task.name() + ".lcfg",
      content: flux_tile_execution_manifest(
        task, expected_failure, job, properties, source_set,
      ),
    })
  }
  {
    fixture,
    artifacts: ReadOnlyArray::from_array(artifacts),
    tasks,
    job_json: job,
    top_identifier: "lc_formal_dependency_top",
    expected_failure,
  }
}

///|
pub fn standard_dependency_formal_bundles() -> ReadOnlyArray[
  DependencyFormalBundle,
] raise {
  ReadOnlyArray::from_array([
    generate_dependency_formal_bundle(LatestWriter),
    generate_dependency_formal_bundle(NegativeFailedGeneration),
    generate_dependency_formal_bundle(NegativeNewIntentPriority),
    generate_dependency_formal_bundle(NegativeInnerIdentity),
  ])
}
