///|
fn create_empty_directory(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    fail("refusing to overwrite output: \{path}")
  }
  @fs.create_dir(path)
}

///|
fn write_bundle(
  directory : String,
  bundle : @phase5_handshake_diff.HandshakeFixtureBundle,
) -> Unit raise {
  create_empty_directory(directory)
  for artifact in bundle.artifacts() {
    @fs.write_string_to_file(
      directory + "/" + artifact.path(),
      artifact.content(),
    )
  }
}

///|
fn materialize_matrix(directory : String) -> Unit raise {
  create_empty_directory(directory)
  for kind in @phase5_handshake_diff.standard_handshake_fixtures() {
    try
      write_bundle(
        directory + "/" + kind.id(),
        @phase5_handshake_diff.generate_handshake_fixture(kind),
      )
    catch {
      error => fail("fixture \{kind.id()} failed: \{Repr(error)}")
    } noraise {
      _ => ()
    }
  }
}

///|
fn materialize_negative(directory : String) -> Unit raise {
  create_empty_directory(directory)
  write_bundle(
    directory + "/coincident-sequential-negative",
    @phase5_handshake_diff.generate_sequential_negative_fixture(),
  )
}

///|
fn fixture_kind(
  id : String,
) -> @phase5_handshake_diff.HandshakeFixtureKind raise {
  match id {
    "directed-2-stage-scalar" => DirectedScalar
    "rational-3-stage-multi-leaf" => MultiLeafRational
    "coincident-4-stage-refill" => CoincidentRefill
    "coordinated-reset-unilateral-flush" => CoordinatedResetFlush
    "seeded-rational-stream" => SeededRational
    _ => fail("unknown fixture: \{id}")
  }
}

///|
fn verify_positive(id : String, actual_path : String) -> Unit raise {
  let bundle = @phase5_handshake_diff.generate_handshake_fixture(
    fixture_kind(id),
  )
  match bundle.compare_actual(@fs.read_file_to_string(actual_path)) {
    None =>
      println(
        "equal\t\{id}\tevents=\{bundle.stimulus().events().length()}\tclass=\{bundle.kind().evidence_class()}",
      )
    Some(mismatch) =>
      fail(
        "mismatch \{id} time=\{mismatch.time()} boundary=\{mismatch.boundary()} output=\{mismatch.output()} expected=\{mismatch.expected()} actual=\{mismatch.actual()}",
      )
  }
}

///|
fn verify_negative(actual_path : String) -> Unit raise {
  let mismatch = @phase5_handshake_diff.verify_sequential_negative(
    @fs.read_file_to_string(actual_path),
  )
  println(
    "required-mismatch\ttime=\{mismatch.time()}\tboundary=\{mismatch.boundary()}\toutput=\{mismatch.output()}\texpected=\{mismatch.expected()}\tactual=\{mismatch.actual()}",
  )
}

///|
fn main raise {
  match @env.args() {
    [_, "matrix", directory] => materialize_matrix(directory)
    [_, "negative", directory] => materialize_negative(directory)
    [_, "verify", id, actual] => verify_positive(id, actual)
    [_, "verify-negative", actual] => verify_negative(actual)
    _ =>
      fail(
        "usage: phase5-handshake-differential-fixtures {matrix OUT|negative OUT|verify FIXTURE ACTUAL|verify-negative ACTUAL}",
      )
  }
}
