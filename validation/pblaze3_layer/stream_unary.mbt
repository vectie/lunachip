///|
// Exercise the real scratch RAM and compare every retired FP32 word on both
// schedules. The final invalid operand test checks precise prefix commit.
fn exercise_stream_unary(b : Bench) -> Unit raise {
  b.reset()
  assert_eq(b.read(0x260UL), 0x53465531UL)
  assert_eq(b.read(0x29cUL), 0UL)
  b.write(0x29cUL, 1UL)
  b.drive("memory_healthy", 0UL)
  for _ in 0..<5 {
    b.step()
  }
  b.drive("memory_healthy", 1UL)
  for _ in 0..<5 {
    b.step()
  }
  assert_eq(b.read(0x29cUL), 0UL)
  for
    (op, size, dst, fault) in [
      (11U, 65, 128U, false),
      (9U, 64, 0U, false),
      (11U, 63, 0U, false),
      (9U, 65, 1U, false),
      (11U, 65, 128U, true),
    ] {
    let reference : Array[UInt64] = []
    for mode in [1UL, 0UL] {
      b.reset()
      b.write(0x264UL, mode)
      for i in 0..<(size + 1) {
        let x = if op == 11U {
          if fault && i == 19 {
            0x7fc02468U
          } else {
            let edges = [
              0xff800000U, 0x7f800000U, 0xc2000000U, 0x42000000U, 0x42000001U, 1U,
            ]
            if i < edges.length() {
              edges[i]
            } else {
              Float::from_double((i - 25).to_double() / 7.0).reinterpret_as_uint()
            }
          }
        } else {
          Float::from_double(1.0 + i.to_double() / 11.0).reinterpret_as_uint()
        }
        b.write(0x40000UL + i.to_uint64() * 4UL, x.to_uint64())
        if dst == 128U {
          b.write(0x40200UL + i.to_uint64() * 4UL, 0xa5a5a5a5UL)
        }
      }
      b.upload(
        [..row(op, dst, 0U, size.reinterpret_as_uint()), ..row(0U, 0U, 0U, 0U)],
      )
      b.write(0x10UL, 1UL)
      if fault {
        for _ in 0..<1200 {
          b.step()
          if b.core.get("fault") == 1UL {
            break
          }
        }
        assert_eq(b.core.get("error"), 3UL)
        b.reset()
      } else {
        b.complete(polls=3000)
      }
      for i in 0..<size {
        let got = b.read(0x40000UL + (dst.to_uint64() + i.to_uint64()) * 4UL)
        if fault && i >= 19 {
          assert_eq(got, 0xa5a5a5a5UL)
        }
        if mode == 1UL {
          reference.push(got)
        } else {
          assert_eq(got, reference[i], msg="op=\{op} n=\{size} i=\{i}")
        }
      }
    }
  }
}
