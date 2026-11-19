///|
test "full MAC product preserves ordered rounding exceptions bubbles and reset" {
  let reference = @sim.Simulator::prepare(@qwen_layer.ordered_bf16_mac_lane())
  let candidate = @sim.Simulator::prepare(
    @qwen_layer.ordered_bf16_mac_lane(full_product=true),
  )
  let cases = [
    0U, 0x80000000U, 1U, 3U, 0x007fffffU, 0x00800000U, 0x3f7e03f8U, 0x3f800000U,
    0xbf800000U, 0x4b800000U, 0xcb800000U, 0x7f7fffffU, 0xff7fffffU, 0x7f800000U,
    0xff800000U, 0x7fc00000U, 0x7f800001U,
  ]
  let mut seed = 9U
  for edge in 0..<4096 {
    seed = seed * 1664525U + 1013904223U
    let a = if edge < 1156 { cases[edge % cases.length()] } else { seed }
    seed = seed * 1664525U + 1013904223U
    let w = if edge < 1156 {
      cases[edge / cases.length() % cases.length()] >> 16
    } else {
      seed >> 16
    }
    let reset = edge == 0 || edge % 257 == 0
    for sim in [reference, candidate] {
      for
        (name, width, value) in [
          ("clock", 1, 0UL),
          ("reset", 1, if reset { 1UL } else { 0UL }),
          ("valid", 1, if edge % 7 == 0 { 0UL } else { 1UL }),
          ("first", 1, if edge / 18 % 5 == 0 { 1UL } else { 0UL }),
          ("activation", 32, a.to_uint64()),
          ("weight", 16, w.to_uint64()),
        ] {
        sim.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
      }
      sim.rising_edge("clock")
    }
    assert_eq(
      candidate.output("result_valid"),
      reference.output("result_valid"),
    )
    if reference.output("result_valid").value_bits() == 1UL {
      assert_eq(
        candidate.output("result"),
        reference.output("result"),
        msg="edge \{edge}",
      )
    }
  }
}
