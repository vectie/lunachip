///|
test "one DDR line streams four ordered held beats and preserves the word portal" {
  let b = bridge_bench()
  let codes = [0x80000000UL, 0xffffffffUL, 0x01234567UL, 0x89abcdefUL]
  for lane, word in codes {
    assert_eq(b.transaction(lane.to_uint64() * 4UL, word~), (0UL, 0UL))
  }
  let before = b.reads.length()
  let result = b.line_transaction(0UL, 13)
  for lane, word in codes {
    assert_eq(result[lane], (word, 0UL, if lane == 3 { 1UL } else { 0UL }))
  }
  assert_eq(b.reads.length(), before + 1)
  // A complete successful stream installs all four words for ordinary reads.
  for lane in [3, 1, 0, 2] {
    assert_eq(b.transaction(lane.to_uint64() * 4UL, hold=3), (codes[lane], 0UL))
  }
  assert_eq(b.reads.length(), before + 1)
  let result = b.line_transaction(4UL, 5)
  for lane in 0..<4 {
    assert_eq(result[lane], (0UL, 1UL, if lane == 3 { 1UL } else { 0UL }))
  }
  assert_eq(b.reads.length(), before + 1) // rejected before any native command
}

///|
test "partial line reset and malformed native reply cannot publish stale words" {
  let b = bridge_bench()
  for lane in 0..<4 {
    assert_eq(
      b.transaction(lane.to_uint64() * 4UL, word=31UL + lane.to_uint64()),
      (0UL, 0UL),
    )
  }
  b.begin_line(0UL)
  assert_eq(b.line_beat(11), (31UL, 0UL, 0UL))
  assert_eq(b.line_beat(7), (32UL, 0UL, 0UL))
  b.reset()
  let result = b.line_transaction(0UL, 3)
  for lane in 0..<4 {
    assert_eq(
      result[lane],
      (31UL + lane.to_uint64(), 0UL, if lane == 3 { 1UL } else { 0UL }),
    )
  }
  b.environment(bad_end=true)
  let result = b.line_transaction(0UL, 3)
  for lane in 0..<4 {
    assert_eq(result[lane], (0UL, 3UL, if lane == 3 { 1UL } else { 0UL }))
  }
  assert_eq(value(b.sim, "memory_healthy"), 0UL)
  b.environment()
  b.reset()
  assert_eq(b.transaction(12UL), (34UL, 0UL))
}
