///|
test "signed 8x8 two-slot replay is deterministic and compares all public outputs" {
  let bundle = @phase6.generate_array8_bundle()
  let repeated = @phase6.generate_array8_bundle()
  assert_eq(bundle.id(), "fetched-concurrent-8x8-k16-two-slots")
  assert_true(bundle.post_reset_cycles() > 960)
  assert_true(bundle.post_reset_cycles() <= 16384)
  assert_eq(bundle.expected_tsv(), repeated.expected_tsv())
  assert_eq(bundle.ports().filter(port => port.is_output()).length(), 30)
  assert_eq(bundle.artifacts().length(), 11)
  let mut found_workload = false
  for index, artifact in bundle.artifacts() {
    assert_eq(artifact.path, repeated.artifacts()[index].path)
    assert_eq(artifact.content, repeated.artifacts()[index].content)
    if artifact.path == "workload.audit" {
      found_workload = true
      assert_true(
        artifact.content.contains(
          "COMPLETIONS 10\nREQUESTS 960\nACKNOWLEDGEMENTS 960\n",
        ),
      )
      assert_true(
        artifact.content.contains(
          "READ-BYTES 832\nWRITE-REQUESTS 128\nWRITE-BYTES 512\n",
        ),
      )
      assert_true(
        artifact.content.contains(
          "ORACLE match\nHOST-BYTES match\nRING-REFILLS 2\n",
        ),
      )
      assert_true(artifact.content.contains("COMPLETION-HOLD-CYCLES 64\n"))
      assert_true(
        artifact.content.contains(
          "COMPUTE-COMPLETIONS 2\nPER-MATMUL-ACCEPTED-STEPS 30\n",
        ),
      )
      assert_true(artifact.content.contains("PER-MATMUL-CAPTURE-CYCLES 64\n"))
      for delay in 1..<=5 {
        assert_true(
          artifact.content.contains("RESPONSE-DELAY-\{delay}-REQUESTS 192\n"),
        )
      }
      for slot in 0..<2 {
        for row in 0..<8 {
          assert_true(
            artifact.content.contains("RESULT-SLOT-\{slot}-ROW-\{row} "),
          )
        }
      }
      assert_true(artifact.content.contains("CLAIM generated-reference-only\n"))
    }
  }
  assert_true(found_workload)
  match bundle.compare_actual_tsv(bundle.expected_tsv()) {
    Equal => ()
    _ => fail("8x8 reference trace failed its exact comparator")
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
    _ => fail("8x8 public output mutation was not detected")
  }
}
