///|
fn direct8_completion_tasks(
  fixture : DirectCompletionFixture,
  source : @formal_core.ArtifactRef,
  timing : @formal_core.FormalTimingContract,
  assumptions : ReadOnlyArray[String],
  assertions : ReadOnlyArray[String],
  covers : ReadOnlyArray[String],
  expected_failure : String,
) -> ReadOnlyArray[GateTask] raise FormalGateError {
  guard covers is [terminal, retirement, useful] else {
    raise InvalidFormalBundleIdentity("direct8 completion cover roster")
  }
  let bound = direct8_completion_budget().global_steps
  let tasks : Array[GateTask] = []
  let tool = formal_tool()
  if !(fixture is UsefulStore) {
    let name = direct8_completion_id(fixture) + "-bmc"
    let selected : ReadOnlyArray[String] = if fixture is NegativeDeadline {
      [expected_failure]
    } else {
      assertions
    }
    let task = @formal_core.BoundedProofTask::checked(
      name,
      source,
      tool,
      "smtbmc-bitwuzla",
      BoundedSafety,
      @formal_core.ProofBound::checked(bound),
      assumptions,
      selected,
    ).with_timing_contract(timing) catch {
      error => raise FormalContract(error)
    }
    tasks.push({
      name,
      task: Bounded(task),
      task_class: BoundedSafetyTask,
      bound,
      timeout_seconds: 600,
      expected_status: if fixture is NegativeDeadline {
        "fail"
      } else {
        "pass"
      },
    })
  }
  let selections : Array[(String, String)] = match fixture {
    Eventual =>
      [(terminal, "watched-terminal"), (retirement, "watched-retirement")]
    UsefulStore => [(useful, "useful-store-write-ack-retirement")]
    NegativeDeadline => []
  }
  for (label, suffix) in selections {
    let name = direct8_completion_id(fixture) + "-cover-" + suffix
    let task = @formal_core.BoundedProofTask::checked(
      name,
      source,
      tool,
      "smtbmc-bitwuzla",
      BoundedCover,
      @formal_core.ProofBound::checked(bound),
      assumptions,
      [label],
    ).with_timing_contract(timing) catch {
      error => raise FormalContract(error)
    }
    tasks.push({
      name,
      task: Bounded(task),
      task_class: BoundedCoverTask,
      bound,
      timeout_seconds: 600,
      expected_status: "pass",
    })
  }
  ReadOnlyArray::from_array(tasks)
}

///|
fn direct8_completion_execution_manifest(
  task : GateTask,
  expected_failure : String,
  job : String,
  properties : String,
  source_set : String,
) -> String raise FormalGateError {
  let original = flux_tile_execution_manifest(
    task, expected_failure, job, properties, source_set,
  )
  let marker = "BOUND-MAPPING 256-global-steps-128-dut-clocks\n"
  dependency_require_marker(original, marker)
  original.replace(
    old=marker,
    new="BOUND-MAPPING 23552-global-steps-11776-dut-clocks\n",
  )
}
