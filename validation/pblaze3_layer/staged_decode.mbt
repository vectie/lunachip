///|
// A legal operation immediately precedes each malformed descriptor. This
// catches validation accidentally retained from the preceding instruction,
// including reserved word 15 which arrives one edge before decode.
fn exercise_staged_decode(b : Bench) -> Unit raise {
  let reserved = row(14U, 128U, 0U, 1U, ddr=0x40000000U)
  reserved[15] = 1U
  let stride = row(5U, 128U, 0U, 2U, k=2U)
  stride[7] = 32768U
  for
    invalid in [
      reserved,
      stride,
      row(4U, 128U, 0U, 64U, k=64U, ddr=0x7fffff80U),
      row(4U, 128U, 0U, 64U, k=0x1000040U, ddr=0x40000000U),
    ] {
    b.reset()
    b.write(0x40000UL, 0x3f800000UL)
    b.write(0x40200UL, 0xdeadbeefUL)
    b.upload([..row(1U, 64U, 0U, 1U), ..invalid, ..row(0U, 0U, 0U, 0U)])
    b.write(0x10UL, 1UL)
    for _ in 0..<300 {
      b.step()
      if b.core.get("fault") == 1UL {
        break
      }
    }
    assert_eq(b.core.get("error"), 1UL)
    assert_eq(b.core.get("instructions"), 1UL)
    assert_eq(b.core.get("ddr_beats"), 0UL)
    b.reset()
    assert_eq(b.read(0x40100UL), 0x3f800000UL)
    assert_eq(b.read(0x40200UL), 0xdeadbeefUL)
  }
  b.reset()
}
