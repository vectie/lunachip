///|
test "owned reader poison and joint reset replay is deterministic and identity bound" {
  let bundle = @phase6.generate_fault_reset_bundle()
  let repeated = @phase6.generate_fault_reset_bundle()
  assert_eq(bundle.id(), "fetched-concurrent-1x1-k64-reader-poison-reset")
  assert_true(bundle.post_reset_cycles() > 258)
  assert_true(bundle.post_reset_cycles() <= 8192)
  assert_eq(bundle.expected_tsv(), repeated.expected_tsv())
  assert_eq(bundle.ports().filter(port => port.is_output()).length(), 30)
  assert_eq(bundle.artifacts().length(), 11)
  let mut found_workload = false
  for index, artifact in bundle.artifacts() {
    assert_eq(artifact.path, repeated.artifacts()[index].path)
    assert_eq(artifact.content, repeated.artifacts()[index].content)
    if artifact.path == "workload.audit" {
      found_workload = true
      assert_true(artifact.content.contains("COMPLETIONS 6\n"))
      assert_true(artifact.content.contains("WRITE-BYTES 0\nREADER-FAULT 5\n"))
      assert_true(
        artifact.content.contains(
          "TRANSPORT-FAULT-ADDRESS 3072\nLOADER-CANCEL-FAULT 15\n",
        ),
      )
      assert_true(
        artifact.content.contains(
          "POISON-ACTIVE-ADVANCE 1\nCOMPLETION-HOLD-CYCLES 32\n",
        ),
      )
      assert_true(
        artifact.content.contains(
          "HELD-CAPTURE-EDGES 1\nPOISON-QUIET-CYCLES 8\n",
        ),
      )
      assert_true(
        artifact.content.contains(
          "DRAIN-ACCEPTED-STEPS 16\nDRAIN-ACTIVE-CYCLES 16\nDRAIN-ELAPSED-CYCLES 17\nDRAIN-STALL-CYCLES 0\nDRAIN-CAPTURE-CYCLES 1\nJOINT-RESETS 2\n",
        ),
      )
      assert_true(
        artifact.content.contains(
          "PENDING-RESET-TAG 32\nSTALE-SLOT-FAULT 4\nRECOVERY-FENCE-FAULT 0\n",
        ),
      )
      assert_true(
        artifact.content.contains(
          "RECOVERY-REQUESTS 64\nRECOVERY-NEXT-TAG 64\nHOST-BYTES match\n",
        ),
      )
      assert_true(artifact.content.contains("CLAIM generated-reference-only\n"))
    }
  }
  assert_true(found_workload)
  match bundle.compare_actual_tsv(bundle.expected_tsv()) {
    Equal => ()
    _ => fail("fault/reset reference trace failed its exact comparator")
  }
  let lines = bundle
    .expected_tsv()
    .split("\n")
    .map(line => line.to_owned())
    .to_array()
  let first_row = lines[2].split("\t").map(cell => cell.to_owned()).to_array()
  let original = first_row[1]
  first_row[1] = original[0:original.length() - 1].to_owned() +
    (if original.has_suffix("0") { "1" } else { "0" })
  lines[2] = first_row.join("\t")
  match bundle.compare_actual_tsv(lines.join("\n")) {
    Mismatch(_) => ()
    _ => fail("fault/reset public output mutation was not detected")
  }
}
