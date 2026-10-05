///|
fn parse_kind(text : String) -> @phase3.FixtureKind raise {
  match text {
    "combinational-logic" => CombinationalLogic
    "arithmetic" => Arithmetic
    "controlled-counter" => ControlledCounter
    "pipeline" => Pipeline
    "lfsr" => Lfsr
    "ready-valid" => ReadyValid
    _ => fail("unknown fixture kind: \{text}")
  }
}

///|
fn checked_new_directory(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    fail("refusing to overwrite existing output: \{path}")
  }
  @fs.create_dir(path)
}

///|
fn materialize(
  bundle : @phase3.FixtureBundle,
  directory : String,
) -> Unit raise {
  checked_new_directory(directory)
  for artifact in bundle.artifacts() {
    @fs.write_string_to_file(
      directory + "/" + artifact.path(),
      artifact.content(),
    )
  }
}

///|
fn write_standard(directory : String) -> Unit raise {
  checked_new_directory(directory)
  for plan in @phase3.standard_plan() {
    materialize(
      @phase3.generate_bundle(plan),
      directory + "/" + plan.kind().id(),
    )
  }
}

///|
fn verify_standard(directory : String) -> Unit raise {
  let mut total = 0
  for plan in @phase3.standard_plan() {
    let bundle = @phase3.generate_bundle(plan)
    let result_path = directory + "/" + plan.kind().id() + "/actual.tsv"
    let actual = @fs.read_file_to_string(result_path)
    match bundle.compare_actual_tsv(actual) {
      Equal => {
        println(
          "fixture=\{plan.kind().id()} cycles=\{plan.post_reset_cycles()} result=equal",
        )
        total += plan.post_reset_cycles()
      }
      Mismatch(mismatch) =>
        fail(
          "fixture=\{plan.kind().id()} result=mismatch identity=\{Repr(mismatch.identity())}",
        )
    }
  }
  println("aggregate cycles=\{total} result=equal")
}

///|
fn main raise {
  let args = @env.args()
  match args {
    [_, "standard", directory] => write_standard(directory)
    [_, "verify-standard", directory] => verify_standard(directory)
    [_, "one", kind, cycles, seed, directory] => {
      let parsed_cycles : Int = @string.parse_int(cycles)
      let parsed_seed : UInt64 = @string.parse_uint64(seed)
      let plan = @phase3.FixturePlan::checked(
        parse_kind(kind),
        parsed_seed,
        parsed_cycles,
      )
      materialize(@phase3.generate_bundle(plan), directory)
    }
    _ =>
      fail(
        "usage: phase3-fixtures standard OUT_DIR | verify-standard RESULTS_ROOT | one KIND CYCLES SEED OUT_DIR",
      )
  }
}
