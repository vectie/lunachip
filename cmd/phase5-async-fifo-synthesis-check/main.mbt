///|
enum AsyncFifoSynthesisCheckCommand {
  Check(String, String, String, String, String)
} derive(Debug, Eq)

///|
fn parse_async_fifo_synthesis_check_command(
  arguments : Array[String],
) -> AsyncFifoSynthesisCheckCommand raise {
  match arguments {
    [_, "check", inventory, pre_map_json, pre_map_rtlil, yosys_lock, output] =>
      Check(inventory, pre_map_json, pre_map_rtlil, yosys_lock, output)
    _ =>
      fail(
        "usage: phase5-async-fifo-synthesis-check check INVENTORY_JSON PRE_MAP_JSON PRE_MAP_RTLIL YOSYS_LOCK OUT_DIR",
      )
  }
}

///|
fn async_fifo_evidence_output_path(output_directory : String) -> String {
  output_directory + "/async-fifo-synthesis-evidence.json"
}

///|
fn create_new_output_directory(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    fail("refusing to overwrite output: \{path}")
  }
  @fs.create_dir(path)
}

///|
fn run_async_fifo_synthesis_check(
  inventory_path : String,
  pre_map_json_path : String,
  pre_map_rtlil_path : String,
  yosys_lock_path : String,
  output_directory : String,
) -> Unit raise {
  if @fs.path_exists(output_directory) {
    fail("refusing to overwrite output: \{output_directory}")
  }
  let report = @synthesis.finalize_async_fifo_synthesis_evidence(
    @fs.read_file_to_string(inventory_path),
    @fs.read_file_to_string(pre_map_json_path),
    @fs.read_file_to_string(pre_map_rtlil_path),
    @fs.read_file_to_string(yosys_lock_path),
  )
  create_new_output_directory(output_directory)
  @fs.write_string_to_file(
    async_fifo_evidence_output_path(output_directory),
    report.to_canonical_json(),
  )
  if !report.passed() {
    fail("asynchronous FIFO synthesis evidence did not pass")
  }
}

///|
fn main raise {
  match parse_async_fifo_synthesis_check_command(@env.args()) {
    Check(inventory, pre_map_json, pre_map_rtlil, yosys_lock, output) =>
      run_async_fifo_synthesis_check(
        inventory, pre_map_json, pre_map_rtlil, yosys_lock, output,
      )
  }
}
