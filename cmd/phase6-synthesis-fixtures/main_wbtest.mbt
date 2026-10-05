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
  let usage = "Usage: phase6-synthesis-fixtures export DIRECTORY | help"
  for args in [[], ["help"], ["--help"], ["-h"]] {
    assert_eq(run_command(args), usage)
  }
  for
    args in [
      ["export"],
      ["unknown"],
      ["export", ".", "extra"],
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
