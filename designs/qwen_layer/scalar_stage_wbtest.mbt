///|
test "scalar pipelines match CPU FP32 bits and reset age" {
  check_scalar_pipeline_bits(false)
  check_scalar_pipeline_bits(true)
}

///|
fn check_scalar_pipeline_bits(stage_aligned : Bool) -> Unit raise {
  let b = @wire.ModuleBuilder::new("scalar_add_stage_proof")
  let d = b.rising_edge(b.input("clock", @wire.clock()))
  let rs = b.input("reset", @wire.reset())
  b.input_timing(rs, SampledIn(d.id()))
  let reset = b.synchronous_reset(rs, 0UL)
  let a = b.input("a", @wire.uint(32))
  let c = b.input("b", @wire.uint(32))
  for x in [a, c] {
    b.input_timing(x, SampledIn(d.id()))
  }
  let value = b.register_in(
    d,
    add(
      b,
      a,
      c,
      fast=true,
      bounded=true,
      stage_aligned~,
      stage_normalized=true,
      pipeline=Some((d, reset)),
    ),
    reset~,
  )
  let out = b.output("result", @wire.uint(32))
  b.output_timing(out, ProducedIn(d.id()))
  b.connect(out, value)
  let s = @sim.Simulator::prepare(b.finish())
  fn set(name : String, width : Int32, value : UInt64) -> Unit raise {
    s.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
  }
  set("clock", 1, 0UL)
  let edge = [
    0U, 0x80000000U, 1U, 0x7fffffU, 0x800000U, 0x3f800000U, 0xbf800000U, 0x3f800001U,
    0x33800000U, 0x7f7fffffU, 0xff7fffffU, 0x7f800000U, 0xff800000U, 0x7fc00000U,
    0x7f800001U,
  ]
  let age = if stage_aligned { 3 } else { 2 }
  let expected : Array[UInt32] = Array::make(age, 0U)
  let mut seed = 0xf82a103dU
  for i in 0..<10000 {
    seed = seed * 1664525U + 1013904223U
    let a = if i < edge.length() * edge.length() {
      edge[i / edge.length()]
    } else {
      seed
    }
    seed = seed * 1664525U + 1013904223U
    let c = if i < edge.length() * edge.length() {
      edge[i % edge.length()]
    } else {
      seed
    }
    let sum = Float::reinterpret_from_uint(a) + Float::reinterpret_from_uint(c)
    let reset = i == 0 || (i > 256 && i % 97 == 0)
    set("reset", 1, if reset { 1UL } else { 0UL })
    set("a", 32, a.to_uint64())
    set("b", 32, c.to_uint64())
    let want = if reset {
      expected.clear()
      for _ in 0..<age {
        expected.push(0U)
      }
      0U
    } else {
      expected.push(
        if sum.is_nan() {
          0x7fc00000U
        } else {
          sum.reinterpret_as_uint()
        },
      )
      expected.remove(0)
    }
    s.rising_edge("clock")
    let actual = s.output("result")
    assert_true(actual.is_fully_known())
    assert_eq(
      actual.value_bits().to_uint(),
      want,
      msg="aligned=\{stage_aligned} edge=\{i} a=\{a} b=\{c}",
    )
  }
}
