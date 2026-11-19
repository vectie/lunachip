///|
fn bundle(kind : String) -> ReadOnlyArray[@projection.Artifact] raise {
  match kind {
    "export" => @validation.replay_bundle()
    "formal-positive" => @validation.formal_bundle()
    "formal-negative" => @validation.formal_bundle(negative=true)
    _ => fail("unknown reset fixture kind")
  }
}

///|
fn deterministic(kind : String, root : String) -> Unit raise {
  for file in bundle(kind) {
    assert_eq(@fs.read_file_to_string(root + "/" + file.path), file.content)
  }
  println("PASS fresh reset elaboration matches " + kind)
}

///|
fn main raise {
  match @env.args()[1:] {
    [kind, root] if ["export", "formal-positive", "formal-negative"].contains(
        kind,
      ) => {
      guard !@fs.path_exists(root) else {
        fail("fresh output directory required")
      }
      @fs.create_dir(root)
      for file in bundle(kind) {
        guard !file.path.contains("/") && !file.path.contains("..") else {
          fail("flat artifact path required")
        }
        @fs.write_string_to_file(root + "/" + file.path, file.content)
      }
      println("Exported " + kind)
    }
    ["deterministic", kind, root] => deterministic(kind, root)
    ["verify", root, actual] => {
      deterministic("export", root)
      assert_eq(
        @fs.read_file_to_string(actual),
        @fs.read_file_to_string(root + "/expected.tsv"),
      )
      println("PASS byte-exact LunaWave/RTL asynchronous reset replay")
    }
    _ =>
      fail(
        "export|formal-positive|formal-negative NEW_DIR; deterministic KIND DIR; verify INPUT ACTUAL",
      )
  }
}
