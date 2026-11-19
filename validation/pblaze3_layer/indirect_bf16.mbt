///|
fn exercise_indirect_bf16(b : Bench) -> Unit raise {
  let pointer = 0x40000004UL
  let source = 0x7fffff00UL
  let values = Array::makei(128, i => {
    if i < 8 {
      [0U, 0x8000U, 1U, 0x7f80U, 0xff80U, 0x7fc1U, 0xffc0U, 0x0080U][i]
    } else {
      (i.reinterpret_as_uint() * 631U + 13U) & 0xffffU
    }
  })
  for i in 0..<64 {
    b.memory[source + i.to_uint64() * 4UL] = (values[2 * i] |
    (values[2 * i + 1] << 16)).to_uint64()
  }
  for
    (address, count, error) in [
      (source, 128U, 0UL),
      (source + 4UL, 128U, 1UL),
      (0x7fffff80UL, 128U, 1UL),
      (0x80000000UL, 128U, 1UL),
      (source, 65U, 1UL),
    ] {
    b.reset()
    assert_eq(b.read(0x2a0UL), 0x42463136UL)
    b.memory[pointer] = address
    b.write(0x40400UL, 0xdeadbeefUL)
    b.upload(
      [
        ..row(14U, 256U, 0U, count, ddr=0x40000004U, flags=1U),
        ..row(0U, 0U, 0U, 0U),
      ],
    )
    let reads = b.reads
    b.write(0x10UL, 1UL)
    if error == 0UL {
      b.complete()
      assert_eq(b.reads - reads, 3)
      assert_eq(b.read(0x34UL), 65UL)
      for i, v in values {
        assert_eq(
          b.read(0x40400UL + i.to_uint64() * 4UL),
          (v << 16).to_uint64(),
        )
      }
    } else {
      for _ in 0..<180 {
        b.step()
        if b.core.get("fault") == 1UL {
          break
        }
      }
      assert_eq(b.core.get("error"), error)
      assert_eq(b.reads - reads, if count == 65U { 0 } else { 1 })
      b.reset()
      assert_eq(b.read(0x40400UL), 0xdeadbeefUL)
    }
  }
}
