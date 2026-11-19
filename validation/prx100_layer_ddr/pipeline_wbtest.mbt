///|
test "eight native credits survive blocked source and consecutive unstallable returns" {
  for period in [2, 4, 7] {
    let b = bridge_bench(period~)
    for line in 0..<8 {
      for lane in 0..<4 {
        b.memory[line][lane] = 0x80000000U +
          (line * 4 + lane).reinterpret_as_uint()
      }
    }
    b.read_delay = 60
    b.begin_line(0UL, burst=true)
    for _ in 0..<200 {
      b.step()
    }
    assert_eq(b.reads.length(), 8)
    assert_eq(b.max_outstanding.val, 8)
    assert_eq(value(b.sim, "request_ready"), 0UL)
    for beat in 0..<32 {
      assert_eq(
        b.line_beat(beat % 11),
        (
          0x80000000UL + beat.to_uint64(),
          0UL,
          if beat == 31 {
            1UL
          } else {
            0UL
          },
        ),
      )
    }
    assert_eq(value(b.sim, "request_ready"), 1UL)
    assert_eq(b.transaction(124UL), (0x8000001fUL, 0UL))
  }
}

///|
test "bounded pipeline is faster than serialized lines with identical data" {
  let old = bridge_bench(legacy=true)
  let new = bridge_bench()
  let before_old = old.tick
  old.begin_line(0UL, burst=true)
  for _ in 0..<32 {
    ignore(old.line_beat(0))
  }
  let before_new = new.tick
  new.begin_line(0UL, burst=true)
  for _ in 0..<32 {
    ignore(new.line_beat(0))
  }
  assert_true(new.tick - before_new < old.tick - before_old)
  assert_eq(old.results, new.results)
}

///|
test "reset discards every pipeline prefix and queued return" {
  let b = bridge_bench()
  for beats in [0, 1, 7, 31] {
    b.begin_line(0UL, burst=true)
    for _ in 0..<beats {
      ignore(b.line_beat(0))
    }
    b.reset()
    assert_eq(b.transaction(0UL), (0UL, 0UL))
  }
}
