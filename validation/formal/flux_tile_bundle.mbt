///|
fn flux_tile_tasks(
  fixture : FluxTileFormalFixture,
  source : @formal_core.ArtifactRef,
  timing : @formal_core.FormalTimingContract,
  legal : ReadOnlyArray[String],
  assertions : ReadOnlyArray[String],
  covers : ReadOnlyArray[String],
  expected_failure : String,
) -> ReadOnlyArray[GateTask] raise FormalGateError {
  let tasks : Array[GateTask] = []
  let tool = formal_tool()
  let selected = if fixture is PublicTransport {
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
    expected_status: if fixture is PublicTransport {
      "pass"
    } else {
      "fail"
    },
  })
  if fixture is PublicTransport {
    let suffixes = ["held-request", "owned-response", "first-terminal"]
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
fn flux_tile_source_set(
  fixture : FluxTileFormalFixture,
  design_ir : String,
  dut : FluxTileFormalDut,
  harness : String,
  properties : String,
) -> String {
  let mutation = match fixture {
    PublicTransport => "none"
    NegativeRequestBounds => "wrapper-observation-address-bit32-set"
    NegativeRequestStability => "wrapper-observation-data-bit0-after-real-stall"
    DirectedFirstTerminal => "none"
  }
  "LUNACHIP-PHASE6-FORMAL-SOURCE-SET 1\n" +
  "FAMILY flux-tile-public-transport\n" +
  "FIXTURE \{fixture.id()}\n" +
  "TOP lc_formal_flux_tile_top\n" +
  "DUT fetched-concurrent-1x1-k2 host-bytes 1024 ring-depth 4 queue-depth 2\n" +
  "OBSERVATIONS public-pins-only-name-manifest\n" +
  "MUTATION \{mutation}\n" +
  "GLOBAL-TIMESTEP engine-steps 2\n" +
  "CLOCK-CONTRACT one-toggle-per-global-step-one-rising-edge-per-two-steps\n" +
  "PILOT-BOUND global-steps 256 dut-clocks 128\n" +
  "COINCIDENCE atomic-global-pre-state\n" +
  "RESET initial-joint-reset-later-symbolic-joint-peer-response-flush\n" +
  "HOST symbolic-descriptors-config-publication-responses-including-malformed\n" +
  "FAIRNESS none\n" +
  "PILOT-LIMIT write-path-assertion-branch-unexercised\n" +
  "REMAINING actual-write-cover-and-safety-horizon-reaching-write\n" +
  "CLAIM-BOUNDARY bounded-public-transport-no-private-queue-dependency-liveness-or-full-product-proof\n" +
  "ADDRESS-KNOWNNESS two-state-formal-all-binary\n" +
  "IR design.lcir sha256 \{sha256_hex(design_ir)}\n" +
  "SOURCE \{dut.filename} sha256 \{sha256_hex(dut.source)}\n" +
  "SOURCE formal-harness.sv sha256 \{sha256_hex(harness)}\n" +
  "PROPERTIES properties.lcfp sha256 \{sha256_hex(properties)}\n" +
  "END\n"
}

///|
fn flux_tile_job_json(
  dut : FluxTileFormalDut,
  harness : String,
  tasks : ReadOnlyArray[GateTask],
) -> String {
  let out = StringBuilder()
  out.write_string("{\n")
  out.write_string(
    "  \"$schema\": \"https://lunachip.dev/schema/yosys-job-v1.json\",\n",
  )
  out.write_string("  \"schema_version\": \"lunachip.yosys-job/v1\",\n")
  out.write_string("  \"top_module\": \"lc_formal_flux_tile_top\",\n")
  out.write_string("  \"sources\": [\n")
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
fn flux_tile_execution_manifest(
  task : GateTask,
  expected_failure : String,
  job : String,
  properties : String,
  source_set : String,
) -> String {
  let (assumptions, selected) = match task.task() {
    Bounded(value) => (value.assumptions(), value.properties())
    Unbounded(value) => (value.assumptions(), value.properties())
  }
  let selections = StringBuilder()
  selections.write_string("SELECTED-ASSUMPTIONS \{assumptions.length()}\n")
  for index, label in assumptions {
    selections.write_string("A \{index} \{label}\n")
  }
  selections.write_string("SELECTED-PROPERTIES \{selected.length()}\n")
  for index, label in selected {
    selections.write_string("P \{index} \{label}\n")
  }
  let failure = if task.task_class() is BoundedCoverTask {
    "none"
  } else {
    expected_failure
  }
  "LUNACHIP-PHASE6-FORMAL-EXECUTION 1\n" +
  "TASK \{task.name()} sha256 \{sha256_hex(task.task().to_canonical_text())}\n" +
  "JOB job.json sha256 \{sha256_hex(job)}\n" +
  "PROPERTIES properties.lcfp sha256 \{sha256_hex(properties)}\n" +
  "SOURCE-SET source-set.lcfs sha256 \{sha256_hex(source_set)}\n" +
  "MODE \{job_mode(task.task_class())}\n" +
  "CLAIM \{job_claim(task.task_class())}\n" +
  "BOUND \{task.bound()}\n" +
  "TIMEOUT-SECONDS \{task.timeout_seconds()}\n" +
  "ENGINE smtbmc\nSOLVER bitwuzla\nMULTICLOCK on\n" +
  "ADDRESS-KNOWNNESS two-state-formal-all-binary\n" +
  "TIMING-CONTRACT formal-task-schema-2\n" +
  "BOUND-MAPPING 256-global-steps-128-dut-clocks\n" +
  selections.to_string() +
  "EXPECTED-STATUS \{task.expected_status()}\n" +
  "EXPECTED-FAILURE \{failure}\n" +
  "RUNNER scripts/phase4-yosys-run.sh oci formal \{task.name()} BUNDLE OUTPUT\n" +
  "END\n"
}

///|
/// Generate a bounded public-transport pilot, not a proof result. The three
/// covers require actual witnesses before accepting non-vacuous tool evidence.
/// No fairness, private dependency, eventual completion or 8x8 claim is made.
/// The 128-clock pilot cannot exercise a successful Store from joint reset.
/// Write predicates are generated but their branch is unexercised: useful write
/// evidence requires an actual-write cover and safety horizon reaching that path.
/// DirectedFirstTerminal instead generates one separately constrained legal
/// Fence cover, preserving the original symbolic pilot tasks and bundle bytes.
pub fn generate_flux_tile_formal_bundle(
  fixture : FluxTileFormalFixture,
) -> FluxTileFormalBundle raise {
  if fixture is DirectedFirstTerminal {
    return generate_directed_terminal_bundle()
  }
  let design = flux_tile_formal_design()
  let design_ir = @ir_codec.serialize(design)
  guard design.top_module() is Some(hardware) else { raise MissingTopModule }
  guard hardware.domains() is [domain] else {
    raise InvalidFormalBundleIdentity(
      "FluxTile formal fixture must have one clock domain",
    )
  }
  let emitted = @rtl.emit_design(design)
  let dut = flux_tile_formal_dut(hardware, emitted)
  let (exported, legal, assertions, covers) = flux_tile_property_export()
  let harness = flux_tile_harness(fixture, dut, exported.source())
  let properties = exported.manifest()
  let source_set = flux_tile_source_set(
    fixture, design_ir, dut, harness, properties,
  )
  let source = checked_artifact("source-set.lcfs", sha256_hex(source_set))
  let timing = flux_tile_timing_contract(domain.id(), legal)
  let expected_failure = flux_tile_expected_failure(
    fixture,
    exported.property_manifest(),
  )
  let tasks = flux_tile_tasks(
    fixture, source, timing, legal, assertions, covers, expected_failure,
  )
  let selected_safety = if fixture is PublicTransport {
    assertions
  } else {
    [expected_failure]
  }
  validate_task_bindings(tasks, legal, selected_safety, covers)
  let artifacts : Array[FormalBundleArtifact] = [
    { path: "design.lcir", content: design_ir, },
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
  let job = flux_tile_job_json(dut, harness, tasks)
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
    top_identifier: "lc_formal_flux_tile_top",
    expected_failure,
  }
}

///|
pub fn standard_flux_tile_formal_bundles() -> ReadOnlyArray[
  FluxTileFormalBundle,
] raise {
  ReadOnlyArray::from_array([
    generate_flux_tile_formal_bundle(PublicTransport),
    generate_flux_tile_formal_bundle(NegativeRequestBounds),
    generate_flux_tile_formal_bundle(NegativeRequestStability),
  ])
}
