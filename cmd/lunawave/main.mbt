///|
suberror LunaWaveCliError {
  Usage(String)
  ExistingOutput(path~ : String)
  ReplayFailed(
    stop_reached~ : Bool,
    expected_matches~ : Bool,
    expected_digest~ : String,
    actual_digest~ : String,
    output~ : String
  )
} derive(Debug)

///|
fn usage() -> String {
  "Usage: lunawave replay REPLAY_FILE NEW_OUTPUT_DIRECTORY | help"
}

///|
fn digest_text(digest : @replay.ReplayDigest) -> String {
  "\{digest.algorithm()}:\{digest.hex()}"
}

///|
fn replay_file(input : String, output : String) -> String raise {
  // Refuse an existing destination before reading input or running hardware.
  if @fs.path_exists(output) {
    raise LunaWaveCliError::ExistingOutput(path=output)
  }
  let bundle = @replay.parse(@fs.read_file_to_string(input))
  let result = @replay.execute(bundle)
  let trace = @trace.serialize(result.trace())
  let vcd = @trace.to_vcd(result.trace())
  // mkdir also rejects a destination created since the initial check. Input,
  // parse, execution and serialization failures create no output directory.
  @fs.create_dir(output)
  @fs.write_string_to_file(output + "/trace.txt", trace)
  @fs.write_string_to_file(output + "/trace.vcd", vcd)
  let expected_digest = digest_text(bundle.expected_result())
  let actual_digest = digest_text(result.digest())
  // A result mismatch is not an exception inside the replay engine. Preserve
  // its actual artifacts before making either incomplete outcome a CLI error.
  if !result.stop_reached() || !result.expected_matches() {
    raise LunaWaveCliError::ReplayFailed(
      stop_reached=result.stop_reached(),
      expected_matches=result.expected_matches(),
      expected_digest~,
      actual_digest~,
      output~,
    )
  }
  "stop_reached=\{result.stop_reached()} expected_matches=\{result.expected_matches()}\n" +
  "expected_digest=\{expected_digest} actual_digest=\{actual_digest}\n" +
  "trace=\{output}/trace.txt vcd=\{output}/trace.vcd\n" +
  "LunaWave simulation replay only; not independent RTL or formal evidence."
}

///|
fn run_command(args : ArrayView[String]) -> String raise {
  match args {
    ["replay", input, output] => replay_file(input, output)
    [] | ["help" | "--help" | "-h"] => usage()
    _ => raise LunaWaveCliError::Usage(usage())
  }
}

///|
fn main {
  println(run_command(@env.args()[1:])) catch {
    error => {
      println("lunawave: \{Repr(error)}")
      @sys.exit(1)
    }
  }
}
