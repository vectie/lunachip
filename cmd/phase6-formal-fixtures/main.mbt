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
  checked_new_directory(directory)
  for artifact in bundle.artifacts() {
    @fs.write_string_to_file(
      directory + "/" + artifact.path(),
      artifact.content(),
    )
  }
  export_report(bundle, directory)
}

///|
fn usage() -> String {
  "Usage: phase6-formal-fixtures export FIXTURE_ID DIRECTORY | help\n" +
  "Fixtures: phase6-flux-tile-public-transport | phase6-flux-tile-negative-request-bounds | phase6-flux-tile-negative-request-stability"
}

///|
fn run_command(args : ArrayView[String]) -> String raise {
  match args {
    ["export", id, directory] => export_fixture(parse_fixture(id), directory)
    [] | ["help" | "--help" | "-h"] => usage()
    _ => raise FormalFixtureCliError::Usage(usage())
  }
}

///|
fn main raise {
  println(run_command(@env.args()[1:]))
}
