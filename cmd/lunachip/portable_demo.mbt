///|
fn portable_demo() -> String raise {
  let left = [1, -2, 3, -128, 4, 127]
  let right = [5, -6, 7, 8, 9, -10, -11, 12, 13]
  let host = DemoHost::new()
  host.seed(32, 8, 2, 3, left)
  host.seed(128, 8, 3, 3, right)
  let simulator = portable_demo_prepare()
  host.command(simulator, 0, 1, 2, 3, 0, 32, 8, 6UL)
  host.command(simulator, 1, 2, 3, 3, 0, 128, 8, 9UL)
  host.command(simulator, 2, 3, 2, 3, 3, 0, 0, 0UL)
  demo_expect(simulator, "active_cycles", 6UL)
  demo_expect(simulator, "elapsed_cycles", 7UL)
  demo_expect(simulator, "stall_cycles", 0UL)
  demo_expect(simulator, "capture_cycles", 6UL)
  host.command(simulator, 3, 4, 2, 3, 0, 256, 16, 24UL)
  let before_fence = host.requests
  host.command(simulator, 4, 5, 0, 0, 0, 0, 0, 0UL)
  if host.requests != before_fence ||
    host.requests != 21 ||
    host.read_bytes != 15 ||
    host.write_bytes != 24 ||
    host.request_stalls == 0 ||
    host.response_delays == 0 {
    raise DemoError::Transport(
      "unexpected request counts or missing injected stalls",
    )
  }
  let expected = @flux_tile.matmul_int8_oracle(
    left,
    right,
    rows=2,
    columns=3,
    reduction=3,
  )
  let results = Array::makei(6, index => {
    let actual = host.word(256 + index / 3 * 16 + index % 3 * 4)
    if actual != expected[index] {
      raise DemoError::UnexpectedResult(
        index~,
        expected=expected[index],
        actual~,
      )
    }
    actual
  })
  // Check every host byte: the only changes permitted beyond input seeding
  // are the six words observed on the device's StoreC requests.
  let expected_memory = DemoHost::new()
  expected_memory.seed(32, 8, 2, 3, left)
  expected_memory.seed(128, 8, 3, 3, right)
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
  "LunaWave FluxTile portable demo: LoadA -> LoadB -> MatMul -> StoreC -> Fence\n" +
  "host C=[\{results[0]}, \{results[1]}, \{results[2]}; \{results[3]}, \{results[4]}, \{results[5]}] oracle=match\n" +
  "5 successful completions; requests=21 read_bytes=15 write_bytes=24; padding preserved\n" +
  "modeled compute cycles=7 active=6 capture=6; transport backpressure and delayed responses exercised\n" +
  "Simulation only; provisional serial transport, not a frozen device ABI."
}
