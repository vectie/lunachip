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
  let usage = "Usage: phase6-fixtures export DIRECTORY | audit ACTUAL_TSV | export-concurrent DIRECTORY | audit-concurrent ACTUAL_TSV | help"
  for args in [[], ["help"], ["--help"], ["-h"]] {
    assert_eq(run_command(args), usage)
  }
  for
    args in [
      ["export"],
      ["audit"],
      ["export-concurrent"],
      ["audit-concurrent"],
      ["unknown"],
      ["export", ".", "extra"],
      ["export-concurrent", ".", "extra"],
      ["audit-concurrent", ".", "extra"],
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
