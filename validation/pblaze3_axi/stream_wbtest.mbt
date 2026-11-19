///|
test "streaming bridge preserves every request shape and all eight write lanes" {
  let b = bench(streaming=true)
  exercise(b)
  for offset in 0..<16 {
    let a = 0x7fffffc0UL + offset.to_uint64() * 4UL
    b.begin(a, write=true, data=[a, 0UL, 0UL, 0UL])
    ignore(b.finish())
    b.begin(a)
    assert_eq(b.finish()[0].0[0], a)
  }
}

///|
test "Qwen K1024 stripe overlaps row bursts with a stalled DDR first beat" {
  let timings : Array[Int32] = []
  // The deployed crossbar has eight credits. The deeper model checks that a
  // less restrictive slave can accept the entire sixteen-row request.
  for (streaming, credits) in [(false, 8), (true, 8), (true, 16)] {
    let b = bench(streaming~, latency=16, read_credits=credits)
    let start = b.cycle
    b.begin(0x1fff80UL, line=true, burst=true, wide=true, data=[
      0x80000800UL, 0UL, 0UL, 0UL,
    ])
    let replies = b.finish(hold=0)
    assert_eq(replies.length(), 64)
    for i, (words, fault, last) in replies {
      assert_eq(fault, 0UL)
      assert_eq(last, if i == 63 { 1UL } else { 0UL })
      for j, word in words {
        assert_eq(
          word,
          b.word(
            0x1fff80UL +
            (i / 4).to_uint64() * 2048UL +
            (i % 4 * 32 + j * 4).to_uint64(),
          ),
        )
      }
    }
    assert_eq(b.reads.length(), if streaming { 16 } else { 128 })
    if streaming {
      assert_eq(b.peak_outstanding, credits)
    }
    timings.push(b.cycle - start)
    println(
      "K1024 stripe streaming=\{streaming} credits=\{credits} bytes=2048 cycles=\{b.cycle-start} AR=\{b.reads.length()} max_outstanding=\{b.peak_outstanding}",
    )
  }
  assert_true(timings[1] * 8 < timings[0])
}

///|
fn exercise_poisoned_stripe(deep : Bool) -> Unit raise {
  for mode in 0..<3 {
    let b = bench(
      streaming=true,
      latency=10,
      wide512=deep,
      wide1024=deep,
      deep_batch=deep,
    )
    b.begin(
      if deep {
        0x7fff8000UL
      } else {
        0x7ffff800UL
      },
      line=true,
      burst=true,
      wide=true,
      data=[if deep { 0xe0000200UL } else { 0x80000080UL }, 0UL, 0UL, 0UL],
    )
    for _ in 0..<100 {
      b.step()
      if value(b.sim, "response_valid") == 1UL {
        break
      }
    }
    assert_eq(value(b.sim, "response_valid"), 1UL)
    if mode == 0 {
      b.read_fault = 2UL
    } else if mode == 1 {
      b.bad_last = true
    } else {
      set(b.sim, "calibrated", 1, 0UL)
    }
    let replies = b.finish(hold=2)
    assert_eq(replies.length(), if deep { 256 } else { 64 })
    assert_eq(replies[0].1, 0UL)
    for (_, fault, _) in replies[1:] {
      assert_eq(fault, if mode == 2 { 2UL } else { 3UL })
    }
    assert_eq(value(b.sim, "bridge_poisoned"), 1UL)
    b.reset()
    b.begin(0x24UL)
    assert_eq(b.finish()[0].0[0], b.word(0x24UL))
  }
}

///|
test "stream errors drain the owned stripe, preserve a stalled packet and require reset" {
  exercise_poisoned_stripe(false)
}

///|
test "32 KiB group handles AXI errors early RLAST and calibration loss under backpressure" {
  exercise_poisoned_stripe(true)
}
