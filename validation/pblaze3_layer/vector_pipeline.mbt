///|
// Exercise the routed wrapper interface with both eligible and dependent
// descriptors. The reference applies every scalar write in ISA order.
fn exercise_vector_pipeline(b : Bench) -> Unit raise {
  b.reset()
  let scratch = Array::makei(44, i => {
    Float::from_double((i - 20).to_double() / 8.0).reinterpret_as_uint()
  })
  scratch[1] = 0x80000000U
  scratch[2] = 1U
  scratch[3] = 0x7fc02198U
  for i, v in scratch {
    b.write(0x40000UL + 4UL * i.to_uint64(), v.to_uint64())
  }
  let program : Array[UInt32] = []
  let mut products = 0
  for
    (op, dst, a, src, n, flags) in [
      (2, 20, 0, 10, 7, 0),
      (3, 20, 20, 10, 7, 0),
      (12, 0, 20, 0, 7, 0),
      (13, 10, 0, 30, 7, 1),
      (1, 30, 10, 0, 7, 0),
      (2, 1, 0, 20, 7, 0),
      (3, 10, 20, 10, 7, 1),
      (2, 8, 8, 0, 3, 2),
      (13, 20, 20, 0, 7, 2),
      (3, 30, 30, 30, 7, 0),
    ] {
    let imm = 0xbf000000U
    let words = row(
      op.reinterpret_as_uint(),
      dst.reinterpret_as_uint(),
      a.reinterpret_as_uint(),
      n.reinterpret_as_uint(),
      immediate=imm,
      flags=flags.reinterpret_as_uint(),
    )
    words[3] = src.reinterpret_as_uint()
    for w in words {
      program.push(w)
    }
    for i in 0..<n {
      let left = scratch[a + i]
      let right = if flags == 2 {
        imm
      } else {
        scratch[src + (if flags == 0 { i } else { 0 })]
      }
      let av = Float::reinterpret_from_uint(left)
      let bv = Float::reinterpret_from_uint(right)
      scratch[dst + i] = if op == 1 {
        left
      } else if op == 12 {
        left | 0x80000000U
      } else {
        let result = if op == 2 {
          av + bv
        } else {
          av * (if op == 13 && left >> 31 == 0U { 1.0F } else { bv })
        }
        if result.is_nan() {
          0x7fc00000U
        } else {
          result.reinterpret_as_uint()
        }
      }
    }
    if op == 3 || op == 13 {
      products += n
    }
  }
  for w in row(0U, 0U, 0U, 0U) {
    program.push(w)
  }
  b.upload(program)
  b.write(0x10UL, 1UL)
  b.complete()
  assert_eq(b.read(0x30UL), products.to_uint64())
  for i, w in scratch {
    assert_eq(
      b.read(0x40000UL + 4UL * i.to_uint64()),
      w.to_uint64(),
      msg="scratch word " + i.to_string(),
    )
  }
}
