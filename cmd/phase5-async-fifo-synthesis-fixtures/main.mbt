///|
fn empty(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    fail("refusing to overwrite output: \{path}")
  }
  @fs.create_dir(path)
}

///|
fn main raise {
  match @env.args() {
    [_, "matrix", root] => {
      empty(root)
      for kind in @synthesis.async_fifo_synthesis_matrix() {
        let directory = root + "/" + kind.id()
        empty(directory)
        for
          artifact in @synthesis.generate_async_fifo_synthesis_bundle(kind).artifacts() {
          @fs.write_string_to_file(
            directory + "/" + artifact.path,
            artifact.content,
          )
        }
      }
    }
    _ => fail("usage: phase5-async-fifo-synthesis-fixtures matrix OUT_DIR")
  }
}
