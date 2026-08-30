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
  for kind in @synthesis.toggle_synthesis_matrix() {
    let bundle = @synthesis.generate_toggle_synthesis_bundle(kind)
    let fixture = kind.id()
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
    _ => fail("usage: phase5-toggle-synthesis-fixtures matrix OUT_DIR")
  }
}
