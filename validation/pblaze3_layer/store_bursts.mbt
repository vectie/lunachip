///|
// Prefix, two full bursts on adjacent 4 KiB pages, and a two-word tail.
// Include a tied maximum on opposite beats and distinctive raw FP32 bits.
fn exercise_store_bursts(b : Bench) -> Unit raise {
  b.reset()
  let base = 0x6ffffefcUL
  let words = Array::makei(131, i => {
    if i == 31 || i == 96 {
      0x40800000UL
    } else {
      0x3f000000UL + i.to_uint64()
    }
  })
  for i, word in words {
    b.write(0x40000UL + 4UL * (5 + i).to_uint64(), word)
  }
  let before = b.word(base - 4UL)
  let after = b.word(base + 524UL)
  b.upload(
    [..row(15U, 0U, 5U, 131U, ddr=base.to_uint()), ..row(0U, 0U, 0U, 0U)],
  )
  b.write(0x44UL, 131UL)
  b.write(0x48UL, base)
  let writes = b.writes
  let bursts = b.burst_writes
  b.write(0x10UL, 1UL)
  b.complete()
  assert_eq(b.writes - writes, 5)
  assert_eq(b.burst_writes - bursts, 2)
  assert_eq(b.read(0x34UL), 131UL)
  assert_eq(b.read(0x4cUL), 31UL)
  for i, word in words {
    assert_eq(b.word(base + 4UL * i.to_uint64()), word)
  }
  assert_eq(b.word(base - 4UL), before)
  assert_eq(b.word(base + 524UL), after)
  // A failed B must not publish any part of the group to an armed argmax.
  // Its interval covers only one word in the second beat.
  let high = 0x7fffff00UL
  b.upload([..row(15U, 0U, 5U, 64U, ddr=high.to_uint()), ..row(0U, 0U, 0U, 0U)])
  b.write(0x44UL, 1UL)
  b.write(0x48UL, high + 128UL)
  b.write_fault = 2UL
  b.write(0x10UL, 1UL)
  for _ in 0..<230 {
    b.step()
  }
  assert_eq(b.read(8UL) & 8UL, 8UL)
  assert_eq(b.read(0x4cUL), 0xffffffffUL)
  b.reset()
  b.write(0x14UL, 2UL)
  b.write(0x44UL, 1UL)
  b.write(0x48UL, high + 128UL)
  b.write(0x10UL, 1UL)
  b.complete()
  assert_eq(b.read(0x4cUL), 0UL)
  for i in 0..<64 {
    assert_eq(b.word(high + 4UL * i.to_uint64()), words[i])
  }
}
