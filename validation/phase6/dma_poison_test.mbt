///|
test "fetched loader and storer poison owners preserve progress and drain accepted compute" {
  let bundle = @phase6.generate_dma_poison_bundle()
  let repeated = @phase6.generate_dma_poison_bundle()
  assert_eq(bundle.id(), "fetched-concurrent-8x8-k64-dma-poison-owners")
  assert_true(bundle.post_reset_cycles() > 0)
  assert_true(bundle.post_reset_cycles() <= 65536)
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
          "OWNERS 2\n",
          "FAULT-EPOCHS 2\n",
          "HOST-BYTES match\n",
          "CLAIM generated-reference-only\n",
        ] {
        assert_true(artifact.content.contains(required))
      }
      for owner in ["LOADER", "STORER"] {
        for
          required in [
            "OWNER-FAULT 10", "SIBLING-FAULT 15", "READER-RING-FAULT 0", "DISCOVERY-ACTIVE-ADVANCE 1",
            "DRAIN-ACTIVE-CYCLES 78", "DRAIN-CAPTURE-CYCLES 64", "HELD-CAPTURE-EDGES 64",
            "HELD-TERMINAL-STABLE true", "QUIET-EDGES 8", "NO-AFTER-POISON-ISSUE true",
            "MALFORMED-ACKS 1", "ORACLE match", "HOST-BYTES 16384 match", "RESETS 2",
            "RECOVERY-COMPLETIONS 2", "RECOVERY-TAG 0", "RECOVERY-STALE-SLOT-FAULT 4",
            "RECOVERY-FENCE-FAULT 0",
          ] {
          assert_true(artifact.content.contains("\{owner}-\{required}\n"))
        }
        // These are measured finite-run counts, not predetermined totals.
        for
          field in [
            "LOADER-ACK-BYTES", "STORER-ACK-BYTES", "DISCOVERY-ACTIVE", "HELD-FENCE-EDGES",
            "HELD-ACTIVE-EDGES",
          ] {
          assert_true(artifact.content.contains("\{owner}-\{field} "))
          assert_false(artifact.content.contains("\{owner}-\{field} 0\n"))
        }
        for
          field in [
            "REQUEST-TAG", "FAULT-ADDRESS", "DISCOVERY-CYCLE", "ADMITTED-PREFIX",
            "COMPLETIONS", "ACCEPTED-WRITES",
          ] {
          assert_true(artifact.content.contains("\{owner}-\{field} "))
        }
      }
    }
  }
  assert_true(found_workload)
  match bundle.compare_actual_tsv(bundle.expected_tsv()) {
    Equal => ()
    _ => fail("DMA-poison reference trace failed its exact typed comparator")
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
    _ => fail("DMA-poison public output mutation was not detected")
  }
}
