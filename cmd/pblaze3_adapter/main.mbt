///|
fn main raise {
  match @env.args()[1:] {
    [fixture] =>
      println(@validation.run_adapter_fixture(@fs.read_file_to_string(fixture)))
    [fixture, output] => {
      guard !@fs.path_exists(output) else {
        fail("fresh replay output required")
      }
      let files = @validation.adapter_replay_bundle(
        @fs.read_file_to_string(fixture),
      )
      @fs.create_dir(output)
      for file in files {
        @fs.write_string_to_file(output + "/" + file.path, file.content)
      }
      println("PASS adapter replay exported to " + output)
    }
    _ => fail("pblaze3_adapter FIXTURE_JSON [NEW_REPLAY_DIRECTORY]")
  }
}
