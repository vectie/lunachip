///|
test "full line writes preserve four distinct signed words and drain rejected requests" {
  let b = bridge_bench()
  write_line_replay(b)
}

///|
test "calibration loss while gathering a write line issues no native write" {
  let b = bridge_bench()
  b.begin_write_line(16UL, [0x80000000UL, 0x7fffffffUL, 0xffffffffUL, 0UL])
  set(b.sim, "calibrated", 1, 0UL)
  assert_eq(b.line_beat(9), (0UL, 2UL, 1UL))
  assert_eq(b.commands.length(), 0)
  assert_eq(b.data.length(), 0)
  assert_eq(b.memory[1], [0U, 0U, 0U, 0U])
  set(b.sim, "calibrated", 1, 1UL)
  for _ in 0..<16 {
    b.step()
  }
  assert_eq(value(b.sim, "memory_healthy"), 0UL)
  b.write_line(16UL, [1UL, 2UL, 3UL, 4UL], fault=2UL)
  b.reset()
  b.write_line(16UL, [1UL, 2UL, 3UL, 4UL])
}
