///|
fn main raise {
  match @env.args()[1:] {
    ["export", root] => {
      guard !@fs.path_exists(root) else {
        fail("fresh output directory required")
      }
      @fs.create_dir(root)
      for file in @fixture.bundle() {
        @fs.write_string_to_file(root + "/" + file.path, file.content)
      }
      println("Exported canonical four-state reset campaign to " + root)
    }
    ["verify", root, actual] => {
      for file in @fixture.bundle() {
        assert_eq(@fs.read_file_to_string(root + "/" + file.path), file.content)
      }
      assert_eq(
        @fs.read_file_to_string(actual),
        @fs.read_file_to_string(root + "/expected-xsim.tsv"),
      )
      println(
        "PASS deterministic export and XSim trace including explicit baseline divergences",
      )
    }
    _ => fail("export FRESH_DIR | verify BUNDLE ACTUAL_TSV")
  }
}
