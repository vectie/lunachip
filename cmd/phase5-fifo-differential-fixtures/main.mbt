///|
fn empty_dir(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    fail("refusing to overwrite output: \{path}")
  }
  @fs.create_dir(path)
}

///|
fn write_bundle(
  path : String,
  bundle : @phase5_fifo.FifoFixtureBundle,
) -> Unit raise {
  empty_dir(path)
  for artifact in bundle.artifacts() {
    @fs.write_string_to_file(path + "/" + artifact.path(), artifact.content())
  }
}

///|
fn kind(id : String) -> @phase5_fifo.FifoFixtureKind raise {
  match id {
    "depth4-coprime-scalar-2stage" => Depth4ScalarTwoStage
    "depth8-noncoprime-aggregate64-3stage" => Depth8AggregateThreeStage
    "depth4-asymmetric-coincident-4stage" => Depth4AsymmetricFourStage
    _ => fail("unknown fixture: \{id}")
  }
}

///|
fn main raise {
  match @env.args() {
    [_, "matrix", path] => {
      empty_dir(path)
      for fixture in @phase5_fifo.standard_fifo_fixtures() {
        write_bundle(
          path + "/" + fixture.id(),
          @phase5_fifo.generate_fifo_fixture(fixture),
        )
      }
    }
    [_, "negative", path] => {
      empty_dir(path)
      write_bundle(
        path + "/depth4-asymmetric-sequential-negative",
        @phase5_fifo.generate_sequential_negative_fixture(),
      )
    }
    [_, "verify", id, actual] =>
      match
        @phase5_fifo.generate_fifo_fixture(kind(id)).compare_actual(
          @fs.read_file_to_string(actual),
        ) {
        None => println("equal\t\{id}")
        Some(m) => fail("mismatch \{m.output()} at \{m.time()}/\{m.boundary()}")
      }
    [_, "verify-negative", actual] => {
      let m = @phase5_fifo.verify_sequential_negative(
        @fs.read_file_to_string(actual),
      )
      println(
        "required-mismatch\ttime=\{m.time()}\tboundary=\{m.boundary()}\toutput=\{m.output()}\texpected=\{m.expected()}\tactual=\{m.actual()}",
      )
    }
    _ =>
      fail(
        "usage: phase5-fifo-differential-fixtures {matrix OUT|negative OUT|verify FIXTURE ACTUAL|verify-negative ACTUAL}",
      )
  }
}
