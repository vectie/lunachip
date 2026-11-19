///|
test "compact jam preserves every shift distance and every single-bit basis" {
  let b = @wire.ModuleBuilder::new("compact_jam_comparison")
  let x = b.input("x", @wire.uint(27))
  let amount = b.input("amount", @wire.uint(11))
  b.connect(b.output("old", @wire.uint(27)), jam(b, x, amount))
  b.connect(b.output("new", @wire.uint(27)), compact_jam27(b, x, amount))
  let s = @sim.Simulator::prepare(b.finish())
  let words = [0UL, 0x7ffffffUL, 0x5555555UL, 0x2aaaaaaUL]
  for i in 0..<27 {
    words.push(1UL << i)
  }
  for distance in 0..<2048 {
    s.set_input(
      "amount",
      @wave.LogicValue::from_uint64(width=11, value=distance.to_uint64()),
    )
    for word in words {
      s.set_input("x", @wave.LogicValue::from_uint64(width=27, value=word))
      s.settle()
      let expected = if distance >= 27 {
        if word == 0UL {
          0UL
        } else {
          1UL
        }
      } else {
        (word >> distance) |
        (if (word & ((1UL << distance) - 1UL)) != 0UL { 1UL } else { 0UL })
      }
      assert_eq(s.output("new"), s.output("old"))
      assert_eq(s.output("new").value_bits(), expected)
    }
  }
}

///|
test "compact FP32 packing and staged products preserve CPU rounded bits at explicit latencies" {
  check_compact_multiply(false)
  check_compact_multiply(true)
  check_compact_multiply(true, registered_inputs=true)
}

///|
fn check_compact_multiply(
  staged_product : Bool,
  registered_inputs~ : Bool = false,
) -> Unit raise {
  let old = @sim.Simulator::prepare(pipelined_multiplier(fast=true))
  let new = @sim.Simulator::prepare(
    pipelined_multiplier(
      fast=true,
      compact_pack=true,
      staged_product~,
      registered_inputs~,
    ),
  )
  let edges = [
    0U, 0x80000000U, 1U, 0x7fffffU, 0x800000U, 0x3f800000U, 0xbf800000U, 0x7f7fffffU,
    0x7f800000U, 0xff800000U, 0x7fc00000U, 0x7f800001U,
  ]
  let pending : Array[UInt32] = []
  let mut seed = 0x871a20d3U
  let extra = (if staged_product { 1 } else { 0 }) +
    (if registered_inputs { 1 } else { 0 })
  let history = Array::make(extra, 0UL)
  for i in 0..<10003 {
    seed = seed * 1664525U + 1013904223U
    let a = if i < edges.length() * edges.length() {
      edges[i / edges.length()]
    } else {
      seed
    }
    seed = seed * 1664525U + 1013904223U
    let c = if i < edges.length() * edges.length() {
      edges[i % edges.length()]
    } else {
      seed
    }
    let reset = i == 0 || i % 173 == 0
    if reset {
      pending.clear()
      for j in 0..<extra {
        history[j] = 0UL
      }
    }
    let product = Float::reinterpret_from_uint(a) *
      Float::reinterpret_from_uint(c)
    if !reset {
      pending.push(
        if product.is_nan() {
          0x7fc00000U
        } else {
          product.reinterpret_as_uint()
        },
      )
    }
    for sim in [old, new] {
      for
        (name, width, value) in [
          ("clock", 1, 0UL),
          ("reset", 1, if reset { 1UL } else { 0UL }),
          ("a", 32, a.to_uint64()),
          ("b", 32, c.to_uint64()),
        ] {
        sim.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
      }
      sim.rising_edge("clock")
    }
    assert_eq(
      new.output("result").value_bits(),
      if extra > 0 {
        let expected = history.remove(0)
        history.push(old.output("result").value_bits())
        expected
      } else {
        old.output("result").value_bits()
      },
    )
    if pending.length() > 2 + extra {
      assert_eq(new.output("result").value_bits().to_uint(), pending.remove(0))
    }
  }
}
