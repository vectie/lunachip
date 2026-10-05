///|
test "queued tile executes a five-descriptor padded signed workload through portable memory" {
  let host = PortableHost::new()
  let simulator = frontend_prepare(3)
  let left = Array::makei(15, index => (index * 47 + 13) % 256 - 128)
  let right = Array::makei(10, index => (index * 83 + 231) % 256 - 128)
  host.seed(32UL, 13UL, 3, 5, left)
  host.seed(256UL, 17UL, 5, 2, right)
  for address in 512..<632 {
    host.memory[address.to_uint64()] = 165
  }
  let commands = [
    frontend_encoded({
      opcode: LoadA,
      id: 1U,
      rows: 3U,
      columns: 5U,
      reduction: 0U,
      base: 32U,
      stride: 13U,
    }),
    frontend_encoded({
      opcode: LoadB,
      id: 2U,
      rows: 5U,
      columns: 2U,
      reduction: 0U,
      base: 256U,
      stride: 17U,
    }),
    frontend_encoded({
      opcode: MatMul,
      id: 3U,
      rows: 3U,
      columns: 2U,
      reduction: 5U,
      base: 0U,
      stride: 0U,
    }),
    frontend_encoded({
      opcode: StoreC,
      id: 4U,
      rows: 3U,
      columns: 2U,
      reduction: 0U,
      base: 512U,
      stride: 40U,
    }),
    frontend_encoded({
      opcode: Fence,
      id: 5U,
      rows: 0U,
      columns: 0U,
      reduction: 0U,
      base: 0U,
      stride: 0U,
    }),
  ]
  for index in 0..<4 {
    frontend_enqueue(host, simulator, commands[index])
  }
  assert_eq(execute_read(simulator, "queue_occupancy"), 3UL)
  frontend_present(simulator, commands[4])
  frontend_completion(host, simulator, 1UL, 0UL, 15UL)
  assert_eq(execute_read(simulator, "descriptor_ready"), 0UL)
  frontend_ack(host, simulator)
  assert_eq(execute_read(simulator, "descriptor_ready"), 1UL)
  host.tick(simulator)
  portable_put(simulator, "descriptor_valid", 1, 0UL)
  for (id, bytes) in [(2UL, 10UL), (3UL, 0UL), (4UL, 24UL), (5UL, 0UL)] {
    frontend_completion(host, simulator, id, 0UL, bytes)
    frontend_ack(host, simulator)
  }
  let expected = @flux_tile.matmul_int8_oracle(
    left,
    right,
    rows=3,
    columns=2,
    reduction=5,
  )
  for row in 0..<3 {
    for column in 0..<2 {
      assert_eq(
        host.word(512UL + row.to_uint64() * 40UL + column.to_uint64() * 4UL),
        expected[row * 2 + column],
      )
    }
    for byte in 8..<40 {
      assert_eq(
        host.memory
        .get(512UL + row.to_uint64() * 40UL + byte.to_uint64())
        .unwrap(),
        165,
      )
    }
  }
  assert_eq(host.requests.length(), 31)
  assert_eq(execute_read(simulator, "active_cycles"), 8UL)
  assert_eq(execute_read(simulator, "elapsed_cycles"), 9UL)
  assert_eq(execute_read(simulator, "capture_cycles"), 6UL)
}
