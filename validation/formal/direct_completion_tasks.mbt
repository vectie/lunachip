///|
fn direct_completion_tasks(
  fixture : DirectCompletionFixture,
  source : @formal_core.ArtifactRef,
  timing : @formal_core.FormalTimingContract,
  assumptions : ReadOnlyArray[String],
  assertions : ReadOnlyArray[String],
  covers : ReadOnlyArray[String],
  expected_failure : String,
) -> ReadOnlyArray[GateTask] raise FormalGateError {
  guard covers is [terminal, retirement, useful] else {
    raise InvalidFormalBundleIdentity(
      "direct completion: exactly three named covers",
    )
  }
  let tasks : Array[GateTask] = []
  let tool = formal_tool()
  if !(fixture is UsefulStore) {
    let name = fixture.id() + "-bmc"
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
      @formal_core.ProofBound::checked(640),
      assumptions,
      selected,
    ).with_timing_contract(timing) catch {
      error => raise FormalContract(error)
    }
    tasks.push({
      name,
      task: Bounded(task),
      task_class: BoundedSafetyTask,
      bound: 640,
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
    let name = fixture.id() + "-cover-" + suffix
    let task = @formal_core.BoundedProofTask::checked(
      name,
      source,
      tool,
      "smtbmc-bitwuzla",
      BoundedCover,
      @formal_core.ProofBound::checked(640),
      assumptions,
      [label],
    ).with_timing_contract(timing) catch {
      error => raise FormalContract(error)
    }
    tasks.push({
      name,
      task: Bounded(task),
      task_class: BoundedCoverTask,
      bound: 640,
      timeout_seconds: 600,
      expected_status: "pass",
    })
  }
  ReadOnlyArray::from_array(tasks)
}

///|
fn direct_completion_job_json(
  dut : QueueFormalDut,
  harness : String,
  tasks : ReadOnlyArray[GateTask],
) -> String {
  let out = StringBuilder()
  out.write_string(
    "{\n  \"$schema\": \"https://lunachip.dev/schema/yosys-job-v1.json\",\n  \"schema_version\": \"lunachip.yosys-job/v1\",\n  \"top_module\": \"lc_formal_direct_completion_top\",\n  \"sources\": [\n",
  )
  out.write_string(
    "    {\"path\": \"\{dut.filename}\", \"sha256\": \"\{sha256_hex(dut.source)}\"},\n",
  )
  out.write_string(
    "    {\"path\": \"formal-harness.sv\", \"sha256\": \"\{sha256_hex(harness)}\"}\n  ],\n  \"formal_tasks\": [\n",
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
fn direct_completion_execution_manifest(
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
  // Reuse the existing execution/selection/receipt contract; only this family's
  // exact bound mapping differs. Never modify older source-set or task bytes.
  original.replace(
    old=marker,
    new="BOUND-MAPPING 640-global-steps-320-dut-clocks\n",
  )
}
