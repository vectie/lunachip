///|
test "synthesis matrix covers all required forms with explicit expectations" {
  let matrix = @synthesis.synthesis_matrix()
  assert_eq(matrix.length(), 9)
  let mut required = 0
  let mut observed = 0
  for kind in matrix {
    if kind.requires_inferred_memory() {
      required += 1
    } else {
      observed += 1
    }
  }
  assert_eq(required, 7)
  assert_eq(observed, 2)
}

///|
test "pure emitted RTL bundles are deterministic and content bound" {
  for kind in @synthesis.synthesis_matrix() {
    let first = @synthesis.generate_bundle(kind)
    let second = @synthesis.generate_bundle(kind)
    assert_eq(first.artifacts(), second.artifacts())
    assert_true(first.job_json().contains("\"formal_tasks\": []"))
    assert_false(first.job_json().contains("harness"))
    assert_false(first.job_json().contains("stimulus"))
    assert_true(first.design().top_module().unwrap().memories().length() >= 1)
  }
}
