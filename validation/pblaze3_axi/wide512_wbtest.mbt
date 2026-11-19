///|
test "512-bit AXI preserves all scalar lanes and ordered wide stripe payloads" {
  let b = bench(streaming=true, wide512=true)
  exercise(b)
  for i in 0..<16 {
    let a = 0x7fffffc0UL + 4UL * i.to_uint64()
    b.begin(a, write=true, data=[a, 0UL, 0UL, 0UL])
    ignore(b.finish())
  }
  for i in 0..<16 {
    let a = 0x7fffffc0UL + 4UL * i.to_uint64()
    b.begin(a)
    assert_eq(b.finish()[0].0[0], a)
  }
}

///|
test "512-bit K1024 row stripe halves AXI beats under the same latency and credits" {
  let times = []
  for wide512 in [false, true] {
    let b = bench(streaming=true, wide512~, latency=16, read_credits=8)
    let start = b.cycle
    b.begin(0x1fff80UL, line=true, burst=true, wide=true, data=[
      0x80000800UL, 0UL, 0UL, 0UL,
    ])
    let replies = b.finish(hold=0)
    assert_eq(replies.length() * b.lanes * 4, 2048)
    assert_eq(b.reads.length(), 16)
    for i, (words, fault, last) in replies {
      assert_eq(fault, 0UL)
      assert_eq(last, if i + 1 == replies.length() { 1UL } else { 0UL })
      let offset = i * 4 * b.lanes
      for j, word in words {
        assert_eq(
          word,
          b.word(
            0x1fff80UL +
            (offset / 128 * 2048 + offset % 128 + j * 4).to_uint64(),
          ),
        )
      }
    }
    times.push(b.cycle - start)
    println(
      "K1024 bytes=2048 width=\{32*b.lanes} beats=\{replies.length()} cycles=\{b.cycle-start}",
    )
  }
  assert_true(times[1] < times[0])
}

///|
test "1024-bit long row reads preserve order at the aperture end and validate complete extents" {
  let b = bench(
    streaming=true,
    wide512=true,
    wide1024=true,
    latency=16,
    read_credits=8,
  )
  let base = 0x7fffe000UL
  b.begin(base, line=true, burst=true, wide=true, data=[
    0xc0000200UL, 0UL, 0UL, 0UL,
  ])
  let result = b.finish(hold=2)
  assert_eq(result.length(), 64)
  assert_eq(b.reads.length(), 16)
  for i, (words, fault, last) in result {
    assert_eq(fault, 0UL)
    assert_eq(last, if i == 63 { 1UL } else { 0UL })
    for j, v in words {
      assert_eq(v, b.word(base + (32 * i + j).to_uint64() * 4UL))
    }
  }
  for
    (address, header) in [
      (base + 512UL, 0xc0000200UL),
      (base + 128UL, 0xc0000200UL),
      (base, 0xc0000080UL),
    ] {
    b.begin(address, line=true, burst=true, wide=true, data=[
      header, 0UL, 0UL, 0UL,
    ])
    assert_eq(b.finish()[0].1, 1UL)
    assert_eq(b.reads.length(), 16)
  }
  for i in 0..<32 {
    let address = 0x7fffff80UL + i.to_uint64() * 4UL
    b.begin(address, write=true, data=[address, 0UL, 0UL, 0UL])
    ignore(b.finish())
  }
  for i in 0..<32 {
    let address = 0x7fffff80UL + i.to_uint64() * 4UL
    b.begin(address)
    assert_eq(b.finish()[0].0[0], address)
  }
}

///|
test "32 KiB group preserves every packet and enforces sixteen outstanding reads" {
  let b = bench(
    streaming=true,
    wide512=true,
    wide1024=true,
    deep_batch=true,
    latency=48,
    read_credits=64,
  )
  let base = 0x7fff8000UL
  let tag = 0xe0000200UL
  b.begin(base, line=true, burst=true, wide=true, data=[tag, 0UL, 0UL, 0UL])
  let replies = b.finish(hold=1)
  assert_eq(replies.length(), 256)
  assert_eq(b.peak_outstanding, 16)
  assert_eq(b.outstanding, 0)
  assert_eq(b.reads.length(), 64)
  for i, address in b.reads {
    assert_eq(address, base + i.to_uint64() * 512UL)
  }
  for i, (words, fault, last) in replies {
    assert_eq(fault, 0UL)
    assert_eq(last, if i == 255 { 1UL } else { 0UL })
    for j, word in words {
      assert_eq(word, b.word(base + (32 * i + j).to_uint64() * 4UL))
    }
  }
  for
    (address, header) in [
      (base + 512UL, tag),
      (base + 128UL, tag),
      (base, tag + 512UL),
    ] {
    b.begin(address, line=true, burst=true, wide=true, data=[
      header, 0UL, 0UL, 0UL,
    ])
    assert_eq(b.finish()[0].1, 1UL)
    assert_eq(b.reads.length(), 64)
  }
  // A normal 8 KiB instruction-loader batch still returns 64 packets.
  b.begin(base, line=true, burst=true, wide=true, data=[
    0xc0000200UL, 0UL, 0UL, 0UL,
  ])
  assert_eq(b.finish().length(), 64)
}

///|
test "32 KiB strided stripes cover all words at the DDR boundary without crossing a row" {
  let b = bench(
    streaming=true,
    wide512=true,
    wide1024=true,
    deep_batch=true,
    strided_rows=true,
    latency=48,
    read_credits=64,
  )
  for stride in [4096UL, 6144UL] {
    let base = 0x80000000UL - 15UL * stride - 2048UL
    let header = 0xe0000000UL + stride
    let first = b.reads.length()
    b.begin(base, line=true, burst=true, wide=true, data=[header, 0UL, 0UL, 0UL])
    let replies = b.finish(hold=2)
    assert_eq(b.reads.length(), first + 64)
    assert_eq(b.peak_outstanding, 16)
    assert_eq(b.outstanding, 0)
    for i in 0..<64 {
      let address = base +
        (i / 4).to_uint64() * stride +
        (i % 4).to_uint64() * 512UL
      assert_eq(b.reads[first + i], address)
    }
    assert_eq(replies.length(), 256)
    for i, (words, fault, last) in replies {
      assert_eq(fault, 0UL)
      assert_eq(last, if i == 255 { 1UL } else { 0UL })
      for j, word in words {
        let address = base +
          (i / 16).to_uint64() * stride +
          (i % 16 * 128 + j * 4).to_uint64()
        assert_eq(word, b.word(address))
      }
    }
    b.begin(base + 512UL, line=true, burst=true, wide=true, data=[
      header, 0UL, 0UL, 0UL,
    ])
    assert_eq(b.finish()[0].1, 1UL)
    assert_eq(b.reads.length(), first + 64)
  }
}
