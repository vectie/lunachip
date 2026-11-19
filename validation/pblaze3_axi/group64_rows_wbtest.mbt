///|
test "64-row 32 KiB reads honor physical row stride, credits and the final DDR byte" {
  check_strided_groups(false, false)
}

///|
test "32-row 1 KiB bursts and the 512-byte fallback preserve all 32 KiB under stalls" {
  check_strided_groups(true, true)
  check_strided_groups(true, false)
}

///|
test "512-row lookahead spans all sixteen blocks and rejects a crossing last row" {
  check_strided_groups(true, true, prefetch=true)
}

///|
fn check_strided_groups(
  stripe512 : Bool,
  use_long : Bool,
  prefetch~ : Bool = false,
) -> Unit raise {
  let b = bench(
    streaming=true,
    wide512=true,
    wide1024=true,
    deep_batch=true,
    strided_rows=true,
    group64_rows=true,
    stripe512~,
    prefetch_row_blocks=prefetch,
    latency=48,
    read_credits=64,
  )
  let rows = if prefetch { 512 } else if use_long { 32 } else { 64 }
  let beats = if use_long { 8 } else { 4 }
  let packets = rows * beats
  let bytes = (128 * beats).to_uint64()
  for stride in [2048UL, 4096UL, 6144UL] {
    let tag = (if prefetch {
        0xfc000000UL
      } else if use_long {
        0xf8000000UL
      } else {
        0xf0000000UL
      }) |
      stride
    let base = 0x80000000UL - (rows - 1).to_uint64() * stride - bytes
    let before = b.reads.length()
    b.begin(base, line=true, burst=true, wide=true, data=[tag, 0UL, 0UL, 0UL])
    let replies = b.finish(hold=2)
    assert_eq((b.reads.length() - before, replies.length()), (rows, packets))
    for row in 0..<rows {
      assert_eq(b.reads[before + row], base + row.to_uint64() * stride)
      if prefetch && row > 0 && row % 32 == 0 {
        assert_true(b.delivered_at_ar[before + row] < row * beats)
      }
    }
    for i, (words, fault, last) in replies {
      assert_eq(fault, 0UL)
      assert_eq(last, if i + 1 == packets { 1UL } else { 0UL })
      for j, word in words {
        let address = base +
          (i / beats).to_uint64() * stride +
          (128 * (i % beats) + 4 * j).to_uint64()
        assert_eq(word, b.word(address))
      }
    }
    assert_true(b.peak_outstanding > 1 && b.peak_outstanding <= 16)
    for
      (address, header) in [
        (base + bytes, tag),
        (0x1000000UL + bytes / 2UL, tag),
        (base + 128UL, tag),
        (base, tag | 0x200UL),
      ] {
      b.begin(address, line=true, burst=true, wide=true, data=[
        header, 0UL, 0UL, 0UL,
      ])
      assert_eq(b.finish()[0].1, 1UL)
      assert_eq(b.reads.length(), before + rows)
    }
  }
}
