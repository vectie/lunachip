///|
test "portable tile canonical graph has a fixed pre-frontend golden digest" {
  let design = @wire.single_design(
    "Portable",
    @flux_tile.portable_tile(
      rows=2,
      columns=3,
      max_reduction=5,
      host_bytes=4096UL,
    ),
  )
  inspect(
    @crypto.bytes_to_hex_string(
      @crypto.sha256(@utf8.encode(@codec.serialize(design))),
    ),
    content="63d6358a98194301aa40f8cd68f8914dc67a71ec648f2716721730d231255927",
  )
}

///|
fn portable_workload(
  host : PortableHost,
  simulator : @sim.Simulator,
  rows : Int,
  columns : Int,
  reduction : Int,
  left : Array[Int],
  right : Array[Int],
) -> Unit raise {
  host.seed(32UL, 13UL, rows, reduction, left)
  host.seed(256UL, 17UL, reduction, columns, right)
  for address in 512..<900 {
    host.memory[address.to_uint64()] = 165
  }
  portable_success(
    host,
    simulator,
    0,
    1,
    rows,
    reduction,
    0,
    32UL,
    13UL,
    (rows * reduction).to_uint64(),
  )
  portable_success(
    host,
    simulator,
    1,
    2,
    reduction,
    columns,
    0,
    256UL,
    17UL,
    (reduction * columns).to_uint64(),
  )
  portable_success(
    host, simulator, 2, 3, rows, columns, reduction, 0UL, 0UL, 0UL,
  )
  let active = execute_read(simulator, "active_cycles")
  assert_eq(active, (reduction + rows + columns - 2).to_uint64())
  assert_eq(execute_read(simulator, "elapsed_cycles"), active + 1UL)
  assert_eq(
    execute_read(simulator, "capture_cycles"),
    (rows * columns).to_uint64(),
  )
  portable_success(
    host,
    simulator,
    3,
    4,
    rows,
    columns,
    0,
    512UL,
    40UL,
    (rows * columns * 4).to_uint64(),
  )
  let expected = @flux_tile.matmul_int8_oracle(
    left,
    right,
    rows~,
    columns~,
    reduction~,
  )
  for row in 0..<rows {
    for column in 0..<columns {
      assert_eq(
        host.word(512UL + row.to_uint64() * 40UL + column.to_uint64() * 4UL),
        expected[row * columns + column],
      )
    }
    for padding in (columns * 4)..<40 {
      assert_eq(
        host.memory
        .get(512UL + row.to_uint64() * 40UL + padding.to_uint64())
        .unwrap(),
        165,
      )
    }
  }
  let count = host.requests.length()
  portable_success(host, simulator, 4, 5, 0, 0, 0, 0UL, 0UL, 0UL)
  assert_eq(host.requests.length(), count)
  assert_eq(execute_read(simulator, "active_cycles"), active)
}

///|
test "portable tile transfers padded non-square and 8x8 workloads through real banks and SRAM" {
  for (rows, columns, reduction) in [(3, 2, 5), (8, 8, 3)] {
    let host = PortableHost::new()
    let simulator = portable_prepare(8, 8, 5, 4096UL)
    let left = Array::makei(rows * reduction, index => {
      (index * 47 + 13) % 256 - 128
    })
    let right = Array::makei(reduction * columns, index => {
      (index * 83 + 231) % 256 - 128
    })
    portable_workload(host, simulator, rows, columns, reduction, left, right)
    // A later smaller exact-shape load/compute/store replaces slot validity;
    // stale initialized prefixes do not select a previous larger shape.
    portable_workload(host, simulator, 1, 1, 1, [-128], [127])
    let count = host.requests.length()
    assert_eq(
      portable_command(
        host, simulator, 2, 6, rows, columns, reduction, 0UL, 0UL,
      ),
      (4UL, 0UL, 0UL),
    )
    portable_ack(host, simulator, true)
    assert_eq(
      portable_command(host, simulator, 3, 7, rows, columns, 0, 900UL, 40UL),
      (5UL, 0UL, 0UL),
    )
    portable_ack(host, simulator, true)
    assert_eq(host.requests.length(), count)
  }
}

///|
test "portable tile accepts the final aperture byte and a word ending exactly at 2^32" {
  let host = PortableHost::new()
  host.stalled = false
  host.latency = 0
  host.memory[0xffffffffUL] = 128
  host.memory[0xfffffffeUL] = 127
  let simulator = portable_prepare(1, 1, 1, 4294967296UL)
  portable_success(host, simulator, 0, 10, 1, 1, 0, 0xffffffffUL, 1UL, 1UL)
  portable_success(host, simulator, 1, 11, 1, 1, 0, 0xfffffffeUL, 1UL, 1UL)
  portable_success(host, simulator, 2, 12, 1, 1, 1, 0UL, 0UL, 0UL)
  portable_success(host, simulator, 3, 13, 1, 1, 0, 0xfffffffcUL, 4UL, 4UL)
  assert_eq(host.word(0xfffffffcUL), -16256)
  assert_eq(host.requests.map(request => request[1]), [
    0xffffffffUL, 0xfffffffeUL, 0xfffffffcUL,
  ])
}

///|
test "portable tile validates descriptors before any issue with exact fault priority" {
  let host = PortableHost::new()
  let simulator = portable_prepare(3, 2, 5, 4096UL)
  for
    (opcode, rows, columns, reduction, base, stride, expected) in [
      (7, 0, 0, 0, 0UL, 0UL, 1UL),
      (0, 0, 0, 1, 0UL, 0UL, 2UL),
      (4, 1, 0, 0, 0UL, 0UL, 2UL),
      (2, 0, 0, 0, 1UL, 0UL, 2UL),
      (2, 0, 0, 0, 0UL, 0UL, 3UL),
      (0, 4, 1, 0, 0UL, 1UL, 3UL),
      (1, 1, 3, 0, 0UL, 3UL, 3UL),
      (0, 1, 8191, 0, 0UL, 8191UL, 3UL),
      (2, 3, 2, 5, 0UL, 0UL, 4UL),
      (3, 3, 2, 0, 3UL, 1UL, 5UL),
      (0, 1, 2, 0, 0UL, 1UL, 6UL),
      (0, 1, 2, 0, 4095UL, 2UL, 8UL),
      (0, 2, 1, 0, 32UL, 0xffffffffUL, 8UL),
    ] {
    let before = host.requests.length()
    let result = portable_command(
      host, simulator, opcode, 20, rows, columns, reduction, base, stride,
    )
    assert_eq(result.0, expected)
    assert_eq(result.1, 0UL)
    assert_eq(host.requests.length(), before)
    portable_ack(host, simulator, true)
  }
  // Valid prior operands/result must survive a rejected preflight transfer.
  portable_workload(host, simulator, 1, 1, 1, [2], [3])
  for
    (base, stride, expected) in [
      (1UL, 4UL, 7UL),
      (0UL, 3UL, 6UL),
      (0UL, 5UL, 7UL),
      (4096UL, 4UL, 8UL),
    ] {
    let before = host.requests.length()
    let result = portable_command(host, simulator, 3, 21, 1, 1, 0, base, stride)
    assert_eq(result.0, expected)
    assert_eq(result.1, 0UL)
    assert_eq(host.requests.length(), before)
    portable_ack(host, simulator, true)
  }
  portable_success(host, simulator, 3, 22, 1, 1, 0, 800UL, 4UL, 4UL)
  assert_eq(host.word(800UL), 6)
}

///|
test "portable tile rejects wrapped UInt32 descriptors with an independent UInt64 aperture bound" {
  let host = PortableHost::new()
  let simulator = portable_prepare(2, 1, 2, 4294967296UL)
  for (base, stride) in [(0xffffffffUL, 1UL), (0xfffffffeUL, 0xffffffffUL)] {
    let result = portable_command(host, simulator, 0, 30, 2, 1, 0, base, stride)
    assert_eq(result.0, 8UL)
    assert_eq(result.1, 0UL)
    assert_eq(host.requests.length(), 0)
    portable_ack(host, simulator, true)
  }
}
