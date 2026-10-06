///|
fn queue_tasks(
  fixture : QueueFormalFixture,
  source : @formal_core.ArtifactRef,
  timing : @formal_core.FormalTimingContract,
  legal : ReadOnlyArray[String],
  assertions : ReadOnlyArray[String],
  covers : ReadOnlyArray[String],
  expected_failure : String,
) -> ReadOnlyArray[GateTask] raise FormalGateError {
  let tasks : Array[GateTask] = []
  let tool = formal_tool()
  let selected = if queue_positive_profile(fixture) {
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
    expected_status: if queue_positive_profile(fixture) {
      "pass"
    } else {
      "fail"
    },
  })
  if queue_positive_profile(fixture) {
    let (label, suffix) = if fixture is PacketProvenance {
      guard covers is [_, _, label] else {
        raise InvalidFormalBundleIdentity(
          "queue packet provenance fixture must declare three covers",
        )
      }
      (label, "-cover-watched-transfer")
    } else if fixture is RetirementRecords {
      guard covers is [_, label] else {
        raise InvalidFormalBundleIdentity(
          "queue records fixture must declare two covers",
        )
      }
      (label, "-cover-held-younger-collector")
    } else {
      guard covers is [label] else {
        raise InvalidFormalBundleIdentity("queue fixture must have one cover")
      }
      (label, "-cover-full-refill-capture")
    }
    let name = fixture.id() + suffix
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
  ReadOnlyArray::from_array(tasks)
}

///|
fn queue_signal_type_name(signal_type : @ir.SignalType) -> String {
  match signal_type {
    Clock => "Clock"
    Reset => "Reset"
    Bits(_) => "Bits"
    UInt(_) => "UInt"
    SInt(_) => "SInt"
  }
}

///|
fn queue_source_set(
  fixture : QueueFormalFixture,
  view : @flux_tile.QueueConservationFixture,
  design_ir : String,
  dut : QueueFormalDut,
  harness : String,
  properties : String,
) -> String {
  let mutation = match fixture {
    Conservation | PacketProvenance => "none"
    NegativePopulation =>
      "comparison-only-retirement-population-plus-one-after-actual-admission-and-reservation"
    RetirementRecords => "none"
    NegativeHeldPayload =>
      "comparison-only-saved-caller-id-bit-zero-flip-after-genuine-stable-hold"
    NegativePacketProvenance =>
      "comparison-only-saved-lane-bit-zero-flip-after-genuine-watched-raw-matching-response"
  }
  let claim = match fixture {
    PacketProvenance =>
      "bounded-structural-conservation-terminal-record-immutability-oldest-stored-entry-selection-held-completion-and-watched-public-packet-response-head-reservation-ordinal-retirement-provenance-only-no-engine-ownership-fault-progress-correctness-leases-ticket-wrap-liveness-fetched-or-full-product-proof"
    NegativePacketProvenance =>
      "comparison-only-watched-public-packet-response-monitor-sensitivity-control-no-DUT-bug-production-safety-engine-ownership-fault-progress-correctness-leases-liveness-fetched-or-full-product-proof"
    RetirementRecords =>
      "bounded-structural-conservation-terminal-record-immutability-oldest-stored-entry-selection-and-held-completion-only-no-saved-public-admission-packet-engine-ownership-leases-ticket-wrap-liveness-fetched-or-full-product-proof"
    NegativeHeldPayload =>
      "comparison-only-held-completion-monitor-sensitivity-control-no-DUT-bug-production-safety-ownership-liveness-fetched-or-full-product-proof"
    Conservation | NegativePopulation =>
      "bounded-structural-lane-population-and-retirement-events-only-no-saved-packet-engine-ownership-leases-ticket-wrap-liveness-fetched-or-full-product-proof"
  }
  let cover_scope = match fixture {
    PacketProvenance =>
      "positive-requires-one-coherent-watched-public-admission-response-capture-reservation-ordinal-retirement-witness-old-full-refill-and-held-younger-covers-declared-unselected"
    NegativePacketProvenance =>
      "none-selected-all-three-declared-covers-unselected-in-sensitivity-control"
    RetirementRecords =>
      "positive-requires-adjacent-held-oldest-younger-collector-witness-old-full-refill-declared-unselected"
    NegativeHeldPayload =>
      "none-selected-both-declared-covers-unselected-in-sensitivity-control"
    Conservation | NegativePopulation =>
      "positive-requires-actual-full-refill-response-head-capture-witness"
  }
  let ghost = if queue_packet_provenance_profile(fixture) {
    "outstanding-from-public-descriptor-accept-and-public-completion-retire-only-and-independent-saved-public-packet-transfer-ordinal-watch"
  } else {
    "outstanding-from-public-descriptor-accept-and-public-completion-retire-only"
  }
  let observations = StringBuilder()
  for reference in view.observations() {
    observations.write_string(
      "OBSERVATION \{queue_role_name(reference.role())} node \{reference.node().ordinal()} width \{reference.signal_type().width().bits()} type \{queue_signal_type_name(reference.signal_type())}\n",
    )
  }
  "LUNACHIP-PHASE6-FORMAL-SOURCE-SET 1\n" +
  "FAMILY flux-tile-queue-conservation\n" +
  "FIXTURE \{fixture.id()}\n" +
  "TOP lc_formal_queue_top\n" +
  "DUT direct-queued-concurrent-1x1-k2 host-bytes 1024 queue-depth 3\n" +
  "OBSERVATIONS exact-115-typed-existing-node-refs-name-manifest-no-new-IR\n" +
  observations.to_string() +
  "MUTATION \{mutation}\n" +
  "GLOBAL-TIMESTEP engine-steps 2\n" +
  "CLOCK-CONTRACT one-toggle-per-global-step-one-rising-edge-per-two-steps\n" +
  "PILOT-BOUND global-steps 256 dut-clocks 128\n" +
  "COINCIDENCE atomic-global-pre-state\n" +
  "RESET initial-joint-reset-later-symbolic-joint-peer-response-flush\n" +
  "HOST symbolic-raw-descriptors-responses-including-malformed\n" +
  "FAIRNESS none\n" +
  "GHOST \{ghost}\n" +
  "CLAIM-BOUNDARY \{claim}\n" +
  "COVERS \{cover_scope}\n" +
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
fn queue_job_json(
  dut : QueueFormalDut,
  harness : String,
  tasks : ReadOnlyArray[GateTask],
) -> String {
  let out = StringBuilder()
  out.write_string(
    "{\n  \"$schema\": \"https://lunachip.dev/schema/yosys-job-v1.json\",\n",
  )
  out.write_string("  \"schema_version\": \"lunachip.yosys-job/v1\",\n")
  out.write_string(
    "  \"top_module\": \"lc_formal_queue_top\",\n  \"sources\": [\n",
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
/// Generate structural queue proof inputs, not formal-result evidence.
/// The positive bundle includes a separate non-vacuity cover; the negative
/// bundles select only their population or held-payload sensitivity assertion.
/// RetirementRecords adds immutable terminal records and oldest stored-entry
/// selection, with its own adjacent-edge non-vacuity cover.
/// PacketProvenance adds independently saved public packet transfer identity;
/// its negative changes only one checked FIFO-response comparison.
/// No internal progress, fairness or full-device ownership is assumed or claimed.
///
/// ```mbt check
/// test {
///   let bundle = @formal.generate_queue_formal_bundle(Conservation)
///   assert_eq(bundle.fixture().id(), "phase6-queue-conservation")
///   assert_eq(bundle.tasks().length(), 2)
///   assert_eq(bundle.artifacts().length(), 11)
/// }
/// ```
pub fn generate_queue_formal_bundle(
  fixture : QueueFormalFixture,
) -> QueueFormalBundle raise {
  let view = @flux_tile.queued_concurrent_queue_formal_fixture()
  let hardware = view.hardware()
  let design = @ir.Design::single(
    "QueuedConcurrentQueueConservationPilot", hardware,
  )
  let design_ir = @ir_codec.serialize(design)
  guard hardware.domains() is [domain] else {
    raise InvalidFormalBundleIdentity(
      "queue fixture must have one clock domain",
    )
  }
  let emitted = @rtl.emit_design(design)
  let dut = queue_formal_dut(view, emitted)
  let (exported, legal, assertions, covers) = queue_property_export(fixture)
  let harness = queue_harness(fixture, dut, exported.source())
  let properties = exported.manifest()
  let source_set = queue_source_set(
    fixture, view, design_ir, dut, harness, properties,
  )
  let source = checked_artifact("source-set.lcfs", sha256_hex(source_set))
  let timing = queue_timing_contract(domain.id(), legal)
  let expected_failure = queue_expected_failure(
    fixture,
    exported.property_manifest(),
  )
  let tasks = queue_tasks(
    fixture, source, timing, legal, assertions, covers, expected_failure,
  )
  let selected_safety = if queue_positive_profile(fixture) {
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
  let job = queue_job_json(dut, harness, tasks)
  artifacts.push({ path: "job.json", content: job, })
  for task in tasks {
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
    top_identifier: "lc_formal_queue_top",
    expected_failure,
  }
}

///|
pub fn standard_queue_formal_bundles() -> ReadOnlyArray[QueueFormalBundle] raise {
  ReadOnlyArray::from_array([
    generate_queue_formal_bundle(Conservation),
    generate_queue_formal_bundle(NegativePopulation),
    generate_queue_formal_bundle(RetirementRecords),
    generate_queue_formal_bundle(NegativeHeldPayload),
    generate_queue_formal_bundle(PacketProvenance),
    generate_queue_formal_bundle(NegativePacketProvenance),
  ])
}
