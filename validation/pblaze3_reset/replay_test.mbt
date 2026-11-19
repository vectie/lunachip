///|
test "independent reset oracle and deterministic export" {
  let first = @pblaze3_reset.replay_bundle()
  let second = @pblaze3_reset.replay_bundle()
  assert_eq(first.length(), second.length())
  for index in 0..<first.length() {
    assert_eq(first[index].path, second[index].path)
    assert_eq(first[index].content, second[index].content)
  }
}
