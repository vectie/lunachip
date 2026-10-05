///|
fn ring_demo() -> String raise {
  let left = [1, -2, 3, -128, 4, 127]
  let right = [5, -6, 7, 8, 9, -10, -11, 12, 13]
  let host = DemoHost::new()
  host.seed(32, 8, 2, 3, left)
  host.seed(128, 8, 3, 3, right)
  ring_demo_seed_descriptors(host)
  let simulator = ring_demo_prepare()
  ring_demo_publish(host, simulator)
  for (id, bytes) in [(1, 6UL), (2, 9UL), (3, 0UL), (4, 24UL), (5, 0UL)] {
    ring_demo_completion(host, simulator, id, bytes)
  }
  for (name, value) in [
    ("producer_count", 5UL), ("consumer_count", 5UL),
    ("ring_fault_valid", 0UL), ("transport_halted", 0UL), ("halted", 0UL),
    ("queue_occupancy", 0UL), ("active_cycles", 6UL),
    ("elapsed_cycles", 7UL), ("stall_cycles", 0UL), ("capture_cycles", 6UL),
  ] {
    demo_expect(simulator, name, value)
  }
  if host.pending is Some(_) || host.held is Some(_) ||
    host.requests != 181 || host.read_bytes != 175 || host.write_bytes != 24 ||
    host.request_stalls == 0 || host.response_delays == 0 {
    raise DemoError::Transport("unexpected ring transaction counts or unretired work")
  }
  let expected = @flux_tile.matmul_int8_oracle(left, right, rows=2, columns=3, reduction=3)
  let results = Array::makei(6, index => {
    let actual = host.word(256 + index / 3 * 16 + index % 3 * 4)
    if actual != expected[index] {
      raise DemoError::UnexpectedResult(index~, expected=expected[index], actual~)
    }
    actual
  })
  // Descriptor fetch and operand reads must not alter any host byte. Only
  // the six acknowledged StoreC words may differ from the seeded image.
  let expected_memory = DemoHost::new()
  expected_memory.seed(32, 8, 2, 3, left)
  expected_memory.seed(128, 8, 3, 3, right)
  ring_demo_seed_descriptors(expected_memory)
  for index in 0..<6 {
    let bits = (expected[index].to_int64() & 0xffffffffL).reinterpret_as_uint64()
    let address = 256 + index / 3 * 16 + index % 3 * 4
    for byte in 0..<4 {
      expected_memory.memory[address + byte] = ((bits >> (byte * 8)) & 255UL).to_int()
    }
  }
  for address in 0..<1024 {
    if host.memory[address] != expected_memory.memory[address] {
      raise DemoError::Transport("unexpected host byte at address \{address}")
    }
  }
  "LunaWave FluxTile ring demo: fetched LoadA -> LoadB -> MatMul -> StoreC -> Fence\n" +
  "host C=[\{results[0]}, \{results[1]}, \{results[2]}; \{results[3]}, \{results[4]}, \{results[5]}] oracle=match\n" +
  "5 ordered successful completions; producer=5 consumer=5; descriptors fetched from host bytes\n" +
  "requests=181 read_bytes=175 write_bytes=24; descriptor/input/output padding preserved\n" +
  "modeled compute cycles=7 active=6 capture=6; shared transport backpressure and delayed responses exercised\n" +
  "Simulation only; provisional fetched ring and draft device ABI."
}
