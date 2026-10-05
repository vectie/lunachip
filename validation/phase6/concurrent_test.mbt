///|
test "concurrent replay requires real overlap and compares every public output" {
  let bundle = @phase6.generate_concurrent_bundle()
  let repeated = @phase6.generate_concurrent_bundle()
  assert_eq(bundle.id(), "fetched-concurrent-1x1-k512-overlap")
  assert_true(bundle.post_reset_cycles() > 1860)
  assert_true(bundle.post_reset_cycles() <= 32768)
  assert_eq(bundle.expected_tsv(), repeated.expected_tsv())
  assert_eq(bundle.artifacts().length(), 11)
  assert_eq(bundle.artifacts().length(), repeated.artifacts().length())
  let mut found_workload = false
  for index, artifact in bundle.artifacts() {
    assert_eq(artifact.path, repeated.artifacts()[index].path)
    assert_eq(artifact.content, repeated.artifacts()[index].content)
    if artifact.path == "workload.audit" {
      found_workload = true
      assert_true(
        artifact.content.contains(
          "COMPLETIONS 10\nREQUESTS 1860\nREAD-BYTES 1858\nWRITE-BYTES 8\n",
        ),
      )
      assert_true(artifact.content.contains("OLD-RESULT 6\n"))
      assert_true(
        artifact.content.contains("ORACLE match\nRING-SLOT-REUSE true\n"),
      )
      assert_true(artifact.content.contains("COMPLETION-HOLD-CYCLES 64\n"))
      assert_true(artifact.content.contains("RUN-ADVANCING-EDGES 512\n"))
      assert_true(artifact.content.contains("CLAIM generated-reference-only\n"))
    }
  }
  assert_true(found_workload)
  assert_eq(bundle.ports().filter(port => port.is_output()).length(), 30)
  match bundle.compare_actual_tsv(bundle.expected_tsv()) {
    Equal => ()
    _ => fail("concurrent reference result failed its typed comparator")
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
    _ => fail("concurrent output mutation was not detected")
  }
}
