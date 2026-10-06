///|
test "capacity17 dynamic shapes reuse mixed source slots and preserve both stored results" {
  let bundle = @phase6.generate_shape_reload_bundle()
  let repeated = @phase6.generate_shape_reload_bundle()
  assert_eq(bundle.id(), "fetched-concurrent-8x8-k17-dynamic-shape-reload")
  assert_true(bundle.post_reset_cycles() > 551)
  assert_true(bundle.post_reset_cycles() <= 16384)
  assert_eq(bundle.expected_tsv(), repeated.expected_tsv())
  assert_eq(bundle.ports().filter(port => port.is_output()).length(), 30)
  assert_eq(bundle.artifacts().length(), 11)
  let mut found = false
  for index, artifact in bundle.artifacts() {
    assert_eq(artifact.path, repeated.artifacts()[index].path)
    assert_eq(artifact.content, repeated.artifacts()[index].content)
    if artifact.path == "workload.audit" {
      found = true
      for
        fragment in [
          "ARRAY 8 8\nREDUCTION-CAPACITY 17\n", "COMPLETIONS 10\nREQUESTS 551\nACKNOWLEDGEMENTS 551\n",
          "READ-BYTES 472\nWRITE-REQUESTS 79\nWRITE-BYTES 316\n", "ORACLE match\nHOST-BYTES match\nHOST-BYTE-COUNT 4096\n",
          "COMPLETION-HOLD-CYCLES 16\n", "SOURCE-SLOTS A1 B0\nEXACT-SHAPE-RELOADS 2\n",
          "MATMUL-0-SHAPE 3 5 17\nMATMUL-0-ACCEPTED-STEPS 23\n", "MATMUL-0-CAPTURE-CYCLES 15\n",
          "MATMUL-1-SHAPE 8 8 1\nMATMUL-1-ACCEPTED-STEPS 15\n", "MATMUL-1-CAPTURE-CYCLES 64\n",
        ] {
        assert_true(artifact.content.contains(fragment))
      }
      for slot in 0..<2 {
        for row in 0..<(if slot == 0 { 3 } else { 8 }) {
          assert_true(
            artifact.content.contains("RESULT-SLOT-\{slot}-ROW-\{row} "),
          )
        }
      }
      for delay in 1..<=5 {
        assert_true(
          artifact.content.contains(
            "RESPONSE-DELAY-\{delay}-REQUESTS \{if delay == 1 { 111 } else { 110 }}\n",
          ),
        )
      }
      assert_true(artifact.content.contains("CLAIM generated-reference-only\n"))
    }
  }
  assert_true(found)
  assert_true(bundle.compare_actual_tsv(bundle.expected_tsv()) is Equal)
  let lines = bundle
    .expected_tsv()
    .split("\n")
    .map(line => line.to_owned())
    .to_array()
  let first = lines[2].split("\t").map(cell => cell.to_owned()).to_array()
  let original = first[1]
  first[1] = original[0:original.length() - 1].to_owned() +
    (if original.has_suffix("0") { "1" } else { "0" })
  lines[2] = first.join("\t")
  assert_true(bundle.compare_actual_tsv(lines.join("\n")) is Mismatch(_))
}
