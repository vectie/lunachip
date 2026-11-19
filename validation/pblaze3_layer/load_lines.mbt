///|
// Two full lines cross a 4 KiB boundary after a one-word prefix. The two
// tail words precede a canary; distinct raw bits catch reversed byte lanes.
fn exercise_load_lines(b : Bench) -> Unit raise {
  b.reset()
  let base = 0x6fffff7cUL
  for i in 0..<67 {
    b.memory[base + 4UL * i.to_uint64()] = 0x80000000UL + 797UL * i.to_uint64()
  }
  b.upload([..row(14U, 5U, 0U, 67U, ddr=base.to_uint()), ..row(0U, 0U, 0U, 0U)])
  b.write(0x40000UL + 4UL * 72UL, 0xfeedfaceUL)
  let reads = b.reads
  b.write(0x10UL, 1UL)
  b.complete()
  assert_eq(b.reads - reads, 5)
  assert_eq(b.read(0x34UL), 67UL)
  for i in 0..<67 {
    assert_eq(
      b.read(0x40000UL + 4UL * (5 + i).to_uint64()),
      b.memory[base + 4UL * i.to_uint64()],
    )
  }
  assert_eq(b.read(0x40000UL + 4UL * 72UL), 0xfeedfaceUL)
  // The final aligned transaction in the aperture ends exactly at 2 GiB.
  for i in 0..<32 {
    b.memory[0x7fffff80UL + 4UL * i.to_uint64()] = 0x55aa0000UL + i.to_uint64()
  }
  b.upload([..row(14U, 0U, 0U, 32U, ddr=0x7fffff80U), ..row(0U, 0U, 0U, 0U)])
  b.write(0x10UL, 1UL)
  b.complete()
  assert_eq(b.read(0x4007cUL), 0x55aa001fUL)
}
