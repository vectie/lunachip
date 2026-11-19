///|
test "dual scratch read keeps both copies coherent and issues one vector element per edge" {
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
    staged_decode=true,
    stream_reductions=true,
    paired_rows=true,
    full_rows=true,
    dual_read=true,
  )
  exercise_vector_pipeline(b)
  exercise_ordered_reductions(b, dual_read=true)
  let times = []
  for size in [16, 32] {
    b.reset()
    for i in 0..<size {
      b.write(0x40000UL + i.to_uint64() * 4UL, 0x3f800000UL)
      b.write(
        0x40100UL + i.to_uint64() * 4UL,
        Float::from_int(i).reinterpret_as_uint().to_uint64(),
      )
    }
    let add = row(2U, 128U, 0U, size.reinterpret_as_uint())
    add[3] = 64U
    // The second instruction reads through the mirror what the first wrote.
    let mul = row(3U, 0U, 128U, size.reinterpret_as_uint())
    mul[3] = 128U
    b.upload([..add, ..mul, ..row(0U, 0U, 0U, 0U)])
    b.write(0x10UL, 1UL)
    b.complete()
    times.push(b.read(0x24UL))
    for i in 0..<size {
      assert_eq(
        b.read(0x40000UL + i.to_uint64() * 4UL),
        Float::from_int((i + 1) * (i + 1)).reinterpret_as_uint().to_uint64(),
      )
    }
  }
  assert_eq(times[1] - times[0], 32UL)
}
