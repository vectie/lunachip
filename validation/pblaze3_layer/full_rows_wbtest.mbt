///|
test "1024-column rows issue consecutive 512-byte bursts up to the end of DDR" {
  let addresses = []
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
    read_addresses=Some(addresses),
  )
  let base = 0x7ff80000UL
  exercise_wide_matrix(b, 256, columns=1024, base~, cancellation=true)
  assert_eq(addresses.length(), 1024)
  for i, address in addresses {
    assert_eq(address, base + i.to_uint64() * 512UL)
  }
  addresses.clear()
  // A misaligned full row uses the original 128-byte path.
  exercise_wide_matrix(
    b,
    16,
    columns=1024,
    base=0x40000f80UL,
    cancellation=true,
  )
  assert_eq(addresses[1] - addresses[0], 2048UL)
}

///|
test "32 KiB matrix groups reduce owner handoffs on 512-byte-aligned weight rows" {
  let trace = []
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
    indirect_bf16=true,
    bounded_add=true,
    deep_batch=true,
    group_headers=Some(trace),
  )
  exercise_wide_matrix(
    b,
    128,
    columns=1024,
    base=0x60000200UL,
    cancellation=true,
  )
  assert_eq(trace.length(), 8)
  for h in trace {
    assert_eq(h, 0xe0000200UL)
  }
  trace.clear()
  exercise_wide_matrix(
    b,
    16,
    columns=1024,
    base=0x7fff8000UL,
    cancellation=true,
  )
  assert_eq(trace, [0xe0000200UL])
}
