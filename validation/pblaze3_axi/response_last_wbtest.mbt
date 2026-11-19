///|
test "predicted terminal response is edge-identical through stalls and faults" {
  for streaming in [false, true] {
    let b = bench(streaming~, compare_staged_response_last=true, latency=7)
    exercise(b)
    for
      (address, line, burst, wide, data) in [
        (0x80000000UL, false, false, false, 0UL),
        (4UL, true, false, false, 0UL),
        (0UL, true, true, true, 0x80000081UL),
        (0UL, true, true, true, 0x80000080UL),
      ] {
      b.begin(address, line~, burst~, wide~, data=[data, 0UL, 0UL, 0UL])
      ignore(b.finish(hold=5))
    }
    for (fault, bad_last) in [(2UL, false), (0UL, true)] {
      b.reset()
      b.read_fault = fault
      b.bad_last = bad_last
      b.begin(0UL, line=true, burst=true, wide=true, data=[
        0x80000080UL, 0UL, 0UL, 0UL,
      ])
      ignore(b.finish(hold=3))
      b.read_fault = 0UL
      b.bad_last = false
    }
    b.reset()
    b.begin(0UL, line=true, burst=true)
    for _ in 0..<10 {
      b.step()
    }
    b.reset()
    b.begin(4092UL)
    ignore(b.finish())
  }
}

///|
test "predicted legacy terminal response preserves 1 KiB streaming and scalar fallback" {
  let b = bench(
    streaming=true,
    wide512=true,
    wide1024=true,
    deep_batch=true,
    strided_rows=true,
    group64_rows=true,
    stripe512=true,
    prefetch_row_blocks=true,
    compare_staged_response_last=true,
    latency=12,
  )
  for
    (line, burst, wide, data, count) in [
      (false, false, false, 0UL, 1),
      (true, false, false, 0UL, 4),
      (true, true, false, 0UL, 32),
      (true, true, true, 0UL, 1),
      (true, true, true, 0xf8000800UL, 256),
      (true, true, true, 0xfc000800UL, 4096),
    ] {
    b.begin(0UL, line~, burst~, wide~, data=[data, 0UL, 0UL, 0UL])
    assert_eq(b.finish(hold=1).length(), count)
  }
  // Rejected wide requests use the legacy response generator even when the
  // accepted wide path normally uses the independent streaming engine.
  b.begin(0x80000000UL, line=true, burst=true, wide=true, data=[
    0x80000080UL, 0UL, 0UL, 0UL,
  ])
  assert_eq(b.finish(hold=4).length(), 64)
}
