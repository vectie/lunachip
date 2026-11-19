///|
fn run() -> Unit raise {
  match @env.args()[1:] {
    ["export", root] => export_target(root)
    ["parallel-export", root] => export_target(root, parallel=true)
    ["parallel-replay", fixture, root] => parallel_replay(fixture, root)
    ["parallel-formal" | "parallel-formal-negative" as mode, root] =>
      parallel_formal(root, mode == "parallel-formal-negative")
    ["replay", fixture, root] => replay(fixture, root)
    ["audit", expected, actual] =>
      assert_eq(
        @fs.read_file_to_string(expected),
        @fs.read_file_to_string(actual),
      )
    ["formal" | "formal-negative" as mode, root] =>
      formal_bundle(root, mode == "formal-negative")
    _ => fail("export NEW_ROOT")
  }
}

///|
fn main {
  run() catch {
    e => abort(e.to_string())
  }
}
