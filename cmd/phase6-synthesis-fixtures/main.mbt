///|
suberror Phase6SynthesisCliError {
  Usage(String)
  ExistingOutput(path~ : String)
} derive(Debug)

///|
fn checked_new_directory(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    raise Phase6SynthesisCliError::ExistingOutput(path~)
  }
  @fs.create_dir(path)
}

///|
fn export_bundle(directory : String) -> String raise {
  let artifacts = @synthesis.generate_flux_tile_bundle()
  checked_new_directory(directory)
  for artifact in artifacts {
    @fs.write_string_to_file(directory + "/" + artifact.path, artifact.content)
  }
  "fixture=fetched-concurrent-1x1-k512-overlap artifacts=\{artifacts.length()} exported=\{directory}\n" +
  "Export only; run the existing pinned Yosys runner independently. No synthesis or physical RAM claim."
}

///|
fn run_command(args : ArrayView[String]) -> String raise {
  let usage = "Usage: phase6-synthesis-fixtures export DIRECTORY | help"
  match args {
    ["export", directory] => export_bundle(directory)
    [] | ["help" | "--help" | "-h"] => usage
    _ => raise Phase6SynthesisCliError::Usage(usage)
  }
}

///|
fn main raise {
  println(run_command(@env.args()[1:]))
}
