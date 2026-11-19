///|
test "paired row contexts preserve ordered sums across row groups, stripes and short fallbacks" {
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
  )
  for rows in [16, 32, 64, 128] {
    exercise_wide_matrix(b, rows, cancellation=true)
  }
  exercise_wide_matrix(
    b,
    256,
    columns=512,
    base=0x40000e00UL,
    cancellation=true,
  )
}
