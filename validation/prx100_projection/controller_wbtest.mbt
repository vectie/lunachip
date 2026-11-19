///|
test "autonomous DDR staging, alternating slots and signed accumulation against CPU" {
  let b = bench()
  let (a, w, partials, sums) = fixture(2, 3)
  store_codes(b, 0x100000U, w)
  store_codes(b, 0x200000U, a)
  b.configure(2)
  assert_eq(b.write(16UL, 1UL), 0UL)
  b.finish_job(2, partials, sums)
  assert_eq(b.read(160UL), 136UL)
  assert_eq(b.read(164UL), 16UL)
  assert_eq(b.read(168UL), 0UL)
  assert_eq(b.read(172UL), 136UL)
  // DDR weights and activations persist; START resets the idle core and sums.
  assert_eq(b.write(16UL, 1UL), 0UL)
  b.finish_job(2, partials, sums)
  assert_eq(b.read(160UL), 136UL) // START clears the previous job's requests.
}

///|
test "next descriptors publish after consumer release; alternating operands and results match CPU" {
  let b = bench()
  let (a, w, partials, sums) = fixture(4, 19)
  store_codes(b, 0x100000U, w)
  store_codes(b, 0x200000U, a)
  b.configure(4)
  for round in 0..<2 {
    b.descriptor_writes.clear()
    b.publications.clear()
    b.collection_requests.clear()
    assert_eq(b.write(16UL, 1UL), 0UL)
    b.finish_job(4, partials, sums)
    assert_eq(b.descriptor_writes.length(), 32 + 3 * 12)
    for i in 0..<32 {
      let (address, _) = b.descriptor_writes[i]
      assert_eq(address, i.to_uint64())
    }
    for tile in 1..<4 {
      for op in 0..<4 {
        let offset = 32 + (tile - 1) * 12 + op * 3
        let (id_address, id) = b.descriptor_writes[offset]
        let (base_address, base) = b.descriptor_writes[offset + 1]
        let (slot_address, slots) = b.descriptor_writes[offset + 2]
        assert_eq(id_address, (op * 8 + 1).to_uint64())
        assert_eq(slot_address, (op * 8 + 6).to_uint64())
        assert_eq(base_address, (op * 8 + 4).to_uint64())
        assert_eq(
          base,
          match op {
            0 => 256UL + (tile % 2).to_uint64() * 2048UL
            1 => 512UL + (tile % 2).to_uint64() * 2048UL
            2 => 0UL
            _ => 1024UL + (tile % 2).to_uint64() * 2048UL
          },
        )
        assert_eq(id, (tile * 4 + op + 1).to_uint64())
        assert_eq(
          slots,
          (tile % 2).to_uint64() * [1UL, 256UL, 65793UL, 65536UL][op],
        )
      }
    }
    assert_eq(b.overlapped_reads.length(), 3 * 2 * (round + 1))
    assert_true(b.simultaneous_reads.length() > 0)
    assert_eq(b.publications.length(), 4)
    for tile in 0..<4 {
      let (producer, retired, collected) = b.publications[tile]
      assert_eq(producer, ((tile + 1) * 4).to_uint64())
      if tile > 0 {
        // Word reads can finish the current four commands before independent
        // DDR prefetch is ready. Publication still precedes their collection,
        // and may never imply a retirement beyond this tile's four commands.
        assert_true(retired <= (tile * 4).to_uint64())
        assert_eq(collected, ((tile - 1) * 8).to_uint64())
      }
    }
    assert_true(b.collection_requests.length() > 0)
  }
}

///|
test "AXI DDR portal endian, full bounds, channel ordering and held responses" {
  let b = bench()
  assert_eq(b.read(0UL), 0x50524433UL)
  for
    (address, data) in [
      (0x10000000UL, 0x89abcdefUL),
      (0x1ffffffcUL, 0x01234567UL),
    ] {
    assert_eq(b.write(address, data, data_first=true, hold=7), 0UL)
    assert_eq(b.read(address, hold=11), data)
    assert_eq(b.memory[(address - 0x10000000UL).to_uint()], data.to_uint())
  }
  for address in [1UL, 0x10000001UL, 0x20000000UL, 0xfffffffcUL] {
    assert_eq(b.write(address, 77UL), 2UL)
    assert_eq(b.read(address, response=2UL), 0UL)
  }
  assert_eq(b.write(0x10000000UL, 1UL, strobe=3UL), 2UL)
  assert_eq(b.read(0x10000000UL), 0x89abcdefUL)
  for
    (address, data) in [
      (16UL, 1UL),
      (20UL, 1UL),
      (24UL, 0x10000000UL),
      (36UL, 0UL),
      (36UL, 65UL),
      (16UL, 2UL),
    ] {
    assert_eq(b.write(address, data), 2UL)
  }
  b.configure(1)
  assert_eq(b.write(24UL, 0x100000UL), 0UL)
  assert_eq(b.write(16UL, 1UL), 2UL) // aliased buffer regions
}

///|
test "busy ownership forbids host mutation and holds DDR request through stalls" {
  let b = bench()
  let (a, w, p, s) = fixture(1, 5)
  store_codes(b, 0x100000U, w)
  store_codes(b, 0x200000U, a)
  b.configure(1)
  b.environment(stalled=true)
  assert_eq(b.write(16UL, 1UL), 0UL)
  for _ in 0..<45 {
    b.step()
  }
  assert_eq(value(b.sim, "ddr_request_valid"), 1UL)
  let address = value(b.sim, "ddr_request_address")
  for _ in 0..<10 {
    b.step()
    assert_eq(value(b.sim, "ddr_request_address"), address)
  }
  assert_eq(b.write(20UL, 0x500000UL), 2UL)
  assert_eq(b.write(16UL, 1UL), 2UL)
  assert_eq(b.write(0x10100000UL, 1UL), 2UL)
  assert_eq(b.read(0x10100000UL, response=2UL), 0UL)
  b.environment()
  b.finish_job(1, p, s)
}

///|
test "DDR faults, calibration loss and bounded watchdog fail closed" {
  let b = bench()
  b.configure(1)
  b.environment(fault=1UL)
  assert_eq(b.write(16UL, 1UL), 0UL)
  for _ in 0..<100 {
    b.step()
  }
  assert_eq(b.read(12UL), 3UL)
  assert_eq(b.read(44UL), 0UL)
  assert_eq(b.write(16UL, 1UL), 2UL)
  let b = bench()
  b.configure(1)
  b.environment(stalled=true)
  assert_eq(b.write(16UL, 1UL), 0UL)
  b.environment(healthy=false, stalled=true)
  for _ in 0..<3 {
    b.step()
  }
  assert_eq(b.read(12UL), 2UL)
  let b = bench(watchdog=40UL)
  b.configure(1)
  b.environment(stalled=true)
  assert_eq(b.write(16UL, 1UL), 0UL)
  for _ in 0..<60 {
    b.step()
  }
  assert_eq(b.read(12UL), 6UL)
}

///|
test "physical reset flushes the interrupted job and preserves DRAM for fresh work" {
  let b = bench()
  let (a, w, p, s) = fixture(1, 7)
  store_codes(b, 0x100000U, w)
  store_codes(b, 0x200000U, a)
  b.configure(1)
  assert_eq(b.write(16UL, 1UL), 0UL)
  for _ in 0..<100 {
    b.step()
  }
  b.set("reset", 1, 1UL)
  b.pending = None
  b.step()
  b.step()
  b.set("reset", 1, 0UL)
  b.step()
  assert_eq(b.read(8UL), 1UL)
  assert_eq(b.read(44UL), 0UL)
  b.configure(1)
  assert_eq(b.write(16UL, 1UL), 0UL)
  b.finish_job(1, p, s)
}
