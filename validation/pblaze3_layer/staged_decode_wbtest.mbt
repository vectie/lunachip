///|
test "pipelined descriptor validation rejects the current shape and final reserved word" {
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
  )
  exercise_staged_decode(b)
  // A full-width invalid encoding with LOAD in its low nibble cannot issue.
  b.upload(
    [
      ..row(1U, 64U, 0U, 1U),
      ..row(0x1000000eU, 128U, 0U, 1U, ddr=0x40000000U),
      ..row(0U, 0U, 0U, 0U),
    ],
  )
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
}
