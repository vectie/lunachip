///|
test "word reads preserve signed matrices for every alignment and short row tail" {
  for alignment in 0..<4 {
    for reduction in [1, 3, 4, 5, 7, 8] {
      let host = PortableHost::new(word_reads=true)
      let simulator = ring_concurrent_prepare(
        rows=2,
        columns=7,
        capacity=8,
        word_reads=true,
      )
      ring_concurrent_config(host, simulator)
      let a = Array::makei(2 * reduction, i => (i * 47 + 11) % 256 - 128)
      let w = Array::makei(reduction * 7, i => (i * 83 + 231) % 256 - 128)
      let base = 32UL + alignment.to_uint64()
      host.seed(base, 13UL, 2, reduction, a)
      host.seed(256UL + alignment.to_uint64(), 11UL, reduction, 7, w)
      ring_concurrent_submit(host, simulator, 0UL, [
        queued_concurrent_packet(
          LoadA,
          10,
          rows=2,
          columns=reduction,
          base~,
          stride=13UL,
        ),
        queued_concurrent_packet(
          LoadB,
          11,
          rows=reduction,
          columns=7,
          base=256UL + alignment.to_uint64(),
          stride=11UL,
        ),
        queued_concurrent_packet(MatMul, 12, rows=2, columns=7, reduction~),
        queued_concurrent_packet(
          StoreC,
          13,
          rows=2,
          columns=7,
          base=4096UL,
          stride=40UL,
        ),
      ])
      queued_concurrent_drain(host, simulator, [
        [10UL, 0UL, (2 * reduction).to_uint64(), 0UL],
        [11UL, 0UL, (reduction * 7).to_uint64(), 0UL],
        [12UL, 0UL, 0UL, 0UL],
        [13UL, 0UL, 56UL, 0UL],
      ])
      let expected = @flux_tile.matmul_int8_oracle(
        a,
        w,
        rows=2,
        columns=7,
        reduction~,
      )
      for row in 0..<2 {
        for column in 0..<7 {
          assert_eq(
            host.word(4096UL + (row * 40 + column * 4).to_uint64()),
            expected[row * 7 + column],
          )
        }
      }
      let descriptor_reads = host.requests.filter(r => {
        r[0] == 0UL && r[1] >= 8192UL
      })
      assert_eq(descriptor_reads.length(), 32)
      assert_true(descriptor_reads.all(r => r[2] == 4UL))
      // Every operand request remains within its exact admitted row.
      for r in host.requests {
        if r[0] == 0UL && r[1] < 8192UL {
          let (start, stride, columns) = if r[1] < 256UL {
            (base, 13UL, reduction.to_uint64())
          } else {
            (256UL + alignment.to_uint64(), 11UL, 7UL)
          }
          assert_true((r[1] - start) % stride + r[2] <= columns)
        }
      }
    }
  }
}

///|
test "word descriptor faults report aligned address and joint reset permits recovery" {
  for protocol in [false, true] {
    let host = PortableHost::new(word_reads=true)
    let simulator = ring_concurrent_prepare(word_reads=true)
    ring_concurrent_config(host, simulator)
    if protocol {
      host.protocol_at = 2
    } else {
      host.fail_at = 2
    }
    ring_concurrent_submit(host, simulator, 0UL, [
      queued_concurrent_packet(Fence, 20),
    ])
    for _ in 0..<200 {
      host.tick(simulator)
      if execute_read(simulator, "ring_fault_valid") == 1UL {
        break
      }
    }
    assert_eq(execute_read(simulator, "ring_fault_valid"), 1UL)
    assert_eq(execute_read(simulator, "ring_fault_address"), 8200UL)
    assert_eq(
      execute_read(simulator, "transport_halted"),
      if protocol {
        1UL
      } else {
        0UL
      },
    )
    ring_concurrent_reset(host, simulator)
    ring_concurrent_config(host, simulator)
    ring_concurrent_one(
      host,
      simulator,
      0UL,
      queued_concurrent_packet(Fence, 21),
      [21UL, 0UL, 0UL, 0UL],
    )
  }
}

///|
test "word core loads every bank of an eight by eight signed edge matrix" {
  let host = PortableHost::new(word_reads=true)
  let simulator = ring_concurrent_prepare(capacity=16, word_reads=true)
  ring_concurrent_config(host, simulator)
  let edges = [-128, 127, 0, 1, -1, -127, 126]
  let a = Array::makei(128, i => edges[i % edges.length()])
  let w = Array::makei(128, i => edges[(i * 3 + 1) % edges.length()])
  host.seed(256UL, 16UL, 8, 16, a)
  host.seed(512UL, 8UL, 16, 8, w)
  for byte in 0..<320 {
    host.memory[4096UL + byte.to_uint64()] = 165
  }
  ring_concurrent_submit(host, simulator, 0UL, [
    queued_concurrent_packet(
      LoadA,
      10,
      rows=8,
      columns=16,
      base=256UL,
      stride=16UL,
    ),
    queued_concurrent_packet(
      LoadB,
      11,
      rows=16,
      columns=8,
      base=512UL,
      stride=8UL,
    ),
    queued_concurrent_packet(MatMul, 12, rows=8, columns=8, reduction=16),
    queued_concurrent_packet(
      StoreC,
      13,
      rows=8,
      columns=8,
      base=4096UL,
      stride=40UL,
    ),
  ])
  queued_concurrent_drain(host, simulator, [
    [10UL, 0UL, 128UL, 0UL],
    [11UL, 0UL, 128UL, 0UL],
    [12UL, 0UL, 0UL, 0UL],
    [13UL, 0UL, 256UL, 0UL],
  ])
  concurrent_check_words(
    host,
    4096UL,
    8,
    8,
    @flux_tile.matmul_int8_oracle(a, w, rows=8, columns=8, reduction=16),
  )
  assert_eq(host.requests.length(), 160)
  assert_true(host.requests.all(r => r[2] == 4UL))
}
