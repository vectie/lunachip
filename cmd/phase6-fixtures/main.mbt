///|
suberror Phase6CliError {
  Usage(String)
  ExistingOutput(path~ : String)
  AuditMismatch(fixture~ : String, identity~ : @differential.MismatchIdentity)
} derive(Debug)

///|
fn checked_new_directory(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    raise Phase6CliError::ExistingOutput(path~)
  }
  @fs.create_dir(path)
}

///|
fn export_bundle(directory : String) -> String raise {
  let bundle = @phase6.generate_bundle()
  checked_new_directory(directory)
  for artifact in bundle.artifacts() {
    @fs.write_string_to_file(directory + "/" + artifact.path, artifact.content)
  }
  "fixture=\{bundle.id()} cycles=\{bundle.post_reset_cycles()} artifacts=\{bundle.artifacts().length()} exported=\{directory}\n" +
  "Export only; run the emitted harness independently and audit actual.tsv."
}

///|
fn audit_source(
  bundle : @phase6.FixtureBundle,
  actual : String,
) -> String raise {
  match bundle.compare_actual_tsv(actual) {
    Equal =>
      "fixture=\{bundle.id()} cycles=\{bundle.post_reset_cycles()} result=equal\n" +
      "Single-fixture differential comparison only; not the complete Phase 6 gate."
    Mismatch(mismatch) =>
      raise Phase6CliError::AuditMismatch(
        fixture=bundle.id(),
        identity=mismatch.identity(),
      )
  }
}

///|
fn audit_file(path : String) -> String raise {
  let actual = @fs.read_file_to_string(path)
  audit_source(@phase6.generate_bundle(), actual)
}

///|
fn run_command(args : ArrayView[String]) -> String raise {
  let usage = "Usage: phase6-fixtures export DIRECTORY | audit ACTUAL_TSV | help"
  match args {
    ["export", directory] => export_bundle(directory)
    ["audit", path] => audit_file(path)
    [] | ["help" | "--help" | "-h"] => usage
    _ => raise Phase6CliError::Usage(usage)
  }
}

///|
fn main raise {
  println(run_command(@env.args()[1:]))
}
