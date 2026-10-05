///|
fn concurrent_demo_packet(
  opcode : @descriptor.Opcode,
  shape : (Int, Int, Int),
  address : (Int, Int),
  slots : (Int, Int, Int),
) -> @slotted_descriptor.Descriptor {
  {
    opcode,
    id: 42U,
    rows: shape.0.reinterpret_as_uint(),
    columns: shape.1.reinterpret_as_uint(),
    reduction: shape.2.reinterpret_as_uint(),
    base: address.0.reinterpret_as_uint(),
    stride: address.1.reinterpret_as_uint(),
    a_slot: slots.0.reinterpret_as_uint(),
    b_slot: slots.1.reinterpret_as_uint(),
    c_slot: slots.2.reinterpret_as_uint(),
  }
}

///|
fn concurrent_demo_seed(
  host : DemoHost,
  left : Array[Int],
  right : Array[Int],
) -> Unit {
  host.seed(32, 8, 2, 3, [1, -2, 3, -128, 4, 127])
  host.seed(128, 8, 3, 3, [5, -6, 7, 8, 9, -10, -11, 12, 13])
  host.seed(192, 10, 8, 8, left)
  host.seed(288, 10, 8, 8, right)
  host.seed(384, 10, 8, 8, Array::makei(64, index => index - 32))
}

///|
fn concurrent_demo_check_result(
  host : DemoHost,
  expected_memory : DemoHost,
  expected : Array[Int],
  columns : Int,
  base : Int,
  stride : Int,
) -> Unit raise {
  for index, value in expected {
    let address = base + index / columns * stride + index % columns * 4
    let actual = host.word(address)
    if actual != value {
      raise DemoError::UnexpectedResult(index~, expected=value, actual~)
    }
    let bits = (value.to_int64() & 0xffffffffL).reinterpret_as_uint64()
    for byte in 0..<4 {
      expected_memory.memory[address + byte] = ((bits >> (byte * 8)) & 255UL).to_int()
    }
  }
}

///|
fn concurrent_demo() -> String raise {
  let left = Array::makei(64, index => (index / 8 * 7 + index % 8 * 3) % 19 - 9)
  let right = Array::makei(64, index => {
    (index / 8 * 5 + index % 8 * 11) % 23 - 11
  })
  let host = DemoHost::new()
  concurrent_demo_seed(host, left, right)
  let run = concurrent_demo_prepare(host)
  // Establish C0 and successfully loaded A1/B1 before the overlap phase.
  for
    packet in [
      concurrent_demo_packet(LoadA, (2, 3, 0), (32, 8), (0, 0, 0)),
      concurrent_demo_packet(LoadB, (3, 3, 0), (128, 8), (0, 0, 0)),
      concurrent_demo_packet(MatMul, (2, 3, 3), (0, 0), (0, 0, 0)),
      concurrent_demo_packet(LoadA, (8, 8, 0), (192, 10), (1, 0, 0)),
      concurrent_demo_packet(LoadB, (8, 8, 0), (288, 10), (0, 1, 0)),
    ] {
    run.enqueue(packet)
  }
  for bytes in [6UL, 9UL, 0UL, 64UL, 64UL] {
    ignore(run.completion(bytes, 3))
  }
  run.read_overlap = 0
  run.write_overlap = 0
  // Strict dispatch may launch unrelated engines while earlier work remains
  // active. A0 reload, C0 store and A1/B1->C1 computation do not alias.
  for
    packet in [
      concurrent_demo_packet(LoadA, (8, 8, 0), (384, 10), (0, 0, 0)),
      concurrent_demo_packet(StoreC, (2, 3, 0), (512, 16), (0, 0, 0)),
      concurrent_demo_packet(MatMul, (8, 8, 8), (0, 0), (1, 1, 1)),
      concurrent_demo_packet(StoreC, (8, 8, 0), (640, 36), (0, 0, 1)),
      concurrent_demo_packet(Fence, (0, 0, 0), (0, 0), (0, 0, 0)),
    ] {
    run.enqueue(packet)
  }
  let held_write_bytes = run.completion(64UL, 24)
  for bytes in [24UL, 0UL, 256UL, 0UL] {
    ignore(run.completion(bytes, 3))
  }
  if run.read_overlap == 0 || run.write_overlap == 0 || held_write_bytes == 0 {
    raise DemoError::Transport(
      "missing observed DMA/compute overlap or held-retirement progress",
    )
  }
  for
    (name, value) in [
      ("completion_valid", 0UL),
      ("queue_occupancy", 0UL),
      ("halted", 0UL),
      ("transport_halted", 0UL),
      ("accepted_steps", 22UL),
      ("active_cycles", 22UL),
      ("elapsed_cycles", 23UL),
      ("stall_cycles", 0UL),
      ("capture_cycles", 64UL),
    ] {
    demo_expect(run.simulator, name, value)
  }
  if host.pending is Some(_) ||
    host.held is Some(_) ||
    host.requests != 277 ||
    host.read_bytes != 207 ||
    host.write_bytes != 280 ||
    host.request_stalls == 0 ||
    host.response_delays == 0 {
    raise DemoError::Transport(
      "unexpected concurrent transaction counts or unretired work",
    )
  }
  let old_result = @flux_tile.matmul_int8_oracle(
    [1, -2, 3, -128, 4, 127],
    [5, -6, 7, 8, 9, -10, -11, 12, 13],
    rows=2,
    columns=3,
    reduction=3,
  )
  let new_result = @flux_tile.matmul_int8_oracle(
    left,
    right,
    rows=8,
    columns=8,
    reduction=8,
  )
  let expected_memory = DemoHost::new()
  concurrent_demo_seed(expected_memory, left, right)
  concurrent_demo_check_result(host, expected_memory, old_result, 3, 512, 16)
  concurrent_demo_check_result(host, expected_memory, new_result, 8, 640, 36)
  for address in 0..<1024 {
    if host.memory[address] != expected_memory.memory[address] {
      raise DemoError::Transport(
        "unexpected concurrent host byte at address \{address}",
      )
    }
  }
  "LunaWave FluxTile concurrent demo: draft 0.2 packets with bounded ordered retirement\n" +
  "C0=[-44, 12, 66; -2005, 2328, 715]; C1=8x8 oracle=match\n" +
  "10 ordered successful completions with duplicate caller ID=42\n" +
  "observed DMA/compute overlap: read_edges=\{run.read_overlap} write_edges=\{run.write_overlap}\n" +
  "oldest completion held for 24 cycles; later stores committed \{held_write_bytes} bytes during hold\n" +
  "requests=277 read_bytes=207 write_bytes=280; all 1024 host bytes checked, padding preserved\n" +
  "modeled compute cycles=23 active=22 capture=64; transport backpressure and delayed responses exercised\n" +
  "Simulation only; provisional queued concurrent engine, not hardware performance."
}
