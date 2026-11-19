///|
suberror Phase6SynthesisCliError {
  Usage(String)
  ExistingOutput(path~ : String)
} derive(Debug)

///|
enum FixtureChoice {
  Pipeline
  Array8
}

///|
fn FixtureChoice::id(self : FixtureChoice) -> String {
  match self {
    Pipeline => "fetched-concurrent-1x1-k512-overlap"
    Array8 => "fetched-concurrent-8x8-k16-two-slots"
  }
}

///|
fn FixtureChoice::artifacts(
  self : FixtureChoice,
) -> ReadOnlyArray[@synthesis.BundleArtifact] raise {
  match self {
    Pipeline => @synthesis.generate_flux_tile_bundle()
    Array8 => @synthesis.generate_flux_tile_array8_bundle()
  }
}

///|
fn checked_new_directory(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    raise Phase6SynthesisCliError::ExistingOutput(path~)
  }
  @fs.create_dir(path)
}

///|
fn export_bundle(
  directory : String,
  fixture~ : FixtureChoice = Pipeline,
) -> String raise {
  let artifacts = fixture.artifacts()
  checked_new_directory(directory)
  for artifact in artifacts {
    @fs.write_string_to_file(directory + "/" + artifact.path, artifact.content)
  }
  "fixture=\{fixture.id()} artifacts=\{artifacts.length()} exported=\{directory}\n" +
  "Export only; run the existing pinned Yosys runner independently. No synthesis or physical RAM claim."
}

///|
fn run_command(args : ArrayView[String]) -> String raise {
  let usage = "Usage: phase6-synthesis-fixtures export DIRECTORY | export-array8 DIRECTORY | help"
  match args {
    ["export", directory] => export_bundle(directory)
    ["export-array8", directory] => export_bundle(directory, fixture=Array8)
    [] | ["help" | "--help" | "-h"] => usage
    _ => raise Phase6SynthesisCliError::Usage(usage)
  }
}

///|
fn main raise {
  println(run_command(@env.args()[1:]))
}
