///|
test "long reciprocal and exponential retire an element per edge after filling the pipeline" {
  let b = bench(
    streaming=true,
    profile=true,
    vectors=true,
    wide512=true,
    rows64=true,
    banked64=true,
    prefetch256=true,
    scalar_lines=true,
    store_bursts=true,
    chain=true,
    program_bursts=true,
    stream_unary=true,
  )
  b.reset()
  for i in 0..<80 {
    b.write(0x40000UL + 4UL * i.to_uint64(), 0x3f800000UL)
  }
  for op in [9U, 11U] {
    let cycles : Array[UInt64] = []
    for (count, mode) in [(64U, 1UL), (64U, 0UL), (80U, 0UL)] {
      b.write(0x264UL, mode)
      b.upload([..row(op, 128U, 0U, count), ..row(0U, 0U, 0U, 0U)])
      b.write(0x10UL, 1UL)
      b.complete(polls=2000)
      cycles.push(b.read(0x24UL))
    }
    assert_true(cycles[1] * 2UL < cycles[0])
    assert_eq(cycles[2] - cycles[1], 16UL)
  }
}
