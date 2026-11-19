///|
fn reference_word(
  index : Int32,
  lane : Int32,
  mode : Int32,
  seed : UInt32,
) -> UInt32 {
  let salts = [0x13579bdfU, 0x2468ace0U, 0x9e3779b9U, 0x5a5aa5a5U]
  let mut x = (index.reinterpret_as_uint() * 16U) ^ seed ^ salts[lane]
  x = x ^ (x << 13)
  x = x ^ (x >> 17)
  x = x ^ (x << 5)
  match mode {
    0 => 0U
    1 => 0xffffffffU
    2 => 0xaaaaaaaaU
    3 => 0x55555555U
    5 => x.lnot()
    6 => x & 0x00ff00ffU
    _ => x
  }
}

///|
test "standalone DDR all patterns, independent full beat oracle and reverse reads" {
  let b = bench(64)
  for mode in 0..<6 {
    b.run(
      mode.to_uint64(),
      0x1072026UL,
      64,
      command=if mode % 2 == 0 { 1UL } else { 9UL },
    )
    for index, words in b.memory {
      for lane, word in words {
        assert_eq(word, reference_word(index, lane, mode, 0x1072026U))
      }
    }
    assert_true(b.value("test_write_cycles") > 0UL)
    assert_true(b.value("test_read_cycles") > 0UL)
  }
  b.run(0UL, 0x12345678UL, 64)
  b.run(6UL, 0x12345678UL, 64)
  for index, words in b.memory {
    for lane, word in words {
      assert_eq(word, reference_word(index, lane, 6, 0x12345678U))
    }
  }
  b.run(7UL, 0x12345678UL, 64, command=9UL)
  for index, words in b.memory {
    for lane, word in words {
      assert_eq(word, reference_word(index, lane, 7, 0x12345678U))
    }
  }
  b.run(7UL, 0x12345678UL, 64, command=11UL)
  b.run(4UL, 0x11122233UL, 1, command=5UL)
  b.run(4UL, 0x11122233UL, 1, command=3UL)
}

///|
test "DDR AXI independent AW/W order, bounds, partial writes and held responses" {
  let b = bench(32)
  assert_eq(b.get(0UL), 0x44445233UL)
  assert_eq(b.get(4UL), 0x10000UL)
  assert_eq(b.get(100UL), 100000000UL)
  assert_eq(b.get(104UL), 16UL)
  assert_eq(b.write(20UL, 0xdeadbeefUL, data_first=true), 0UL)
  assert_eq(b.get(20UL), 0xdeadbeefUL)
  assert_eq(b.write(20UL, 1UL, strobe=3UL), 2UL)
  assert_eq(b.get(20UL), 0xdeadbeefUL)
  for address in [1UL, 112UL, 0x10000014UL, 0xfffffffCUL] {
    assert_eq(b.write(address, 7UL), 2UL)
    assert_eq(b.get(address, response=2UL), 0UL)
  }
  for
    (address, data) in [
      (24UL, 0UL),
      (24UL, 16777217UL),
      (28UL, 8UL),
      (16UL, 7UL),
    ] {
    assert_eq(b.write(address, data), 2UL)
  }
  b.stalled = true
  b.start_test(4UL, 0x11223344UL, 32)
  assert_eq(b.write(20UL, 2UL), 2UL)
  assert_eq(b.write(16UL, 1UL), 2UL)
  let address = b.value("app_addr")
  let data = b.value("app_wdf_word3")
  for _ in 0..<20 {
    b.step()
    assert_eq(b.value("app_addr"), address)
    assert_eq(b.value("app_wdf_word3"), data)
  }
  assert_eq(b.value("test_writes"), 0UL)
  b.stalled = false
  for _ in 0..<1000 {
    b.step()
    if b.value("test_state") == 3UL {
      break
    }
  }
  assert_eq(b.value("test_state"), 3UL)
  assert_eq(b.value("test_mismatches"), 0UL)
}

///|
test "DDR tester detects upper-lane bit corruption and aliased addresses" {
  let b = bench(64)
  b.corrupt_lane = 3
  b.start_test(4UL, 0x56565656UL, 64)
  for _ in 0..<2000 {
    b.step()
    if b.value("test_state") >= 3UL {
      break
    }
  }
  assert_eq(b.value("test_state"), 3UL)
  assert_eq(b.value("test_mismatches"), 64UL)
  assert_eq(b.get(64UL), 0UL)
  let expected = reference_word(0, 3, 4, 0x56565656U)
  assert_eq(b.get(80UL), expected.to_uint64())
  assert_eq(b.get(96UL), (expected ^ 0x80000000U).to_uint64())
  let b = bench(64)
  b.alias_modulus = 16
  b.start_test(4UL, 7UL, 64)
  for _ in 0..<2000 {
    b.step()
    if b.value("test_state") >= 3UL {
      break
    }
  }
  assert_eq(b.value("test_mismatches"), 48UL)
  assert_eq(b.get(64UL), 0UL)
}

///|
test "DDR calibration loss, missing read-end, reset and deterministic exports" {
  let b = bench(32)
  b.stalled = true
  b.start_test(0UL, 0UL, 32)
  b.calibrated = false
  b.step()
  assert_eq(b.value("test_state"), 4UL)
  assert_eq(b.value("test_error"), 2UL)
  b.set("reset", 1, 1UL)
  b.step()
  b.step()
  b.set("reset", 1, 0UL)
  b.calibrated = true
  b.stalled = false
  b.step()
  b.run(4UL, 42UL, 32)
  let b = bench(32)
  b.bad_end = true
  b.start_test(1UL, 0UL, 32)
  for _ in 0..<1000 {
    b.step()
    if b.value("test_state") == 4UL {
      break
    }
  }
  assert_eq(b.value("test_state"), 4UL)
  assert_eq(b.value("test_error"), 3UL)
  let a = @ddr.export_bundle()
  assert_eq(a, @ddr.export_bundle())
}

///|
test "DDR replay export satisfies its strict emitted-name result protocol" {
  let bundle = generate_bundle()
  let expected = bundle[bundle.search_by(a => a.path == "expected.tsv").unwrap()].content
  let stimulus = bundle[bundle.search_by(a => a.path == "stimulus.tsv").unwrap()].content
  assert_false(expected.contains("\n\n"))
  assert_true(stimulus.has_prefix("cycle\tlc_i"))
  audit(expected, expected, 2078)
}
