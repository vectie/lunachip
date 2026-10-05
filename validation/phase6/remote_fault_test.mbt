///|
test "matching remote failures preserve partial bytes, retry and recover generations without reset" {
  let bundle = @phase6.generate_remote_fault_bundle()
  let repeated = @phase6.generate_remote_fault_bundle()
  assert_eq(bundle.id(), "fetched-concurrent-1x2-k2-remote-fault-recovery")
  assert_true(bundle.post_reset_cycles() > 537)
  assert_true(bundle.post_reset_cycles() <= 16384)
  assert_eq(bundle.post_reset_cycles(), repeated.post_reset_cycles())
  assert_eq(bundle.expected_tsv(), repeated.expected_tsv())
  assert_eq(bundle.ports().filter(port => port.is_output()).length(), 30)
  assert_eq(bundle.artifacts().length(), 11)
  assert_eq(repeated.artifacts().length(), 11)
  let mut found = false
  for index, artifact in bundle.artifacts() {
    assert_eq(artifact.path, repeated.artifacts()[index].path)
    assert_eq(artifact.content, repeated.artifacts()[index].content)
    if artifact.path == "workload.audit" {
      found = true
      for
        required in [
          "CYCLES \{bundle.post_reset_cycles()}\nCOMPLETIONS 16\n",
          "REQUESTS 537\nACKNOWLEDGEMENTS 537\n",
          "DESCRIPTOR-READS 512\nOPERAND-READS 15\nREAD-BYTES 527\n",
          "WRITE-REQUESTS 10\nWRITE-REQUEST-BYTES 40\nWRITE-EFFECT-BYTES 38\nWRITE-ACK-BYTES 36\n",
          "REMOTE-FAILURE-ACKS 2\n",
          "STORE-FAULT-ADDRESS 1540\nSTORE-COMPLETED-BYTES 4\n",
          "LOAD-FAULT-ADDRESS 771\nLOAD-COMPLETED-BYTES 2\n",
          "PARTIAL-WRITE-HOST-BYTES 4096 match\nRETRY-SAME-C0 true\n",
          "FAILED-MATMUL-FAULT 4\nFAILED-STORE-FAULT 5\n",
          "ORACLE match\nHOST-BYTES 4096 match\n",
          "RESULT -23,-53\nUNRELATED-RESULT 35,93\nRECOVERY-RESULT -16,33\n",
          "REJECTED-GROUP-DESCRIPTOR-READS 96\nREJECTED-GROUP-OPERAND-READS 0\nREJECTED-GROUP-C0-WRITES 0\nREJECTED-GROUP-C1-WRITES 2\n",
          "REJECTED-COMPUTE-COUNTERS unchanged\nRECOVERY-ACTIVE-EDGES 3\nRECOVERY-CAPTURE-EDGES 2\n",
          "RING-REFILLS 5\nPRODUCER 16\nCONSUMER 16\n",
          "INITIAL-RESET 1\nJOINT-RESETS 0\nHOST-REINITIALIZATIONS 0\nTRANSPORT-POISON false\n",
          "CLAIM generated-reference-only\n",
        ] {
        assert_true(artifact.content.contains(required))
      }
    }
  }
  assert_true(found)
  match bundle.compare_actual_tsv(bundle.expected_tsv()) {
    Equal => ()
    _ => fail("remote-fault reference trace failed its typed comparator")
  }
  let lines = bundle
    .expected_tsv()
    .split("\n")
    .map(line => line.to_owned())
    .to_array()
  let cells = lines[2].split("\t").map(cell => cell.to_owned()).to_array()
  let original = cells[1]
  cells[1] = original[0:original.length() - 1].to_owned() +
    (if original.has_suffix("0") { "1" } else { "0" })
  lines[2] = cells.join("\t")
  match bundle.compare_actual_tsv(lines.join("\n")) {
    Mismatch(_) => ()
    _ => fail("remote-fault public observation mutation was not detected")
  }
}
