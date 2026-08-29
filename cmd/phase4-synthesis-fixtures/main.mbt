///|
fn parse_kind(text : String) -> @synthesis.SynthesisKind raise {
  match text {
    "single-read-old" => SingleReadOld
    "single-read-new" => SingleReadNew
    "single-no-change" => SingleNoChange
    "single-undefined" => SingleUndefined
    "single-masked" => SingleMasked
    "multiwrite-lower-port-id-wins" => MultiwriteLowerPortIdWins
    "multiwrite-reject" => MultiwriteReject
    "fifo" => Fifo
    "banked-memory" => BankedMemory
    _ => fail("unknown synthesis fixture: \{text}")
  }
}

///|
fn create_empty_directory(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    fail("refusing to overwrite output: \{path}")
  }
  @fs.create_dir(path)
}

///|
fn materialize(
  kind : @synthesis.SynthesisKind,
  directory : String,
) -> Unit raise {
  create_empty_directory(directory)
  for artifact in @synthesis.generate_bundle(kind).artifacts() {
    @fs.write_string_to_file(directory + "/" + artifact.path, artifact.content)
  }
}

///|
fn materialize_matrix(directory : String) -> Unit raise {
  create_empty_directory(directory)
  for kind in @synthesis.synthesis_matrix() {
    materialize(kind, directory + "/" + kind.id())
  }
}

///|
fn main raise {
  match @env.args() {
    [_, "matrix", directory] => materialize_matrix(directory)
    [_, "one", kind, directory] => materialize(parse_kind(kind), directory)
    _ =>
      fail("usage: phase4-synthesis-fixtures matrix OUT_DIR | one KIND OUT_DIR")
  }
}
