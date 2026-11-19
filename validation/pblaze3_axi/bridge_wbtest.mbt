///|
test "AXI scalar masks line burst and sixteen-row delivery cover high2GiB addresses" {
  exercise(bench())
}

///|
test "AXI AW and W channels complete independently under stalls" {
  let b = bench()
  for first_address in [true, false] {
    b.aw_pause = !first_address
    b.w_pause = first_address
    b.begin(0x4000000cUL, write=true, data=[0x76543210UL, 0UL, 0UL, 0UL])
    for _ in 0..<20 {
      b.step()
    }
    assert_eq(value(b.sim, "response_valid"), 0UL)
    assert_eq(
      value(b.sim, if first_address { "m_axi_awvalid" } else { "m_axi_wvalid" }),
      0UL,
    )
    assert_eq(
      value(b.sim, if first_address { "m_axi_wvalid" } else { "m_axi_awvalid" }),
      1UL,
    )
    b.aw_pause = false
    b.w_pause = false
    assert_eq(b.finish()[0].1, 0UL)
    assert_eq(b.word(0x4000000cUL), 0x76543210UL)
    assert_eq(b.word(0x40000008UL), (0x40000008UL / 4UL) ^ 0x5a37c019UL)
  }
}

///|
test "AXI rejects misaligned shapes overflowing2GiB extents before bus traffic" {
  let b = bench()
  for
    (address, line, burst, wide, data, count) in [
      (1UL, false, false, false, 0UL, 1),
      (0x80000000UL, false, false, false, 0UL, 1),
      (0xfffffff0UL, true, false, false, 0UL, 4),
      (4UL, true, false, false, 0UL, 4),
      (16UL, true, true, true, 0UL, 4),
      (0UL, false, true, false, 0UL, 1),
      (0UL, false, false, true, 0UL, 1),
      (0UL, true, true, true, 0x80000000UL, 64),
      (0UL, true, true, true, 0x80000081UL, 64),
      (0x7ffff880UL, true, true, true, 0x80000080UL, 64),
      (0UL, true, true, true, 0xffff0000UL, 64),
    ] {
    let before = b.reads.length()
    b.begin(address, line~, burst~, wide~, data=[data, 0UL, 0UL, 0UL])
    let result = b.finish(hold=0)
    assert_eq(result.length(), count)
    for (words, fault, _) in result {
      assert_eq(fault, 1UL)
      assert_eq(words, [0UL, 0UL, 0UL, 0UL, 0UL, 0UL, 0UL, 0UL])
    }
    assert_eq(b.reads.length(), before)
  }
}

///|
test "coordinated reset discards partial AW W read and held response ownership" {
  let b = bench()
  for first_address in [true, false] {
    b.aw_pause = !first_address
    b.w_pause = first_address
    b.begin(0x40000000UL, write=true, data=[0x12121212UL, 0UL, 0UL, 0UL])
    for _ in 0..<20 {
      b.step()
    }
    b.reset()
    b.aw_pause = false
    b.w_pause = false
    for _ in 0..<20 {
      b.step()
    }
    assert_eq(value(b.sim, "response_valid"), 0UL)
    b.begin(0x40000000UL)
    assert_eq(b.finish()[0].0[0], (0x40000000UL / 4UL) ^ 0x5a37c019UL)
  }
  b.begin(0UL)
  for _ in 0..<100 {
    if !b.rd.is_empty() {
      break
    }
    b.step()
  }
  assert_false(b.rd.is_empty())
  b.reset()
  for _ in 0..<20 {
    b.step()
  }
  assert_eq(value(b.sim, "response_valid"), 0UL)
  b.begin(0x7fffff80UL, line=true, burst=true, wide=true)
  for _ in 0..<100 {
    if value(b.sim, "response_valid") == 1UL {
      break
    }
    b.step()
  }
  assert_eq(value(b.sim, "response_valid"), 1UL)
  b.reset()
  assert_eq(value(b.sim, "response_valid"), 0UL)
  b.begin(0x7ffffffcUL)
  assert_eq(b.finish()[0].0[0], (0x7ffffffcUL / 4UL) ^ 0x5a37c019UL)
}

///|
test "AXI response failures drain shaped zero responses and require coordinated reset" {
  let b = bench()
  for (response, bad_last) in [(2UL, false), (3UL, false), (0UL, true)] {
    b.read_fault = response
    b.bad_last = bad_last
    b.begin(0UL, line=true, burst=true, wide=true, data=[
      0x80000080UL, 0UL, 0UL, 0UL,
    ])
    let result = b.finish(hold=2)
    assert_eq(result.length(), 64)
    for (words, fault, _) in result {
      assert_eq(fault, 3UL)
      assert_eq(words[0], 0UL)
    }
    assert_eq(value(b.sim, "bridge_poisoned"), 1UL)
    b.begin(0UL)
    assert_eq(b.finish()[0].1, 2UL)
    b.reset()
  }
  b.write_fault = 2UL
  b.begin(0UL, write=true)
  assert_eq(b.finish()[0].1, 3UL)
  assert_eq(value(b.sim, "bridge_poisoned"), 1UL)
  b.reset()
  b.begin(0UL)
  assert_eq(b.finish()[0].1, 0UL)
}

///|
test "calibration loss preserves pending AXI valid and held successful response" {
  let b = bench()
  b.ar_pause = true
  b.begin(0UL)
  b.step()
  set(b.sim, "calibrated", 1, 0UL)
  for _ in 0..<10 {
    b.step()
  }
  assert_eq(value(b.sim, "m_axi_arvalid"), 1UL)
  b.ar_pause = false
  assert_eq(b.finish()[0].1, 2UL)
  b.reset()
  b.begin(0UL, line=true)
  for _ in 0..<100 {
    if value(b.sim, "response_valid") == 1UL {
      break
    }
    b.step()
  }
  set(b.sim, "calibrated", 1, 0UL)
  for _ in 0..<10 {
    b.step()
  }
  assert_eq(value(b.sim, "response_fault"), 0UL)
  let result = b.finish()
  assert_eq(result[0].1, 0UL)
  assert_eq(result[1].1, 2UL)
  b.reset()
}
