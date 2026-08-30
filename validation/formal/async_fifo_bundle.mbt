///|
fn async_fifo_expected_failure(
  fixture : AsyncFifoFormalFixture,
  properties : @formal_core.FormalPropertyManifest,
) -> String raise FormalGateError {
  let name = match fixture {
    ValidAsyncFifo => return "none"
    BrokenAsyncFifoGray => "write_gray_equation_exact"
    BrokenAsyncFifoFull => "full_equation_exact"
    BrokenAsyncFifoAddress => "write_address_selection_exact"
    BrokenAsyncFifoStorageOrder => "watched_token_data_integrity"
    BrokenAsyncFifoReadPipeline => "read_gray_source_pipeline_exact"
    BrokenAsyncFifoWritePipeline => "write_gray_destination_pipeline_exact"
    BrokenAsyncFifoWriteAddressBounds => "write_address_in_bounds"
    BrokenAsyncFifoReadAddressBounds => "read_address_in_bounds"
  }
  for property in properties.properties() {
    if property.name() == name {
      return property.stable_name()
    }
  }
  raise InvalidAsyncFifoFormalBundle("missing expected property label")
}

///|
fn async_fifo_timing(
  source : @ir.ClockDomainId,
  destination : @ir.ClockDomainId,
  legal : ReadOnlyArray[String],
  fairness : ReadOnlyArray[String],
) -> @formal_core.FormalTimingContract raise FormalGateError {
  let path = "lc_formal_async_fifo_top"
  let source_signal = named_signal(path, "source_clock")
  let destination_signal = named_signal(path, "destination_clock")
  let source_clock = @formal_core.FormalClockBinding::checked(
    source,
    source_signal,
    Rising,
  ) catch {
    error => raise FormalContract(error)
  }
  let destination_clock = @formal_core.FormalClockBinding::checked(
    destination,
    destination_signal,
    Rising,
  ) catch {
    error => raise FormalContract(error)
  }
  @formal_core.FormalTimingContract::checked(
    @formal_core.GlobalFormalTimestep::checked(2),
    [source_clock, destination_clock],
    legal,
    fairness,
    AtomicGlobalPreState,
  ) catch {
    error => raise FormalContract(error)
  }
}

///|
fn async_fifo_tasks(
  fixture : AsyncFifoFormalFixture,
  source : @formal_core.ArtifactRef,
  timing : @formal_core.FormalTimingContract,
  assumptions : ReadOnlyArray[String],
  assertions : ReadOnlyArray[String],
  covers : ReadOnlyArray[String],
) -> ReadOnlyArray[GateTask] raise FormalGateError {
  let tool = formal_tool()
  let tasks : Array[GateTask] = []
  let bmc_name = fixture.id() + "-bmc"
  let bmc_bound = async_fifo_safety_bmc_bound(fixture)
  let bmc = @formal_core.BoundedProofTask::checked(
    bmc_name,
    source,
    tool,
    "smtbmc-bitwuzla",
    BoundedSafety,
    @formal_core.ProofBound::checked(bmc_bound),
    assumptions,
    assertions,
  ).with_timing_contract(timing) catch {
    error => raise FormalContract(error)
  }
  tasks.push({
    name: bmc_name,
    task: Bounded(bmc),
    task_class: BoundedSafetyTask,
    bound: bmc_bound,
    timeout_seconds: 900,
    expected_status: if fixture is ValidAsyncFifo {
      "pass"
    } else {
      "fail"
    },
  })
  if fixture is ValidAsyncFifo {
    let suffixes = [
      "coincident", "full", "write-wrap", "read-wrap", "simultaneous", "watched",
    ]
    for index, label in covers {
      let name = "valid-async-fifo-cover-" + suffixes[index]
      let cover = @formal_core.BoundedProofTask::checked(
        name,
        source,
        tool,
        "smtbmc-bitwuzla",
        BoundedCover,
        @formal_core.ProofBound::checked(ASYNC_FIFO_STANDARD_TASK_BOUND),
        assumptions,
        [label],
      ).with_timing_contract(timing) catch {
        error => raise FormalContract(error)
      }
      tasks.push({
        name,
        task: Bounded(cover),
        task_class: BoundedCoverTask,
        bound: ASYNC_FIFO_STANDARD_TASK_BOUND,
        timeout_seconds: 900,
        expected_status: "pass",
      })
    }
  }
  ReadOnlyArray::from_array(tasks)
}

///|
fn async_fifo_job(
  dut : AsyncFifoFormalDut,
  harness : String,
  tasks : ReadOnlyArray[GateTask],
) -> String {
  let out = StringBuilder()
  out.write_string(
    "{\n  \"$schema\": \"https://lunachip.dev/schema/yosys-job-v1.json\",\n  \"schema_version\": \"lunachip.yosys-job/v1\",\n  \"top_module\": \"lc_formal_async_fifo_top\",\n  \"sources\": [\n",
  )
  out.write_string(
    "    {\"path\": \"\{dut.filename}\", \"sha256\": \"\{sha256_hex(dut.source)}\"},\n    {\"path\": \"formal-harness.sv\", \"sha256\": \"\{sha256_hex(harness)}\"}\n  ],\n  \"formal_tasks\": [\n",
  )
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
fn async_fifo_source_set(
  fixture : AsyncFifoFormalFixture,
  ir : String,
  dut : AsyncFifoFormalDut,
  harness : String,
  properties : String,
) -> String {
  "LUNACHIP-PHASE5-FORMAL-SOURCE-SET 1\n" +
  "FAMILY async-fifo\nFIXTURE \{fixture.id()}\nTOP lc_formal_async_fifo_top\n" +
  "PROFILE depth=4 payload=bits8 synchronizer-stages=2\n" +
  "GLOBAL-TIMESTEP engine-steps 2\nCLOCK-MAX-IDLE-INTERVALS 3\nEVENTUAL-READY-MAX-DESTINATION-EDGES 3\nCOINCIDENCE atomic-global-pre-state\n" +
  "RESET coordinated-idle-initialization-unilateral-reset-excluded\n" +
  "SAFETY-BMC-BOUND engine-steps \{async_fifo_safety_bmc_bound(fixture)}\nCOVER-BOUND engine-steps \{ASYNC_FIFO_STANDARD_TASK_BOUND}\n" +
  "VALID-SAFETY-BMC-DERIVATION engine-steps 204 formula 2*(20-activation+80-completion+2-observation)\n" +
  "COMPLETION-DRAIN-BOUND scheduling-intervals 76 formula (3-sync-and-nonempty+4-ready-edges*4-tokens)*4-clock-gap\n" +
  "COMPLETION-BOUND scheduling-intervals 80 conditional-on-bounded-clocks-eventual-ready-and-at-least-80-remaining-scheduling-intervals\n" +
  "CLAIM-BOUNDARY digital-two-state-bounded-no-metastability-mtbf-placement-reset-recovery-or-timing\nADDRESS-KNOWNNESS two-state-formal-all-binary\n" +
  "IR design.lcir sha256 \{sha256_hex(ir)}\nSOURCE \{dut.filename} sha256 \{sha256_hex(dut.source)}\nSOURCE formal-harness.sv sha256 \{sha256_hex(harness)}\nPROPERTIES properties.lcfp sha256 \{sha256_hex(properties)}\nEND\n"
}

///|
fn async_fifo_execution(
  task : GateTask,
  failure : String,
  job : String,
  properties : String,
  source_set : String,
) -> String {
  let (assumptions, selected) = match task.task() {
    Bounded(value) => (value.assumptions(), value.properties())
    Unbounded(value) => (value.assumptions(), value.properties())
  }
  let picks = StringBuilder()
  picks.write_string("SELECTED-ASSUMPTIONS \{assumptions.length()}\n")
  for index, label in assumptions {
    picks.write_string("A \{index} \{label}\n")
  }
  picks.write_string("SELECTED-PROPERTIES \{selected.length()}\n")
  for index, label in selected {
    picks.write_string("P \{index} \{label}\n")
  }
  let expected = if task.task_class() is BoundedCoverTask {
    "none"
  } else {
    failure
  }
  "LUNACHIP-PHASE5-FORMAL-EXECUTION 1\nTASK \{task.name()} sha256 \{sha256_hex(task.task().to_canonical_text())}\n" +
  "JOB job.json sha256 \{sha256_hex(job)}\nPROPERTIES properties.lcfp sha256 \{sha256_hex(properties)}\nSOURCE-SET source-set.lcfs sha256 \{sha256_hex(source_set)}\n" +
  "MODE \{job_mode(task.task_class())}\nCLAIM \{job_claim(task.task_class())}\nBOUND \{task.bound()}\nTIMEOUT-SECONDS \{task.timeout_seconds()}\nENGINE smtbmc\nSOLVER bitwuzla\nMULTICLOCK on\nADDRESS-KNOWNNESS two-state-formal-all-binary\nTIMING-CONTRACT formal-task-schema-2\nCOMPLETION-BOUND conditional 80-scheduling-intervals-with-at-least-80-remaining-bmc-intervals\n" +
  picks.to_string() +
  "EXPECTED-STATUS \{task.expected_status()}\nEXPECTED-FAILURE \{expected}\nRUNNER scripts/phase4-yosys-run.sh oci formal \{task.name()} BUNDLE OUTPUT\nEND\n"
}

///|
pub fn generate_async_fifo_formal_bundle(
  fixture : AsyncFifoFormalFixture,
) -> AsyncFifoFormalBundle raise {
  let built = async_fifo_formal_design()
  let design = built.design
  let ir = @ir_codec.serialize(design)
  guard design.top_module() is Some(hardware_module) else {
    raise MissingTopModule
  }
  guard hardware_module.domains() is [source_domain, destination_domain] else {
    raise InvalidAsyncFifoFormalBundle("expected two sparse domains")
  }
  let emitted = @rtl.emit_design(design)
  let production_dut = top_emitted_module(emitted)
  let dut = async_fifo_formal_dut(design, emitted, production_dut)
  let (exported, legal, fairness, assumptions, assertions, covers) = async_fifo_property_export()
  let harness = async_fifo_harness(
    fixture,
    design,
    emitted,
    dut,
    exported.source(),
    80,
  )
  let properties = exported.manifest()
  let source_set = async_fifo_source_set(fixture, ir, dut, harness, properties)
  let source = checked_artifact("source-set.lcfs", sha256_hex(source_set))
  let timing = async_fifo_timing(
    source_domain.id(),
    destination_domain.id(),
    legal,
    fairness,
  )
  let tasks = async_fifo_tasks(
    fixture, source, timing, assumptions, assertions, covers,
  )
  validate_task_bindings(tasks, assumptions, assertions, covers)
  let expected_failure = async_fifo_expected_failure(
    fixture,
    exported.property_manifest(),
  )
  let artifacts : Array[FormalBundleArtifact] = [
    { path: "design.lcir", content: ir },
    { path: dut.filename, content: dut.source },
    { path: "formal-harness.sv", content: harness },
    { path: "properties.lcfp", content: properties },
    { path: "source-set.lcfs", content: source_set },
  ]
  for task in tasks {
    artifacts.push({
      path: task.name() + ".lcft",
      content: task.task().to_canonical_text(),
    })
  }
  let job = async_fifo_job(dut, harness, tasks)
  artifacts.push({ path: "job.json", content: job })
  for task in tasks {
    artifacts.push({
      path: task.name() + ".lcfg",
      content: async_fifo_execution(
        task, expected_failure, job, properties, source_set,
      ),
    })
  }
  {
    fixture,
    artifacts: ReadOnlyArray::from_array(artifacts),
    tasks,
    job_json: job,
    expected_failure,
    completion_bound: ASYNC_FIFO_COMPLETION_INTERVALS,
  }
}

///|
pub fn standard_async_fifo_formal_bundles() -> ReadOnlyArray[
  AsyncFifoFormalBundle,
] raise {
  ReadOnlyArray::from_array([
    generate_async_fifo_formal_bundle(ValidAsyncFifo),
    generate_async_fifo_formal_bundle(BrokenAsyncFifoGray),
    generate_async_fifo_formal_bundle(BrokenAsyncFifoFull),
    generate_async_fifo_formal_bundle(BrokenAsyncFifoAddress),
    generate_async_fifo_formal_bundle(BrokenAsyncFifoStorageOrder),
    generate_async_fifo_formal_bundle(BrokenAsyncFifoReadPipeline),
    generate_async_fifo_formal_bundle(BrokenAsyncFifoWritePipeline),
    generate_async_fifo_formal_bundle(BrokenAsyncFifoWriteAddressBounds),
    generate_async_fifo_formal_bundle(BrokenAsyncFifoReadAddressBounds),
  ])
}
