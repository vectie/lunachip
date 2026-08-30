///|
fn create_empty_directory(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    fail("refusing to overwrite output: \{path}")
  }
  @fs.create_dir(path)
}

///|
fn materialize_matrix(directory : String) -> Unit raise {
  create_empty_directory(directory)
  for stage_count in @synthesis.cdc_bit_synchronizer_stage_counts() {
    let bundle = @synthesis.generate_bit_synchronizer_bundle(stage_count)
    let fixture = "bit-synchronizer-\{stage_count}-stage"
    create_empty_directory(directory + "/" + fixture)
    for artifact in bundle.artifacts() {
      @fs.write_string_to_file(
        directory + "/" + fixture + "/" + artifact.path,
        artifact.content,
      )
    }
  }
}

///|
fn main raise {
  match @env.args() {
    [_, "matrix", directory] => materialize_matrix(directory)
    _ => fail("usage: phase5-sync-fixtures matrix OUT_DIR")
  }
}
