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
fn queue_export_report(
  bundle : @gate.QueueFormalBundle,
  directory : String,
) -> String {
  "fixture=\{bundle.fixture().id()} artifacts=\{bundle.artifacts().length()} tasks=\{bundle.tasks().length()} exported=\{directory}\n" +
  "Export only; no formal result claimed."
}

///|
fn export_queue_fixture(
  fixture : @gate.QueueFormalFixture,
  directory : String,
) -> String raise {
  let bundle = @gate.generate_queue_formal_bundle(fixture)
  write_artifacts(bundle.artifacts(), directory)
  queue_export_report(bundle, directory)
}

///|
fn usage() -> String {
  "Usage: phase6-formal-fixtures export FIXTURE_ID DIRECTORY | generation-lemma DIRECTORY | compute-generation DIRECTORY | queue-control DIRECTORY | queue-monitor DIRECTORY | queue-owner DIRECTORY | help\n" +
  "Fixtures: phase6-flux-tile-public-transport | phase6-flux-tile-negative-request-bounds | phase6-flux-tile-negative-request-stability" +
  " | phase6-flux-tile-directed-first-terminal" +
  " | phase6-dependency-latest-writer | phase6-dependency-negative-failed-generation | phase6-dependency-negative-new-intent-priority | phase6-dependency-negative-inner-identity" +
  " | phase6-dependency-generation-support" +
  " | phase6-queue-conservation | phase6-queue-negative-population" +
  " | phase6-queue-retirement-records | phase6-queue-negative-held-payload" +
  " | phase6-queue-packet-provenance | phase6-queue-negative-packet-provenance\n" +
  "queue-control exports local proof inputs only; no proof or result receipt.\n" +
  "queue-monitor exports original monitor inputs only; no proof or full-device result receipt.\n" +
  "queue-owner exports supporting ownership inputs only; no proof or full-device result receipt."
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
    ["compute-generation", directory] => {
      let artifacts = @gate.generate_dependency_compute_generation_artifacts()
      write_artifacts(artifacts, directory)
      "Local generation/compute proof inputs: artifacts=\{artifacts.length()} exported=\{directory}\n" +
      "Export only; no proof, authorization or full-device composition claimed."
    }
    ["queue-control", directory] => {
      let artifacts = @gate.generate_queue_control_proof_artifacts()
      write_artifacts(artifacts, directory)
      "Local queue-control proof inputs: artifacts=\{artifacts.length()} exported=\{directory}\n" +
      "Export only; no proof, result receipt, engine ownership or full-device composition claimed."
    }
    ["queue-monitor", directory] => {
      let artifacts = @gate.generate_queue_monitor_proof_artifacts()
      write_artifacts(artifacts, directory)
      "Original queue-monitor proof inputs: artifacts=\{artifacts.length()} exported=\{directory}\n" +
      "Export only; no proof, result receipt, memory safety or full-device gate claimed."
    }
    ["queue-owner", directory] => {
      let artifacts = @gate.generate_queue_owner_proof_artifacts()
      write_artifacts(artifacts, directory)
      "Engine/live-entry ownership proof inputs: artifacts=\{artifacts.length()} exported=\{directory}\n" +
      "Export only; no proof, result receipt, payload correctness or full-device gate claimed."
    }
    ["export", id, directory] =>
      match @gate.QueueFormalFixture::from_id(id) {
        Some(fixture) => export_queue_fixture(fixture, directory)
        None =>
          match @gate.DependencyFormalFixture::from_id(id) {
            Some(fixture) => export_dependency_fixture(fixture, directory)
            None => export_fixture(parse_fixture(id), directory)
          }
      }
    [] | ["help" | "--help" | "-h"] => usage()
    _ => raise FormalFixtureCliError::Usage(usage())
  }
}

///|
fn main raise {
  println(run_command(@env.args()[1:]))
}
