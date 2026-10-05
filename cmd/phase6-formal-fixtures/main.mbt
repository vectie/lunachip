///|
suberror FormalFixtureCliError {
  Usage(String)
  UnknownFixture(id~ : String)
  ExistingOutput(path~ : String)
} derive(Debug)

///|
fn parse_fixture(
  id : String,
) -> @gate.FluxTileFormalFixture raise FormalFixtureCliError {
  match @gate.FluxTileFormalFixture::from_id(id) {
    Some(fixture) => fixture
    None => raise UnknownFixture(id~)
  }
}

///|
fn checked_new_directory(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    raise FormalFixtureCliError::ExistingOutput(path~)
  }
  @fs.create_dir(path)
}

///|
fn write_artifacts(
  artifacts : ReadOnlyArray[@gate.FormalBundleArtifact],
  directory : String,
) -> Unit raise {
  checked_new_directory(directory)
  for artifact in artifacts {
    @fs.write_string_to_file(
      directory + "/" + artifact.path(),
      artifact.content(),
    )
  }
}

///|
fn export_report(
  bundle : @gate.FluxTileFormalBundle,
  directory : String,
) -> String {
  "fixture=\{bundle.fixture().id()} artifacts=\{bundle.artifacts().length()} tasks=\{bundle.tasks().length()} exported=\{directory}\n" +
  "Export only; no formal result claimed."
}

///|
fn export_fixture(
  fixture : @gate.FluxTileFormalFixture,
  directory : String,
) -> String raise {
  let bundle = @gate.generate_flux_tile_formal_bundle(fixture)
  write_artifacts(bundle.artifacts(), directory)
  export_report(bundle, directory)
}

///|
fn dependency_export_report(
  bundle : @gate.DependencyFormalBundle,
  directory : String,
) -> String {
  "fixture=\{bundle.fixture().id()} artifacts=\{bundle.artifacts().length()} tasks=\{bundle.tasks().length()} exported=\{directory}\n" +
  "Export only; no formal result claimed."
}

///|
fn export_dependency_fixture(
  fixture : @gate.DependencyFormalFixture,
  directory : String,
) -> String raise {
  let bundle = @gate.generate_dependency_formal_bundle(fixture)
  write_artifacts(bundle.artifacts(), directory)
  dependency_export_report(bundle, directory)
}

///|
fn usage() -> String {
  "Usage: phase6-formal-fixtures export FIXTURE_ID DIRECTORY | generation-lemma DIRECTORY | help\n" +
  "Fixtures: phase6-flux-tile-public-transport | phase6-flux-tile-negative-request-bounds | phase6-flux-tile-negative-request-stability" +
  " | phase6-flux-tile-directed-first-terminal" +
  " | phase6-dependency-latest-writer | phase6-dependency-negative-failed-generation | phase6-dependency-negative-new-intent-priority | phase6-dependency-negative-inner-identity"
}

///|
fn run_command(args : ArrayView[String]) -> String raise {
  match args {
    ["generation-lemma", directory] => {
      let artifacts = @gate.generate_dependency_generation_lemma_artifacts()
      write_artifacts(artifacts, directory)
      "Local generation lemma inputs: artifacts=\{artifacts.length()} exported=\{directory}\n" +
      "Export only; no proof, intermediate decoder equivalence or composition claimed."
    }
    ["export", id, directory] =>
      match @gate.DependencyFormalFixture::from_id(id) {
        Some(fixture) => export_dependency_fixture(fixture, directory)
        None => export_fixture(parse_fixture(id), directory)
      }
    [] | ["help" | "--help" | "-h"] => usage()
    _ => raise FormalFixtureCliError::Usage(usage())
  }
}

///|
fn main raise {
  println(run_command(@env.args()[1:]))
}
