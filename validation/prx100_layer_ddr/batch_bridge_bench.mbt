///|
fn batch_bridge_replay(b : BridgeBench) -> Unit raise {
  let original = b.memory.map(a => a.copy())
  for line in 0..<b.memory.length() {
    for word in 0..<4 {
      b.memory[line][word] = 0x90000000U +
        (line * 4 + word).reinterpret_as_uint()
    }
  }
  for prefix in [0, 1, 7, 8, 9, 16, 31, 32] {
    set(b.sim, "request_wide", 1, 1UL)
    set(b.sim, "request_data", 32, 0x80000100UL)
    b.begin_line(0UL, burst=true, header=0x80000100UL)
    set(b.sim, "request_wide", 1, 0UL)
    set(b.sim, "request_data", 32, 0UL)
    for i in 0..<prefix {
      let base = (i / 8 * 64 + i % 8 * 4).to_uint64()
      assert_eq(wide_packet(b, i % 9), [
        0x90000000UL + base,
        0x90000001UL + base,
        0x90000002UL + base,
        0x90000003UL + base,
        0UL,
        if i == 31 {
          1UL
        } else {
          0UL
        },
      ])
    }
    b.reset()
    assert_eq(b.transaction(1020UL), (0x900000ffUL, 0UL))
  }
  // Illegal stride, reserved bits and complete-extent overflow are refused
  // before any native access, yet drain the full four-row response shape.
  for
    (address, header) in [
      (0UL, 0x80000000UL),
      (0UL, 0x80000084UL),
      (0UL, 0x90000100UL),
      (0xfffff80UL, 0x80000080UL),
    ] {
    let before = b.reads.length()
    set(b.sim, "request_wide", 1, 1UL)
    set(b.sim, "request_data", 32, header)
    b.begin_line(address, burst=true, header~)
    for i in 0..<32 {
      assert_eq(wide_packet(b, 1), [
        0UL,
        0UL,
        0UL,
        0UL,
        1UL,
        if i == 31 {
          1UL
        } else {
          0UL
        },
      ])
    }
    assert_eq(b.reads.length(), before)
  }
  b.reset()
  set(b.sim, "request_wide", 1, 1UL)
  set(b.sim, "request_data", 32, 0x80000100UL)
  b.begin_line(0UL, burst=true, header=0x80000100UL)
  for _ in 0..<9 {
    ignore(wide_packet(b, 1))
  }
  b.environment(bad_end=true)
  let mut failed = false
  for i in 9..<32 {
    let packet = wide_packet(b, 2)
    if packet[4] != 0UL {
      failed = true
    }
    assert_eq(packet[5], if i == 31 { 1UL } else { 0UL })
  }
  assert_true(failed)
  b.environment()
  b.reset()
  set(b.sim, "request_wide", 1, 0UL)
  set(b.sim, "request_data", 32, 0UL)
  for i, words in original {
    for j, word in words {
      b.memory[i][j] = word
    }
  }
}
