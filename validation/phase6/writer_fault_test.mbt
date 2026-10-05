///|
test "fetched writer rejection preserves syntax intent, poisons semantic intent and recovers" {
  let bundle = @phase6.generate_writer_fault_bundle()
  let repeated = @phase6.generate_writer_fault_bundle()
  assert_eq(bundle.id(), "fetched-concurrent-1x1-k2-writer-fault-recovery")
  assert_true(bundle.post_reset_cycles() > 552)
  assert_true(bundle.post_reset_cycles() <= 16384)
  assert_eq(bundle.post_reset_cycles(), repeated.post_reset_cycles())
  assert_eq(bundle.expected_tsv(), repeated.expected_tsv())
  assert_eq(bundle.ports().filter(port => port.is_output()).length(), 30)
  assert_eq(bundle.artifacts().length(), 11)
  assert_eq(repeated.artifacts().length(), 11)
  let mut found_workload = false
  for index, artifact in bundle.artifacts() {
    assert_eq(artifact.path, repeated.artifacts()[index].path)
    assert_eq(artifact.content, repeated.artifacts()[index].content)
    if artifact.path == "workload.audit" {
      found_workload = true
      for
        required in [
          "CYCLES \{bundle.post_reset_cycles()}\n",
          "COMPLETIONS 17\nREQUESTS 552\nACKNOWLEDGEMENTS 552\n",
          "READ-BYTES 549\nWRITE-REQUESTS 3\nWRITE-BYTES 12\n",
          "DESCRIPTOR-READS 544\nOPERAND-READS 5\n",
          "ORACLE match\nHOST-BYTES match\n",
          "RING-REFILLS 5\n",
          "PRODUCER 17\nCONSUMER 17\nCOMPLETION-HOLD-CYCLES 32\n",
          "REJECTED-GROUP-DESCRIPTOR-READS 128\n",
          "REJECTED-GROUP-OPERAND-READS 0\n",
          "REJECTED-GROUP-C0-WRITES 0\n",
          "REJECTED-GROUP-C1-WRITES 1\n",
          "REJECTED-COMPUTE-COUNTERS unchanged\n",
          "RECOVERY-ACTIVE-EDGES 1\nRECOVERY-CAPTURE-EDGES 1\n",
          "RESULT 6\nUNRELATED-RESULT 35\nRECOVERY-RESULT 27\n",
          "CLAIM generated-reference-only\n",
        ] {
        assert_true(artifact.content.contains(required))
      }
    }
  }
  assert_true(found_workload)
  match bundle.compare_actual_tsv(bundle.expected_tsv()) {
    Equal => ()
    _ => fail("writer-fault reference trace failed its exact typed comparator")
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
    _ => fail("writer-fault public output mutation was not detected")
  }
}
