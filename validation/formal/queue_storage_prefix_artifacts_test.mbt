///|
test "original FIFO prefix artifact export is deterministic and not a result" {
  let artifacts = @formal.generate_queue_storage_prefix_proof_artifacts()
  assert_eq(artifacts, @formal.generate_queue_storage_prefix_proof_artifacts())
  assert_eq(artifacts.map(artifact => artifact.path()), [
    "sequential.lcir", "sequential-production.sv", "sequential-boolean.sv", "bridge.sv",
    "negative-watched-response.sv", "properties.lcfp", "names.lcnm", "bridge-inputs.txt",
  ])
  let report = artifacts[7].content()
  guard report
    .split(
      "CANDIDATE-STORAGE-PROBE ONLY-not-accepted-cut-projection-or-proof\n",
    )
    .to_array()
    is [inventory, _] else {
    fail("one complete nested candidate report required")
  }
  assert_true(
    inventory.has_prefix(
      "SCOPE binary-original-FIFO-to-head-prefix-inputs-not-proof-or-full-retirement\n",
    ),
  )
  assert_eq(inventory.split("\nASSUMPTION ").count(), 2)
  assert_eq(inventory.split("\nASSERTION ").count(), 8)
  assert_eq(inventory.split("\nGLOBAL-ASSERTION ").count(), 2)
  assert_eq(inventory.split("\nMEMORY-ASSERTION ").count(), 9)
  assert_eq(inventory.split("\nCUT ").count(), 60)
  assert_eq(inventory.split("\nREGISTER ").count(), 29)
  assert_eq(inventory.split("\nMEMORY ").count(), 5)
  assert_true(inventory.contains("no-zero-storage-premise"))
  assert_true(
    inventory.contains(
      "QUALIFICATION Boolean-helper-equivalence-prepared-model-review-and-engine-execution-pending\n",
    ),
  )
}
