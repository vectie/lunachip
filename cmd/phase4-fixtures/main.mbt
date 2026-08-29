///|
fn parse_kind(text : String) -> @phase4.FixtureKind raise {
  match text {
    "whole-read-old" => WholeReadOld
    "whole-read-new" => WholeReadNew
    "no-change" => NoChange
    "undefined-safe" => UndefinedSafe
    "masked-write" => MaskedWrite
    "non-power-of-two" => NonPowerOfTwo
    "enables" => Enables
    "lower-port-id-wins" => LowerPortIdWins
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
  bundle : @phase4.FixtureBundle,
  directory : String,
) -> Unit raise {
  checked_new_directory(directory)
  for artifact in bundle.artifacts() {
    @fs.write_string_to_file(directory + "/" + artifact.path, artifact.content)
  }
}

///|
fn materialize_negative(
  bundle : @phase4.NegativeFixtureBundle,
  directory : String,
) -> Unit raise {
  checked_new_directory(directory)
  for artifact in bundle.artifacts() {
    @fs.write_string_to_file(directory + "/" + artifact.path, artifact.content)
  }
}

///|
fn write_standard(directory : String) -> Unit raise {
  checked_new_directory(directory)
  for plan in @phase4.standard_plan() {
    materialize(
      @phase4.generate_bundle(plan),
      directory + "/" + plan.kind().id(),
    )
  }
}

///|
fn write_negative(directory : String) -> Unit raise {
  checked_new_directory(directory)
  let kinds : Array[@phase4.NegativeFixtureKind] = [
    FaultOutOfBounds,
    DynamicRejectCollision,
  ]
  for kind in kinds {
    materialize_negative(
      @phase4.generate_negative_bundle(kind),
      directory + "/" + kind.id(),
    )
  }
}

///|
fn verify_standard(directory : String) -> Unit raise {
  let mut total = 0
  for plan in @phase4.standard_plan() {
    let bundle = @phase4.generate_bundle(plan)
    let actual = @fs.read_file_to_string(
      directory + "/" + plan.kind().id() + "/actual.tsv",
    )
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
    [_, "negative", directory] => write_negative(directory)
    [_, "verify-standard", directory] => verify_standard(directory)
    [_, "one", kind, cycles, seed, directory] => {
      let plan = @phase4.FixturePlan::checked(
        parse_kind(kind),
        @strconv.from_str(seed),
        @strconv.from_str(cycles),
      )
      materialize(@phase4.generate_bundle(plan), directory)
    }
    _ =>
      fail(
        "usage: phase4-fixtures standard OUT_DIR | negative OUT_DIR | verify-standard RESULTS_ROOT | one KIND CYCLES SEED OUT_DIR",
      )
  }
}
