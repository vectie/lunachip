///|
test "fixed-seed 8x8 replay is reproducible and detects public output mutation" {
  let bundle = @phase6.generate_seeded_bundle()
  let repeated = @phase6.generate_seeded_bundle()
  assert_eq(bundle.id(), "fetched-concurrent-8x8-k16-seed-5eedc0de20261005")
  assert_true(bundle.post_reset_cycles() > 960)
  assert_true(bundle.post_reset_cycles() <= 32768)
  assert_eq(bundle.expected_tsv(), repeated.expected_tsv())
  assert_eq(bundle.ports().filter(port => port.is_output()).length(), 30)
  assert_eq(bundle.artifacts().length(), 11)
  let mut found_workload = false
  for index, artifact in bundle.artifacts() {
    assert_eq(artifact.path, repeated.artifacts()[index].path)
    assert_eq(artifact.content, repeated.artifacts()[index].content)
    if artifact.path == "workload.audit" {
      found_workload = true
      for
        required in [
          "CYCLES \{bundle.post_reset_cycles()}\n",
          "COMPLETIONS 10\nREQUESTS 960\nACKNOWLEDGEMENTS 960\n",
          "READ-BYTES 832\nWRITE-REQUESTS 128\nWRITE-BYTES 512\n",
          "ORACLE match\nHOST-BYTES match\nRING-REFILLS 2\n",
          "PRODUCER 10\nCONSUMER 10\nCOMPLETION-HOLD-CYCLES 64\n",
          "COMPUTE-COMPLETIONS 2\nPER-MATMUL-ACCEPTED-STEPS 30\n",
          "PER-MATMUL-ACTIVE-CYCLES 30\nPER-MATMUL-ELAPSED-CYCLES 31\n",
          "PER-MATMUL-STALL-CYCLES 0\nPER-MATMUL-CAPTURE-CYCLES 64\n",
          "PRNG SplitMix64\nMASTER-SEED 5eedc0de20261005\n",
          "MATRIX-SEED 5eed8d9f7474595d\n",
          "READINESS-SEED 5eedc08c6567545c\n",
          "LATENCY-SEED 5ea1818a6568535c\n",
          "MATRIX-PRNG-DRAWS 516\nRETAINED-RANDOM-INT8 492\n",
          "EXPLICIT-INT8-EDGE-VALUES 20\nREADINESS-PRNG-DRAWS 32769\n",
          "LATENCY-PRNG-DRAWS 960\n",
          "CLAIM generated-reference-only\n",
        ] {
        assert_true(artifact.content.contains(required))
      }
      // SplitMix64 fixed-seed finite vector, not a statistical coverage claim.
      for index, count in [133, 133, 149, 150, 140, 121, 134] {
        assert_true(
          artifact.content.contains(
            "RESPONSE-DELAY-\{index + 1}-REQUESTS \{count}\n",
          ),
        )
      }
      for slot in 0..<2 {
        for row in 0..<8 {
          assert_true(
            artifact.content.contains("RESULT-SLOT-\{slot}-ROW-\{row} "),
          )
        }
      }
    }
  }
  assert_true(found_workload)
  match bundle.compare_actual_tsv(bundle.expected_tsv()) {
    Equal => ()
    _ => fail("seeded reference trace failed the exact typed comparator")
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
    _ => fail("seeded public output mutation was not detected")
  }
}
