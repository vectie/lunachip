///|
test "canonical async reset fixture exports deterministic four-state campaign" {
  let first = @pblaze3_reset4state.bundle()
  let second = @pblaze3_reset4state.bundle()
  assert_eq(first.length(), 7)
  for index, file in first {
    assert_eq(file.path, second[index].path)
    assert_eq(file.content, second[index].content)
  }
  assert_true(
    first[0].content.contains("always_ff @(posedge lc_n0 or posedge lc_n1)"),
  )
  assert_true(
    first[0].content.contains("always_ff @(posedge lc_n0 or negedge lc_n2)"),
  )
  assert_true(first[0].content.contains("    if (lc_n1)"))
  assert_true(first[0].content.contains("    if (!lc_n2)"))
  assert_true(!first[1].content.contains("    if ("))
  assert_true(first[4].content.contains("xfail_x_between_edges_enabled"))
  assert_true(first[4].content.contains("xfail_z_between_edges_enabled"))
  assert_true(first[4].content != first[5].content)
}
