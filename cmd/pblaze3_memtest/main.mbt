///|
fn artifacts(kind : String) -> ReadOnlyArray[@projection.Artifact] raise {
  match kind {
    "low" => @validation.replay_bundle()
    "high" => @validation.replay_bundle(high=true)
    "digital" => @validation.digital_bundle()
    "formal-positive" => @validation.formal_bundle()
    "formal-negative" => @validation.formal_bundle(negative=true)
    _ => fail("expected low, high or digital")
  }
}

///|
fn main raise {
  match @env.args()[1:] {
    ["export", kind, root] => {
      guard !@fs.path_exists(root) else { fail("fresh directory required") }
      let files = artifacts(kind)
      @fs.create_dir(root)
      for file in files {
        @fs.write_string_to_file(root + "/" + file.path, file.content)
      }
      println("Exported " + kind + " memtest: " + root)
    }
    ["verify", kind, root, actual] => {
      for file in artifacts(kind) {
        assert_eq(
          @fs.read_file_to_string(root + "/" + file.path),
          file.content,
          msg=file.path,
        )
      }
      assert_eq(
        @fs.read_file_to_string(actual),
        @fs.read_file_to_string(root + "/expected.tsv"),
      )
      println("PASS fresh deterministic LunaWave/Verilator replay " + kind)
    }
    ["deterministic", kind, root] => {
      for file in artifacts(kind) {
        assert_eq(
          @fs.read_file_to_string(root + "/" + file.path),
          file.content,
          msg=file.path,
        )
      }
      println("PASS deterministic " + kind)
    }
    _ => fail("export low|high|digital NEW_DIR; verify low|high DIR ACTUAL_TSV")
  }
}
