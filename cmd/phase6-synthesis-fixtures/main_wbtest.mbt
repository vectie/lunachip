///|
test "synthesis export refuses existing output without touching it" {
  try checked_new_directory(".") catch {
    Phase6SynthesisCliError::ExistingOutput(path=".") => ()
    other => fail("unexpected existing-output error: \{Repr(other)}")
  } noraise {
    _ => fail("existing output must not be reused")
  }
}

///|
test "synthesis fixture CLI help and arity remain explicit" {
  let usage = "Usage: phase6-synthesis-fixtures export DIRECTORY | export-array8 DIRECTORY | help"
  for args in [[], ["help"], ["--help"], ["-h"]] {
    assert_eq(run_command(args), usage)
  }
  for
    args in [
      ["export"],
      ["export-array8"],
      ["unknown"],
      ["export", ".", "extra"],
      ["export-array8", ".", "extra"],
      ["help", "extra"],
    ] {
    try run_command(args) catch {
      Phase6SynthesisCliError::Usage(actual) => assert_eq(actual, usage)
      other => fail("unexpected usage error: \{Repr(other)}")
    } noraise {
      _ => fail("invalid command must not run")
    }
  }
}

///|
test "synthesis fixture selectors retain their exact replay identities" {
  assert_eq(FixtureChoice::Pipeline.id(), "fetched-concurrent-1x1-k512-overlap")
  assert_eq(FixtureChoice::Array8.id(), "fetched-concurrent-8x8-k16-two-slots")
}
