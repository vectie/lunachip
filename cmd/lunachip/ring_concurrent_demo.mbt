///|
fn ring_concurrent_demo() -> String raise {
  let left = Array::makei(128, index => (index * 47 + 13) % 256 - 128)
  let right = Array::makei(128, index => (index * 83 + 231) % 256 - 128)
  let host = DemoHost::new()
  let expected_memory = DemoHost::new()
  for memory in [host, expected_memory] {
    memory.seed(32, 18, 8, 16, left)
    memory.seed(192, 10, 16, 8, right)
  }
  let run = ring_concurrent_demo_prepare(host)
  run.publish(expected_memory, 0, [
    concurrent_demo_packet(LoadA, (8, 16, 0), (32, 18), (1, 0, 0)),
    concurrent_demo_packet(LoadB, (16, 8, 0), (192, 10), (0, 1, 0)),
    concurrent_demo_packet(MatMul, (8, 8, 16), (0, 0), (1, 1, 0)),
  ])
  for bytes in [128UL, 128UL, 0UL] {
    run.completion(bytes, 3)
  }
  for memory in [host, expected_memory] {
    memory.seed(384, 16, 8, 16, Array::make(128, -7))
  }
  run.operand_overlap = 0
  run.descriptor_overlap = 0
  run.write_overlap = 0
  // C0 stores over the consumed preload image, never over active DMA input.
  // A1/B1 remain in physical banks; the reload uses separate host bytes/slot0.
  run.publish(expected_memory, 3, [
    concurrent_demo_packet(LoadA, (8, 16, 0), (384, 16), (0, 0, 0)),
    concurrent_demo_packet(StoreC, (8, 8, 0), (0, 36), (0, 0, 0)),
    concurrent_demo_packet(MatMul, (8, 8, 16), (0, 0), (1, 1, 1)),
    concurrent_demo_packet(StoreC, (8, 8, 0), (640, 36), (0, 0, 1)),
  ])
  // Consumer advancement, not command retirement, makes the wrapped ring
  // slot reusable. The oldest completion remains unacknowledged meanwhile.
  run.publish(expected_memory, 7, [
    concurrent_demo_packet(Fence, (0, 0, 0), (0, 0), (0, 0, 0)),
  ])
  run.completion(128UL, 24)
  for bytes in [256UL, 0UL, 256UL, 0UL] {
    run.completion(bytes, 3)
  }
  if run.operand_overlap == 0 || run.write_overlap == 0 {
    raise DemoError::Transport("missing accepted operand DMA/compute overlap")
  }
  for
    (name, value) in [
      ("producer_count", 8UL),
      ("consumer_count", 8UL),
      ("completion_valid", 0UL),
      ("queue_occupancy", 0UL),
      ("ring_fault_valid", 0UL),
      ("halted", 0UL),
      ("transport_halted", 0UL),
      ("accepted_steps", 30UL),
      ("active_cycles", 30UL),
      ("elapsed_cycles", 31UL),
      ("stall_cycles", 0UL),
      ("capture_cycles", 64UL),
    ] {
    demo_expect(run.simulator, name, value)
  }
  if host.pending is Some(_) ||
    host.held is Some(_) ||
    host.requests != 768 ||
    host.read_bytes != 640 ||
    host.write_bytes != 512 ||
    host.request_stalls == 0 ||
    host.response_delays == 0 {
    raise DemoError::Transport("unexpected fetched concurrent transfer totals")
  }
  let expected = @flux_tile.matmul_int8_oracle(
    left,
    right,
    rows=8,
    columns=8,
    reduction=16,
  )
  concurrent_demo_check_result(host, expected_memory, expected, 8, 0, 36)
  concurrent_demo_check_result(host, expected_memory, expected, 8, 640, 36)
  for address in 0..<1024 {
    if host.memory[address] != expected_memory.memory[address] {
      raise DemoError::Transport(
        "unexpected fetched concurrent host byte at \{address}",
      )
    }
  }
  "LunaWave FluxTile fetched concurrent demo: real draft 0.2 host descriptors\n" +
  "C0=8x8 C1=8x8 signed INT8 K=16 oracle=match\n" +
  "8 ordered successful completions with duplicate caller ID=42; producer=8 consumer=8\n" +
  "accepted DMA during advancing compute/capture: operand_read_edges=\{run.operand_overlap} store_write_edges=\{run.write_overlap} descriptor_read_edges=\{run.descriptor_overlap}\n" +
  "requests=768 read_bytes=640 write_bytes=512; all 1024 host bytes checked, padding preserved\n" +
  "oldest completion held for 24 cycles; ring slots reused only after consumer advancement\n" +
  "Simulation only; provisional fetched concurrent device, not hardware performance."
}
