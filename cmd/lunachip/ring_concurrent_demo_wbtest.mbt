///|
test "CLI fetched concurrent demo checks ordered duplicate IDs and real DMA overlap" {
  let result = run_command(["ring-concurrent-demo"])
  assert_true(result.contains("C0=8x8 C1=8x8 signed INT8 K=16 oracle=match"))
  assert_true(
    result.contains(
      "8 ordered successful completions with duplicate caller ID=42",
    ),
  )
  assert_true(result.contains("operand_read_edges="))
  assert_true(result.contains("store_write_edges="))
  assert_true(result.contains("all 1024 host bytes checked, padding preserved"))
  assert_true(
    result.contains(
      "Simulation only; provisional fetched concurrent device, not hardware performance.",
    ),
  )
}
