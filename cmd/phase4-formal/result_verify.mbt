///|
fn proof_result_task(
  result : @formal_core.ProofResultManifest,
) -> @formal_core.ProofTaskManifest {
  match result {
    BoundedResult(value) => Bounded(value.task())
    UnboundedResult(value) => Unbounded(value.task())
  }
}

///|
fn verify_result(
  bundle : String,
  task_name : String,
  result_file : String,
) -> Unit raise {
  let task_file = bundle + "/" + task_name + ".lcft"
  if !@fs.path_exists(task_file) || !@fs.path_exists(result_file) {
    fail("formal task or result is missing")
  }
  let task = @formal_core.parse_proof_task(@fs.read_file_to_string(task_file))
  if proof_task_name(task) != task_name {
    fail("task filename/name mismatch")
  }
  let result = @formal_core.parse_proof_result(
    @fs.read_file_to_string(result_file),
  )
  if proof_result_task(result) != task {
    fail("formal result does not bind the requested task")
  }
  println("formal result binding verified: \{task_name}")
}
