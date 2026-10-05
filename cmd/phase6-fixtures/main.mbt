///|
suberror Phase6CliError {
  Usage(String)
  ExistingOutput(path~ : String)
  AuditMismatch(fixture~ : String, identity~ : @differential.MismatchIdentity)
} derive(Debug)

///|
enum FixtureChoice {
  Pipeline
  Concurrent
  FaultReset
  Array8
  Seeded
}

///|
fn FixtureChoice::bundle(self : FixtureChoice) -> @phase6.FixtureBundle raise {
  match self {
    Pipeline => @phase6.generate_bundle()
    Concurrent => @phase6.generate_concurrent_bundle()
    FaultReset => @phase6.generate_fault_reset_bundle()
    Array8 => @phase6.generate_array8_bundle()
    Seeded => @phase6.generate_seeded_bundle()
  }
}

///|
fn checked_new_directory(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    raise Phase6CliError::ExistingOutput(path~)
  }
  @fs.create_dir(path)
}

///|
fn export_bundle(
  directory : String,
  fixture? : FixtureChoice = Pipeline,
) -> String raise {
  let bundle = fixture.bundle()
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
fn audit_file(
  path : String,
  fixture? : FixtureChoice = Pipeline,
) -> String raise {
  let actual = @fs.read_file_to_string(path)
  audit_source(fixture.bundle(), actual)
}

///|
fn run_command(args : ArrayView[String]) -> String raise {
  let usage = "Usage: phase6-fixtures export DIRECTORY | audit ACTUAL_TSV | export-concurrent DIRECTORY | audit-concurrent ACTUAL_TSV | export-fault-reset DIRECTORY | audit-fault-reset ACTUAL_TSV | export-array8 DIRECTORY | audit-array8 ACTUAL_TSV | export-seeded DIRECTORY | audit-seeded ACTUAL_TSV | help"
  match args {
    ["export", directory] => export_bundle(directory)
    ["audit", path] => audit_file(path)
    ["export-concurrent", directory] =>
      export_bundle(directory, fixture=Concurrent)
    ["audit-concurrent", path] => audit_file(path, fixture=Concurrent)
    ["export-fault-reset", directory] =>
      export_bundle(directory, fixture=FaultReset)
    ["audit-fault-reset", path] => audit_file(path, fixture=FaultReset)
    ["export-array8", directory] => export_bundle(directory, fixture=Array8)
    ["audit-array8", path] => audit_file(path, fixture=Array8)
    ["export-seeded", directory] => export_bundle(directory, fixture=Seeded)
    ["audit-seeded", path] => audit_file(path, fixture=Seeded)
    [] | ["help" | "--help" | "-h"] => usage
    _ => raise Phase6CliError::Usage(usage)
  }
}

///|
fn main raise {
  println(run_command(@env.args()[1:]))
}
