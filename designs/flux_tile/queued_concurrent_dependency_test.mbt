///|
fn queued_concurrent_seed_scalars(
  host : PortableHost,
  simulator : @sim.Simulator,
) -> Unit raise {
  for slot in [0, 1] {
    queued_concurrent_load(host, simulator, 0, slot, 1, 1, 32UL, 1UL, [
      if slot == 0 {
        2
      } else {
        5
      },
    ])
    queued_concurrent_load(host, simulator, 1, slot, 1, 1, 256UL, 1UL, [
      if slot == 0 {
        3
      } else {
        7
      },
    ])
    queued_concurrent_compute(host, simulator, 1, 1, 1, a=slot, b=slot, c=slot)
  }
}

///|
test "queued concurrent rejected writer generations forbid fallback to valid old physical operands and C" {
  for (writer, fault) in [(0, 6UL), (1, 2UL), (2, 2UL), (3, 3UL)] {
    let host = PortableHost::new()
    let simulator = queued_concurrent_prepare(16, rows=1, columns=1, capacity=1)
    queued_concurrent_seed_scalars(host, simulator)
    let rejected = match writer {
      0 =>
        queued_concurrent_packet(
          LoadA,
          50,
          rows=1,
          columns=1,
          base=32UL,
          stride=0UL,
        )
      1 =>
        queued_concurrent_packet(
          LoadA,
          50,
          rows=1,
          columns=1,
          base=32UL,
          stride=1UL,
          b=1,
        )
      2 =>
        queued_concurrent_packet(
          MatMul,
          50,
          rows=1,
          columns=1,
          reduction=1,
          base=1UL,
        )
      _ => queued_concurrent_packet(MatMul, 50, rows=0, columns=1, reduction=1)
    }
    let before = host.requests.length()
    queued_concurrent_enqueue(host, simulator, rejected)
    if writer < 2 {
      queued_concurrent_enqueue(
        host,
        simulator,
        queued_concurrent_packet(MatMul, 51, rows=1, columns=1, reduction=1),
      )
    }
    queued_concurrent_enqueue(
      host,
      simulator,
      queued_concurrent_packet(
        StoreC,
        52,
        rows=1,
        columns=1,
        base=1536UL,
        stride=40UL,
      ),
    )
    queued_concurrent_completion(host, simulator, [50UL, fault, 0UL, 0UL])
    queued_concurrent_ack(host, simulator)
    if writer < 2 {
      queued_concurrent_completion(host, simulator, [51UL, 4UL, 0UL, 0UL])
      queued_concurrent_ack(host, simulator)
    }
    queued_concurrent_completion(host, simulator, [52UL, 5UL, 0UL, 0UL])
    queued_concurrent_ack(host, simulator)
    assert_eq(host.requests.length(), before)
    // Unrelated physical slots and latest-writer summaries remain usable.
    queued_concurrent_store(host, simulator, 1, 1, 1, 2048UL, [35])
    host.memory[32UL] = 9
    for byte in 0..<40 {
      host.memory[1536UL + byte.to_uint64()] = 165
    }
    // All three recovery packets are admitted before any recovery completion
    // ACK: Pending dependencies must wait for the new successful generation.
    queued_concurrent_enqueue(
      host,
      simulator,
      queued_concurrent_packet(
        LoadA,
        53,
        rows=1,
        columns=1,
        base=32UL,
        stride=1UL,
      ),
    )
    queued_concurrent_enqueue(
      host,
      simulator,
      queued_concurrent_packet(MatMul, 54, rows=1, columns=1, reduction=1),
    )
    queued_concurrent_enqueue(
      host,
      simulator,
      queued_concurrent_packet(
        StoreC,
        55,
        rows=1,
        columns=1,
        base=1536UL,
        stride=40UL,
      ),
    )
    queued_concurrent_drain(host, simulator, [
      [53UL, 0UL, 1UL, 0UL],
      [54UL, 0UL, 0UL, 0UL],
      [55UL, 0UL, 4UL, 0UL],
    ])
    concurrent_check_words(host, 1536UL, 1, 1, [27])
    queued_concurrent_store(host, simulator, 1, 1, 1, 2048UL, [35])
  }
}

///|
test "queued concurrent syntax invalid would-be writers preserve prior successful intent" {
  let host = PortableHost::new()
  let simulator = queued_concurrent_prepare(16, rows=1, columns=1, capacity=1)
  queued_concurrent_seed_scalars(host, simulator)
  for (kind, fault) in [(0, 12UL), (1, 13UL), (2, 1UL), (3, 14UL)] {
    let malformed = queued_concurrent_packet(
      LoadA,
      60,
      rows=1,
      columns=1,
      base=32UL,
      stride=1UL,
    )
    match kind {
      0 => malformed[0] = malformed[0] ^ 768UL
      1 => malformed[3] = 2UL // Reserved upper A-selector bit, not selector1.
      2 => malformed[0] = malformed[0] | (255UL << 16)
      _ => malformed[1] = 8192UL | (1UL << 16)
    }
    let before = host.requests.length()
    for
      packet in [
        malformed,
        queued_concurrent_packet(MatMul, 61, rows=1, columns=1, reduction=1),
        queued_concurrent_packet(
          StoreC,
          62,
          rows=1,
          columns=1,
          base=1536UL,
          stride=40UL,
        ),
      ] {
      queued_concurrent_enqueue(host, simulator, packet)
    }
    queued_concurrent_drain(host, simulator, [
      [60UL, fault, 0UL, 0UL],
      [61UL, 0UL, 0UL, 0UL],
      [62UL, 0UL, 4UL, 0UL],
    ])
    assert_eq(host.requests.length(), before + 1)
    assert_eq(host.word(1536UL), 6)
  }
}

///|
test "queued concurrent delayed older writer success cannot replace newer Failed intent" {
  let host = PortableHost::new()
  let simulator = queued_concurrent_prepare(16, rows=1, columns=1, capacity=1)
  queued_concurrent_load(host, simulator, 1, 0, 1, 1, 256UL, 1UL, [3])
  host.latency = 100
  host.memory[32UL] = 9
  for
    packet in [
      queued_concurrent_packet(
        LoadA,
        70,
        rows=1,
        columns=1,
        base=32UL,
        stride=1UL,
      ),
      queued_concurrent_packet(
        LoadA,
        71,
        rows=1,
        columns=1,
        base=32UL,
        stride=1UL,
        b=1,
      ),
      queued_concurrent_packet(MatMul, 72, rows=1, columns=1, reduction=1),
    ] {
    queued_concurrent_enqueue(host, simulator, packet)
  }
  queued_concurrent_completion(host, simulator, [70UL, 0UL, 1UL, 0UL])
  // Physical A0 is now successfully loaded by the older ticket. The newer
  // syntax-valid unused-field writer must nevertheless remain latest Failed.
  queued_concurrent_enqueue(
    host,
    simulator,
    queued_concurrent_packet(MatMul, 73, rows=1, columns=1, reduction=1),
  )
  queued_concurrent_drain(host, simulator, [
    [70UL, 0UL, 1UL, 0UL],
    [71UL, 2UL, 0UL, 0UL],
    [72UL, 4UL, 0UL, 0UL],
    [73UL, 4UL, 0UL, 0UL],
  ])
  host.latency = 1
  queued_concurrent_load(host, simulator, 0, 0, 1, 1, 32UL, 1UL, [5])
  queued_concurrent_compute(host, simulator, 1, 1, 1)
  queued_concurrent_store(host, simulator, 0, 1, 1, 1536UL, [15])
}
