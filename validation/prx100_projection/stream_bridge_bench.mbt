///|
fn stream_bridge_replay(b : BridgeBench) -> Unit raise {
  // Distinct signed boundary/data patterns in every line/lane, written through
  // the independently masked native model before a single streamed request.
  for line in 0..<8 {
    for lane in 0..<4 {
      let word = [0x80000000UL, 0x7fffffffUL, 0xffffffffUL, 0x01234567UL][lane] ^
        (line.to_uint64() * 0x10101UL)
      assert_eq(
        b.transaction(
          896UL + line.to_uint64() * 16UL + lane.to_uint64() * 4UL,
          word~,
        ),
        (0UL, 0UL),
      )
    }
  }
  let before = b.reads.length()
  b.begin_line(896UL, burst=true)
  // Accepted ownership must survive changing every source request field.
  set(b.sim, "request_burst", 1, 0UL)
  set(b.sim, "request_line", 1, 0UL)
  set(b.sim, "request_address", 28, 0UL)
  set(b.sim, "request_write", 1, 1UL)
  for beat in 0..<32 {
    let word = [0x80000000UL, 0x7fffffffUL, 0xffffffffUL, 0x01234567UL][beat % 4] ^
      ((beat / 4).to_uint64() * 0x10101UL)
    assert_eq(
      b.line_beat(3 + beat % 7),
      (word, 0UL, if beat == 31 { 1UL } else { 0UL }),
    )
  }
  assert_eq(b.reads.length(), before + 8)
  assert_eq(value(b.sim, "request_ready"), 1UL)
  // A burst does not install its first line under the portal's old cache key.
  assert_eq(b.transaction(896UL), (0x80000000UL, 0UL))
  assert_eq(b.reads.length(), before + 9)
  for address in [16UL, 112UL, 1008UL] {
    let reads = b.reads.length()
    b.begin_line(address, burst=true)
    for beat in 0..<32 {
      assert_eq(b.line_beat(2), (0UL, 1UL, if beat == 31 { 1UL } else { 0UL }))
    }
    assert_eq(b.reads.length(), reads)
  }
  b.begin_line(896UL, burst=true)
  for _ in 0..<7 {
    ignore(b.line_beat(2))
  }
  b.reset()
  assert_eq(b.transaction(1020UL), (0x01234567UL ^ (7UL * 0x10101UL), 0UL))
}
