///|
fn exercise_ordered_reductions(
  b : Bench,
  dual_read~ : Bool = false,
  bounded_add~ : Bool = false,
) -> Unit raise {
  b.reset()
  let xs = Array::makei(32, i => {
    [16777216.0F, 1.0F, -16777216.0F, -0.25F, 2.0F][i % 5]
  })
  let weights = Array::makei(128, i => Float::from_int(i % 9 - 4) / 4.0F)
  for i, x in xs {
    b.write(
      0x40000UL + 4UL * i.to_uint64(),
      x.reinterpret_as_uint().to_uint64(),
    )
  }
  for i, x in weights {
    b.write(
      0x41000UL + 4UL * i.to_uint64(),
      x.reinterpret_as_uint().to_uint64(),
    )
  }
  for op in [5U, 6U, 7U] {
    let times = []
    for n in [16, 32] {
      let dot = op == 5U
      let count = n.reinterpret_as_uint()
      let inst = if dot {
        let d = row(op, 512U, 0U, 2U, k=count)
        d[3] = 1024U
        d[6] = 2U
        d[7] = 64U
        d
      } else {
        row(op, 512U, 0U, count)
      }
      b.upload([..inst, ..row(0U, 0U, 0U, 0U)])
      b.write(0x10UL, 1UL)
      b.complete()
      times.push(b.read(0x24UL))
      let products = if dot { 2 * n } else if op == 7U { n } else { 0 }
      assert_eq(b.core.get("products"), products.to_uint64())
      for r in 0..<(if dot { 2 } else { 1 }) {
        let mut sum = 0.0F
        for i in 0..<n {
          let term = if dot {
            xs[i] * weights[r * 64 + 2 * i]
          } else if op == 7U {
            xs[i] * xs[i]
          } else {
            xs[i]
          }
          sum += term
        }
        assert_eq(
          b.read(0x40800UL + 4UL * r.to_uint64()),
          sum.reinterpret_as_uint().to_uint64(),
        )
      }
    }
    let expected = if bounded_add {
      if op == 5U {
        64UL
      } else {
        32UL
      }
    } else if op == 5U {
      if dual_read {
        32UL
      } else {
        64UL
      }
    } else {
      16UL
    }
    assert_eq(times[1] - times[0], expected)
  }
}
