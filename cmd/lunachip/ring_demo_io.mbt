///|
fn ring_demo_prepare() -> @sim.Simulator raise {
  let simulator = @sim.Simulator::prepare(
    @flux_tile.ring_tile(
      rows=2,
      columns=3,
      max_reduction=3,
      host_bytes=1024UL,
      ring_depth=8,
      queue_depth=3,
    ),
  )
  for
    (name, width) in [
      ("reset", 1),
      ("config_valid", 1),
      ("config_base", 32),
      ("config_origin", 32),
      ("publish_valid", 1),
      ("publish_producer", 32),
      ("completion_ready", 1),
      ("memory_request_ready", 1),
      ("memory_response_valid", 1),
      ("memory_response_tag", 32),
      ("memory_response_fault", 2),
      ("memory_response_data", 32),
    ] {
    portable_demo_put(simulator, name, width, 0UL)
  }
  portable_demo_put(simulator, "reset", 1, 1UL)
  simulator.rising_edge("clock")
  portable_demo_put(simulator, "reset", 1, 0UL)
  demo_expect(simulator, "config_ready", 1UL)
  simulator
}

///|
fn ring_demo_seed_descriptors(host : DemoHost) -> Unit raise {
  let commands : Array[@descriptor.Descriptor] = [
    {
      opcode: LoadA,
      id: 1U,
      rows: 2U,
      columns: 3U,
      reduction: 0U,
      base: 32U,
      stride: 8U,
    },
    {
      opcode: LoadB,
      id: 2U,
      rows: 3U,
      columns: 3U,
      reduction: 0U,
      base: 128U,
      stride: 8U,
    },
    {
      opcode: MatMul,
      id: 3U,
      rows: 2U,
      columns: 3U,
      reduction: 3U,
      base: 0U,
      stride: 0U,
    },
    {
      opcode: StoreC,
      id: 4U,
      rows: 2U,
      columns: 3U,
      reduction: 0U,
      base: 256U,
      stride: 16U,
    },
    {
      opcode: Fence,
      id: 5U,
      rows: 0U,
      columns: 0U,
      reduction: 0U,
      base: 0U,
      stride: 0U,
    },
  ]
  for slot, descriptor in commands {
    let bytes = descriptor.encode()
    for byte in 0..<32 {
      host.memory[512 + slot * 32 + byte] = bytes[byte].to_int()
    }
  }
}

///|
fn ring_demo_publish(host : DemoHost, simulator : @sim.Simulator) -> Unit raise {
  portable_demo_put(simulator, "config_base", 32, 512UL)
  portable_demo_put(simulator, "config_valid", 1, 1UL)
  host.tick(simulator)
  portable_demo_put(simulator, "config_valid", 1, 0UL)
  host.tick(simulator)
  demo_expect(simulator, "configured", 1UL)
  demo_expect(simulator, "publish_ready", 1UL)
  portable_demo_put(simulator, "publish_producer", 32, 5UL)
  portable_demo_put(simulator, "publish_valid", 1, 1UL)
  host.tick(simulator)
  portable_demo_put(simulator, "publish_valid", 1, 0UL)
  demo_expect(simulator, "producer_count", 5UL)
}

///|
fn ring_demo_completion(
  host : DemoHost,
  simulator : @sim.Simulator,
  id : Int32,
  bytes : UInt64,
) -> Unit raise {
  for _ in 0..<10000 {
    if demo_read(simulator, "completion_valid") == 1UL {
      break
    }
    host.tick(simulator)
  }
  if demo_read(simulator, "completion_valid") != 1UL {
    raise DemoError::Timeout(id~)
  }
  for _ in 0..<3 {
    demo_expect(simulator, "completion_valid", 1UL)
    demo_expect(simulator, "completion_id", id.to_uint64())
    demo_expect(simulator, "completion_fault", 0UL)
    demo_expect(simulator, "completion_bytes_completed", bytes)
    demo_expect(simulator, "completion_fault_address", 0UL)
    // The reader may continue fetching into free queue slots while this
    // completion is held. Service its real memory traffic during the hold.
    host.tick(simulator)
  }
  portable_demo_put(simulator, "completion_ready", 1, 1UL)
  host.tick(simulator)
  portable_demo_put(simulator, "completion_ready", 1, 0UL)
  demo_expect(simulator, "completion_valid", 0UL)
}
