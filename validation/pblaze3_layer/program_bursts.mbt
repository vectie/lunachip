///|
/// Verify the entire held-beat lane order across 4 KiB and the partial
/// transactions at the exclusive 2 GiB boundary (independent AXI stalls).
fn exercise_program_bursts(b : Bench) -> Unit raise {
  for
    (base, count, scalar, single, batch) in [
      (0x70000e00UL, 130, 0, 1, 1),
      (0x7fffff40UL, 3, 16, 1, 0),
      (0x70000000UL, 2, 32, 0, 0),
    ] {
    b.reset()
    assert_eq(b.read(0x240UL), 0x50425231UL)
    assert_eq(b.read(0x244UL), 0UL)
    b.write(0x244UL, 2UL, response=2UL)
    if count == 2 {
      b.write(0x244UL, 1UL)
    }
    for i in 0..<(count * 16) {
      b.memory[base + i.to_uint64() * 4UL] = if i < 16 {
        0UL
      } else {
        0x32100000UL + i.to_uint64()
      }
    }
    b.write(0x3cUL, base)
    b.write(0x98UL, count.to_uint64())
    let before = b.reads
    b.write(0x10UL, 2UL)
    b.write(0x244UL, 1UL, response=2UL)
    b.complete(polls=1000)
    assert_eq(b.reads - before, scalar + single + 16 * batch)
    for
      i, value in [
        scalar,
        single,
        batch,
        count * 16,
        scalar + single + 64 * batch,
      ] {
      assert_eq(b.read(0x248UL + i.to_uint64() * 4UL), value.to_uint64())
    }
    for
      i in [
        0, 15, 16, 31, 32, 47, 60, 63, 64, 127, 511, 1023, 2015, 2047, 2048, 2079,
      ] {
      if i < count * 16 {
        assert_eq(
          b.read(0x20000UL + i.to_uint64() * 4UL),
          b.word(base + i.to_uint64() * 4UL),
        )
      }
    }
  }
  b.reset()
}
