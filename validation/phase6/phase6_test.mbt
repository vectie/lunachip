///|
test "fetched device fixture is deterministic and compares every public output" {
  let bundle = @phase6.generate_bundle()
  let repeated = @phase6.generate_bundle()
  assert_eq(bundle.id(), "fetched-concurrent-1x1-k2")
  assert_true(bundle.post_reset_cycles() > 165)
  assert_true(bundle.post_reset_cycles() <= 4096)
  assert_eq(bundle.expected_tsv(), repeated.expected_tsv())
  assert_eq(bundle.artifacts().length(), repeated.artifacts().length())
  for index, artifact in bundle.artifacts() {
    assert_eq(artifact.path, repeated.artifacts()[index].path)
    assert_eq(artifact.content, repeated.artifacts()[index].content)
  }
  match bundle.compare_actual_tsv(bundle.expected_tsv()) {
    Equal => ()
    _ => fail("reference result failed its exact comparator")
  }
  let outputs = bundle.ports().filter(port => port.is_output())
  assert_eq(outputs.length(), 30)
  let lines = bundle.expected_tsv().split("\n").map(line => line.to_owned()).to_array()
  let first_row = lines[2].split("\t").map(cell => cell.to_owned()).to_array()
  let original = first_row[1]
  first_row[1] = original[0:original.length() - 1].to_owned() +
    (if original.has_suffix("0") { "1" } else { "0" })
  lines[2] = first_row.join("\t")
  match bundle.compare_actual_tsv(lines.join("\n")) {
    Mismatch(_) => ()
    _ => fail("mutated public output was not detected")
  }
}
