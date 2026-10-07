///|
fn fetched_useful_timing(
  domain : @ir.ClockDomainId,
  assumptions : ReadOnlyArray[String],
) -> @formal_core.FormalTimingContract raise FormalGateError {
  let clock_signal = named_signal("lc_formal_fetched_useful_top", "clock")
  let clock = @formal_core.FormalClockBinding::checked(
    domain,
    clock_signal,
    Rising,
  ) catch {
    error => raise FormalContract(error)
  }
  @formal_core.FormalTimingContract::checked(
    @formal_core.GlobalFormalTimestep::checked(2),
    [clock],
    assumptions,
    [],
    AtomicGlobalPreState,
  ) catch {
    error => raise FormalContract(error)
  }
}

///|
fn fetched_useful_tasks(
  source : @formal_core.ArtifactRef,
  timing : @formal_core.FormalTimingContract,
  assumptions : ReadOnlyArray[String],
  assertions : ReadOnlyArray[String],
  covers : ReadOnlyArray[String],
) -> ReadOnlyArray[GateTask] raise FormalGateError {
  guard covers is [cover] else {
    raise InvalidFormalBundleIdentity("fetched useful one cover")
  }
  let tasks : Array[GateTask] = []
  let tool = formal_tool()
  for
    (suffix, kind, task_class, selected) in [
      (
        "-bmc",
        @formal_core.BoundedMode::BoundedSafety,
        BoundedSafetyTask,
        assertions,
      ),
      (
        "-cover-write-ack-retirement",
        BoundedCover,
        BoundedCoverTask,
        ReadOnlyArray::from_array([cover]),
      ),
    ] {
    let name = fetched_useful_id() + suffix
    let bounded = @formal_core.BoundedProofTask::checked(
      name,
      source,
      tool,
      "smtbmc-bitwuzla",
      kind,
      @formal_core.ProofBound::checked(1024),
      assumptions,
      selected,
    ).with_timing_contract(timing) catch {
      error => raise FormalContract(error)
    }
    tasks.push({
      name,
      task: Bounded(bounded),
      task_class,
      bound: 1024,
      timeout_seconds: 600,
      expected_status: "pass",
    })
  }
  ReadOnlyArray::from_array(tasks)
}

///|
fn fetched_useful_job(
  dut : FluxTileFormalDut,
  harness : String,
  tasks : ReadOnlyArray[GateTask],
) -> String raise FormalGateError {
  let original = flux_tile_job_json(dut, harness, tasks)
  let marker = "\"top_module\": \"lc_formal_flux_tile_top\""
  dependency_require_marker(original, marker)
  original.replace(
    old=marker,
    new="\"top_module\": \"lc_formal_fetched_useful_top\"",
  )
}

///|
fn fetched_useful_execution(
  task : GateTask,
  job : String,
  properties : String,
  source_set : String,
) -> String raise FormalGateError {
  let original = flux_tile_execution_manifest(
    task, "none", job, properties, source_set,
  )
  let marker = "BOUND-MAPPING 256-global-steps-128-dut-clocks\n"
  dependency_require_marker(original, marker)
  original.replace(
    old=marker,
    new="BOUND-MAPPING 1024-global-steps-512-dut-clocks\n",
  )
}
