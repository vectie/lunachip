///|
test "phase6 fixture audit verifies the actual differential equality" {
  let bundle = @phase6.generate_bundle()
  assert_eq(
    audit_source(bundle, bundle.expected_tsv()),
    "fixture=\{bundle.id()} cycles=\{bundle.post_reset_cycles()} result=equal\n" +
    "Single-fixture differential comparison only; not the complete Phase 6 gate.",
  )
}

///|
test "phase6 fixture audit reports a real mutated observation as a mismatch" {
  let bundle = @phase6.generate_bundle()
  let lines = bundle
    .expected_tsv()
    .split("\n")
    .map(line => line.to_owned())
    .to_array()
  let cells = lines[2].split("\t").map(cell => cell.to_owned()).to_array()
  let original = cells[1]
  // Change one output's low nibble without changing field width or identity.
  cells[1] = original[0:original.length() - 1].to_owned() +
    (if original.has_suffix("0") { "1" } else { "0" })
  lines[2] = cells.join("\t")
  try audit_source(bundle, lines.join("\n")) catch {
    Phase6CliError::AuditMismatch(fixture~, identity=Value(..)) =>
      assert_eq(fixture, bundle.id())
    other => fail("unexpected audit mismatch: \{Repr(other)}")
  } noraise {
    _ => fail("mutated actual data must not pass audit")
  }
}

///|
test "phase6 fixture audit propagates malformed result errors" {
  try audit_source(@phase6.generate_bundle(), "malformed") catch {
    @verilator.HarnessError::InvalidResultTsv(
      reason="missing final newline",
      row=0
    ) => ()
    other => fail("unexpected malformed result error: \{Repr(other)}")
  } noraise {
    _ => fail("malformed actual data must not pass audit")
  }
}

///|
test "phase6 export refuses an existing output without touching it" {
  try checked_new_directory(".") catch {
    Phase6CliError::ExistingOutput(path=".") => ()
    other => fail("unexpected overwrite error: \{Repr(other)}")
  } noraise {
    _ => fail("existing output must not be reused")
  }
}

///|
test "phase6 fixture CLI help and argument checks remain explicit" {
  let usage = "Usage: phase6-fixtures export DIRECTORY | audit ACTUAL_TSV | export-concurrent DIRECTORY | audit-concurrent ACTUAL_TSV | export-fault-reset DIRECTORY | audit-fault-reset ACTUAL_TSV | export-array8 DIRECTORY | audit-array8 ACTUAL_TSV | export-seeded DIRECTORY | audit-seeded ACTUAL_TSV | export-writer-fault DIRECTORY | audit-writer-fault ACTUAL_TSV | export-dma-poison DIRECTORY | audit-dma-poison ACTUAL_TSV | export-remote-fault DIRECTORY | audit-remote-fault ACTUAL_TSV | export-capacity-wrap DIRECTORY | audit-capacity-wrap ACTUAL_TSV | export-descriptor-rejection DIRECTORY | audit-descriptor-rejection ACTUAL_TSV | export-ring-control DIRECTORY | audit-ring-control ACTUAL_TSV | export-shape-reload DIRECTORY | audit-shape-reload ACTUAL_TSV | help"
  for args in [[], ["help"], ["--help"], ["-h"]] {
    assert_eq(run_command(args), usage)
  }
  for
    args in [
      ["export"],
      ["audit"],
      ["export-concurrent"],
      ["audit-concurrent"],
      ["export-fault-reset"],
      ["audit-fault-reset"],
      ["export-array8"],
      ["audit-array8"],
      ["export-seeded"],
      ["audit-seeded"],
      ["export-writer-fault"],
      ["audit-writer-fault"],
      ["export-dma-poison"],
      ["audit-dma-poison"],
      ["export-remote-fault"],
      ["audit-remote-fault"],
      ["export-capacity-wrap"],
      ["audit-capacity-wrap"],
      ["export-descriptor-rejection"],
      ["audit-descriptor-rejection"],
      ["export-ring-control"],
      ["audit-ring-control"],
      ["export-shape-reload"],
      ["audit-shape-reload"],
      ["unknown"],
      ["export", ".", "extra"],
      ["export-concurrent", ".", "extra"],
      ["audit-concurrent", ".", "extra"],
      ["export-fault-reset", ".", "extra"],
      ["audit-fault-reset", ".", "extra"],
      ["export-array8", ".", "extra"],
      ["audit-array8", ".", "extra"],
      ["export-seeded", ".", "extra"],
      ["audit-seeded", ".", "extra"],
      ["export-writer-fault", ".", "extra"],
      ["audit-writer-fault", ".", "extra"],
      ["export-dma-poison", ".", "extra"],
      ["audit-dma-poison", ".", "extra"],
      ["export-remote-fault", ".", "extra"],
      ["audit-remote-fault", ".", "extra"],
      ["export-capacity-wrap", ".", "extra"],
      ["audit-capacity-wrap", ".", "extra"],
      ["export-descriptor-rejection", ".", "extra"],
      ["audit-descriptor-rejection", ".", "extra"],
      ["export-ring-control", ".", "extra"],
      ["audit-ring-control", ".", "extra"],
      ["export-shape-reload", ".", "extra"],
      ["audit-shape-reload", ".", "extra"],
    ] {
    try run_command(args) catch {
      Phase6CliError::Usage(actual) => assert_eq(actual, usage)
      other => fail("unexpected usage error: \{Repr(other)}")
    } noraise {
      _ => fail("invalid command must not run")
    }
  }
}

///|
test "concurrent fixture audit verifies equality and rejects another fixture identity" {
  let bundle = FixtureChoice::Concurrent.bundle()
  assert_eq(bundle.id(), "fetched-concurrent-1x1-k512-overlap")
  assert_true(bundle.compare_actual_tsv(bundle.expected_tsv()) is Equal)
  assert_eq(
    audit_source(bundle, bundle.expected_tsv()),
    "fixture=\{bundle.id()} cycles=\{bundle.post_reset_cycles()} result=equal\n" +
    "Single-fixture differential comparison only; not the complete Phase 6 gate.",
  )
  let lines = bundle
    .expected_tsv()
    .split("\n")
    .map(line => line.to_owned())
    .to_array()
  let pipeline = FixtureChoice::Pipeline.bundle()
  // Preserve every concurrent observation and row count, changing only the
  // identity header to the original fixture's independently valid identity.
  lines[0] = pipeline.expected_tsv().split("\n").next().unwrap().to_owned()
  try audit_source(bundle, lines.join("\n")) catch {
    Phase6CliError::AuditMismatch(fixture~, identity=Identity(..)) =>
      assert_eq(fixture, bundle.id())
    other => fail("unexpected cross-fixture error: \{Repr(other)}")
  } noraise {
    _ => fail("a result bound to another fixture must not pass audit")
  }
}

///|
test "fault-reset fixture audit verifies equality and rejects another fixture identity" {
  let bundle = FixtureChoice::FaultReset.bundle()
  assert_eq(bundle.id(), "fetched-concurrent-1x1-k64-reader-poison-reset")
  assert_true(bundle.compare_actual_tsv(bundle.expected_tsv()) is Equal)
  assert_eq(
    audit_source(bundle, bundle.expected_tsv()),
    "fixture=\{bundle.id()} cycles=\{bundle.post_reset_cycles()} result=equal\n" +
    "Single-fixture differential comparison only; not the complete Phase 6 gate.",
  )
  let lines = bundle
    .expected_tsv()
    .split("\n")
    .map(line => line.to_owned())
    .to_array()
  let pipeline = FixtureChoice::Pipeline.bundle()
  // Keep all fault/reset samples and their row count, changing only the
  // identity header to a different fixture's valid header.
  lines[0] = pipeline.expected_tsv().split("\n").next().unwrap().to_owned()
  try audit_source(bundle, lines.join("\n")) catch {
    Phase6CliError::AuditMismatch(fixture~, identity=Identity(..)) =>
      assert_eq(fixture, bundle.id())
    other => fail("unexpected fault-reset identity error: \{Repr(other)}")
  } noraise {
    _ => fail("wrong-fixture result must not pass fault-reset audit")
  }
}

///|
test "array8 fixture audit verifies equality and rejects another fixture identity" {
  let bundle = FixtureChoice::Array8.bundle()
  assert_eq(bundle.id(), "fetched-concurrent-8x8-k16-two-slots")
  assert_true(bundle.compare_actual_tsv(bundle.expected_tsv()) is Equal)
  assert_eq(
    audit_source(bundle, bundle.expected_tsv()),
    "fixture=\{bundle.id()} cycles=\{bundle.post_reset_cycles()} result=equal\n" +
    "Single-fixture differential comparison only; not the complete Phase 6 gate.",
  )
  let lines = bundle
    .expected_tsv()
    .split("\n")
    .map(line => line.to_owned())
    .to_array()
  let pipeline = FixtureChoice::Pipeline.bundle()
  // Keep every array8 observation and its row count, changing only the
  // identity header to the original fixture's valid header.
  lines[0] = pipeline.expected_tsv().split("\n").next().unwrap().to_owned()
  try audit_source(bundle, lines.join("\n")) catch {
    Phase6CliError::AuditMismatch(fixture~, identity=Identity(..)) =>
      assert_eq(fixture, bundle.id())
    other => fail("unexpected array8 identity error: \{Repr(other)}")
  } noraise {
    _ => fail("wrong-fixture result must not pass array8 audit")
  }
}

///|
test "seeded fixture audit verifies equality and rejects another fixture identity" {
  let bundle = FixtureChoice::Seeded.bundle()
  assert_eq(bundle.id(), "fetched-concurrent-8x8-k16-seed-5eedc0de20261005")
  assert_true(bundle.compare_actual_tsv(bundle.expected_tsv()) is Equal)
  assert_eq(
    audit_source(bundle, bundle.expected_tsv()),
    "fixture=\{bundle.id()} cycles=\{bundle.post_reset_cycles()} result=equal\n" +
    "Single-fixture differential comparison only; not the complete Phase 6 gate.",
  )
  let lines = bundle
    .expected_tsv()
    .split("\n")
    .map(line => line.to_owned())
    .to_array()
  let pipeline = FixtureChoice::Pipeline.bundle()
  // Keep every seeded observation and its row count, changing only the
  // identity header to the original fixture's valid header.
  lines[0] = pipeline.expected_tsv().split("\n").next().unwrap().to_owned()
  try audit_source(bundle, lines.join("\n")) catch {
    Phase6CliError::AuditMismatch(fixture~, identity=Identity(..)) =>
      assert_eq(fixture, bundle.id())
    other => fail("unexpected seeded identity error: \{Repr(other)}")
  } noraise {
    _ => fail("wrong-fixture result must not pass seeded audit")
  }
}

///|
test "writer fault fixture audit binds equality to the selected device identity" {
  let bundle = FixtureChoice::WriterFault.bundle()
  assert_eq(bundle.id(), "fetched-concurrent-1x1-k2-writer-fault-recovery")
  assert_eq(
    audit_source(bundle, bundle.expected_tsv()),
    "fixture=\{bundle.id()} cycles=\{bundle.post_reset_cycles()} result=equal\n" +
    "Single-fixture differential comparison only; not the complete Phase 6 gate.",
  )
  let lines = bundle
    .expected_tsv()
    .split("\n")
    .map(line => line.to_owned())
    .to_array()
  lines[0] = FixtureChoice::Pipeline
    .bundle()
    .expected_tsv()
    .split("\n")
    .next()
    .unwrap()
    .to_owned()
  try audit_source(bundle, lines.join("\n")) catch {
    Phase6CliError::AuditMismatch(fixture~, identity=Identity(..)) =>
      assert_eq(fixture, bundle.id())
    other => fail("unexpected writer-fault identity error: \{Repr(other)}")
  } noraise {
    _ => fail("wrong-fixture result must not pass writer-fault audit")
  }
}

///|
test "DMA poison fixture audit binds both owners to the selected identity" {
  let bundle = FixtureChoice::DmaPoison.bundle()
  assert_eq(bundle.id(), "fetched-concurrent-8x8-k64-dma-poison-owners")
  assert_eq(
    audit_source(bundle, bundle.expected_tsv()),
    "fixture=\{bundle.id()} cycles=\{bundle.post_reset_cycles()} result=equal\n" +
    "Single-fixture differential comparison only; not the complete Phase 6 gate.",
  )
  let lines = bundle
    .expected_tsv()
    .split("\n")
    .map(line => line.to_owned())
    .to_array()
  lines[0] = FixtureChoice::Pipeline
    .bundle()
    .expected_tsv()
    .split("\n")
    .next()
    .unwrap()
    .to_owned()
  try audit_source(bundle, lines.join("\n")) catch {
    Phase6CliError::AuditMismatch(fixture~, identity=Identity(..)) =>
      assert_eq(fixture, bundle.id())
    other => fail("unexpected DMA-poison identity error: \{Repr(other)}")
  } noraise {
    _ => fail("wrong-fixture result must not pass DMA-poison audit")
  }
}

///|
test "remote fault fixture audit rejects another fixture identity" {
  let bundle = FixtureChoice::RemoteFault.bundle()
  assert_eq(bundle.id(), "fetched-concurrent-1x2-k2-remote-fault-recovery")
  assert_eq(
    audit_source(bundle, bundle.expected_tsv()),
    "fixture=\{bundle.id()} cycles=\{bundle.post_reset_cycles()} result=equal\n" +
    "Single-fixture differential comparison only; not the complete Phase 6 gate.",
  )
  let lines = bundle
    .expected_tsv()
    .split("\n")
    .map(line => line.to_owned())
    .to_array()
  lines[0] = FixtureChoice::Pipeline
    .bundle()
    .expected_tsv()
    .split("\n")
    .next()
    .unwrap()
    .to_owned()
  try audit_source(bundle, lines.join("\n")) catch {
    Phase6CliError::AuditMismatch(fixture~, identity=Identity(..)) =>
      assert_eq(fixture, bundle.id())
    other => fail("unexpected remote-fault identity error: \{Repr(other)}")
  } noraise {
    _ => fail("wrong-fixture result passed remote-fault audit")
  }
}

///|
test "capacity wrap fixture audit rejects another fixture identity" {
  let bundle = FixtureChoice::CapacityWrap.bundle()
  assert_eq(bundle.id(), "fetched-concurrent-1x1-k1-capacity-origin-wrap")
  assert_eq(
    audit_source(bundle, bundle.expected_tsv()),
    "fixture=\{bundle.id()} cycles=\{bundle.post_reset_cycles()} result=equal\n" +
    "Single-fixture differential comparison only; not the complete Phase 6 gate.",
  )
  let lines = bundle
    .expected_tsv()
    .split("\n")
    .map(line => line.to_owned())
    .to_array()
  lines[0] = FixtureChoice::Pipeline
    .bundle()
    .expected_tsv()
    .split("\n")
    .next()
    .unwrap()
    .to_owned()
  try audit_source(bundle, lines.join("\n")) catch {
    Phase6CliError::AuditMismatch(fixture~, identity=Identity(..)) =>
      assert_eq(fixture, bundle.id())
    other => fail("unexpected capacity-wrap identity error: \{Repr(other)}")
  } noraise {
    _ => fail("wrong-fixture result passed capacity-wrap audit")
  }
}

///|
test "ring control fixture audit binds recovery to its selected identity" {
  let bundle = FixtureChoice::RingControl.bundle()
  assert_eq(bundle.id(), "fetched-concurrent-1x1-k512-ring-control-recovery")
  assert_eq(
    audit_source(bundle, bundle.expected_tsv()),
    "fixture=\{bundle.id()} cycles=\{bundle.post_reset_cycles()} result=equal\n" +
    "Single-fixture differential comparison only; not the complete Phase 6 gate.",
  )
  let lines = bundle
    .expected_tsv()
    .split("\n")
    .map(line => line.to_owned())
    .to_array()
  lines[0] = FixtureChoice::Pipeline
    .bundle()
    .expected_tsv()
    .split("\n")
    .next()
    .unwrap()
    .to_owned()
  try audit_source(bundle, lines.join("\n")) catch {
    Phase6CliError::AuditMismatch(fixture~, identity=Identity(..)) =>
      assert_eq(fixture, bundle.id())
    other => fail("unexpected ring-control identity error: \{Repr(other)}")
  } noraise {
    _ => fail("wrong-fixture result passed ring-control audit")
  }
}
