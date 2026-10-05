///|
test "fetched capacity saturation preserves held slots across recorded origin wrap" {
  let bundle = @phase6.generate_capacity_wrap_bundle()
  let repeated = @phase6.generate_capacity_wrap_bundle()
  assert_eq(bundle.id(), "fetched-concurrent-1x1-k1-capacity-origin-wrap")
  assert_true(bundle.post_reset_cycles() > 256)
  assert_true(bundle.post_reset_cycles() <= 8192)
  assert_eq(bundle.post_reset_cycles(), repeated.post_reset_cycles())
  assert_eq(bundle.expected_tsv(), repeated.expected_tsv())
  assert_eq(bundle.ports().filter(port => port.is_output()).length(), 30)
  assert_eq(bundle.ports().length(), repeated.ports().length())
  let mut origin_name = ""
  let mut completion_name = ""
  for index, port in bundle.ports() {
    assert_eq(port, repeated.ports()[index])
    if port.source_name() == "config_origin" {
      assert_true(port.is_input())
      assert_eq(port.width(), 32)
      origin_name = port.emitted_name()
    }
    if port.source_name() == "completion_id" {
      assert_true(port.is_output())
      completion_name = port.emitted_name()
    }
  }
  assert_true(origin_name != "")
  assert_true(completion_name != "")
  assert_eq(bundle.artifacts().length(), 11)
  assert_eq(repeated.artifacts().length(), 11)
  let mut found_workload = false
  let mut found_stimulus = false
  for index, artifact in bundle.artifacts() {
    assert_eq(artifact.path, repeated.artifacts()[index].path)
    assert_eq(artifact.content, repeated.artifacts()[index].content)
    if artifact.path == "workload.audit" {
      found_workload = true
      for
        required in [
          "LUNACHIP-PHASE6-FIXTURE 1\n",
          "PROFILE flux-tile-0/fetched-concurrent\n",
          "FIXTURE fetched-concurrent-1x1-k1-capacity-origin-wrap\n",
          "CYCLES \{bundle.post_reset_cycles()}\n",
          "CONFIGURATION-ACCEPTS 1\n",
          "CONFIG-ORIGIN 4294967294\n",
          "PUBLICATION-ACCEPTS 4\n",
          "PUBLICATION-PRODUCERS 0 2 4 6\n",
          "COMPLETIONS 8\n",
          "REQUESTS 256\n",
          "ACKS 256\n",
          "DESCRIPTOR-READS 256\n",
          "OPERAND-READS 0\n",
          "WRITE-BYTES 0\n",
          "BLOCKED-ADMITTED 5\n",
          "BLOCKED-FETCHED 6\n",
          "BLOCKED-CONSUMER 3\n",
          "BLOCKED-PRODUCER 4\n",
          "BLOCKED-QUEUE 2\n",
          "BLOCKED-REQUESTS 192\n",
          "BLOCKED-ACKS 192\n",
          "QUIET-EDGES 32\n",
          "HELD-TERMINAL-STABLE true\n",
          "HELD-SLOT-BYTES match\n",
          "FINAL-CONSUMER 6\n",
          "FINAL-PRODUCER 6\n",
          "STARTUP-RESETS 1\n",
          "COMPUTE-COUNTERS 0 0 0 0 0\n",
          "HOST-BYTES 4096 match\n",
          "CLAIM generated-reference-only\n",
        ] {
        assert_true(artifact.content.contains(required))
      }
    }
    if artifact.path == "stimulus.tsv" {
      found_stimulus = true
      let lines = artifact.content.split("\n").to_array()
      assert_true(lines.length() > 1)
      let header = lines[0].split("\t").to_array()
      let mut origin_column = -1
      for column, name in header {
        if name == origin_name {
          origin_column = column
        }
      }
      assert_true(origin_column >= 0)
      let mut recorded_rows = 0
      for line in lines[1:] {
        if line != "" {
          let cells = line.split("\t").to_array()
          assert_eq(cells.length(), header.length())
          assert_eq(cells[origin_column], "fffffffe")
          recorded_rows += 1
        }
      }
      assert_true(recorded_rows > bundle.post_reset_cycles())
    }
  }
  assert_true(found_workload)
  assert_true(found_stimulus)
  match bundle.compare_actual_tsv(bundle.expected_tsv()) {
    Equal => ()
    _ => fail("capacity-wrap reference trace failed its exact typed comparator")
  }
  let lines = bundle
    .expected_tsv()
    .split("\n")
    .map(line => line.to_owned())
    .to_array()
  let header = lines[1].split("\t").to_array()
  let mut completion_column = -1
  for column, name in header {
    if name == completion_name {
      completion_column = column
    }
  }
  assert_true(completion_column > 0)
  let first_row = lines[2].split("\t").map(cell => cell.to_owned()).to_array()
  let original = first_row[completion_column]
  first_row[completion_column] = original[0:original.length() - 1].to_owned() +
    (if original.has_suffix("0") { "1" } else { "0" })
  lines[2] = first_row.join("\t")
  match bundle.compare_actual_tsv(lines.join("\n")) {
    Mismatch(_) => ()
    _ =>
      fail("capacity-wrap public completion output mutation was not detected")
  }
}
