///|
priv struct RingConcurrentDemoRun {
  host : DemoHost
  simulator : @sim.Simulator
  mut operand_overlap : Int
  mut descriptor_overlap : Int
  mut write_overlap : Int
}

///|
fn ring_concurrent_demo_prepare(host : DemoHost) -> RingConcurrentDemoRun raise {
  let simulator = @sim.Simulator::prepare(
    @flux_tile.ring_concurrent_tile(
      rows=8,
      columns=8,
      max_reduction=16,
      host_bytes=1024UL,
      ring_depth=4,
      queue_depth=8,
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
  portable_demo_put(simulator, "config_base", 32, 512UL)
  portable_demo_put(simulator, "config_valid", 1, 1UL)
  host.tick(simulator)
  portable_demo_put(simulator, "config_valid", 1, 0UL)
  host.tick(simulator)
  demo_expect(simulator, "configured", 1UL)
  {
    host,
    simulator,
    operand_overlap: 0,
    descriptor_overlap: 0,
    write_overlap: 0,
  }
}

///|
fn RingConcurrentDemoRun::tick(self : RingConcurrentDemoRun) -> Unit raise {
  let active = demo_read(self.simulator, "active_cycles")
  let capture = demo_read(self.simulator, "capture_cycles")
  let reads = self.host.read_bytes
  let writes = self.host.write_bytes
  let address = demo_read(self.simulator, "memory_request_address")
  self.host.tick(self.simulator)
  let advanced = demo_read(self.simulator, "active_cycles") > active ||
    demo_read(self.simulator, "capture_cycles") > capture
  // The host increments byte counts only on an observed accepted request.
  // Separate real operand reads from the descriptor reader's bus traffic.
  if advanced && self.host.read_bytes > reads {
    if address >= 512UL && address < 640UL {
      self.descriptor_overlap += 1
    } else {
      self.operand_overlap += 1
    }
  }
  if advanced && self.host.write_bytes > writes {
    self.write_overlap += 1
  }
}

///|
fn RingConcurrentDemoRun::publish(
  self : RingConcurrentDemoRun,
  expected_memory : DemoHost,
  sequence : Int,
  descriptors : Array[@slotted_descriptor.Descriptor],
) -> Unit raise {
  // A four-slot ring is reusable only after atomic consumer advancement.
  for _ in 0..<20000 {
    let producer = demo_read(self.simulator, "producer_count").to_int()
    let consumer = demo_read(self.simulator, "consumer_count").to_int()
    if producer == sequence &&
      producer - consumer + descriptors.length() <= 4 &&
      demo_read(self.simulator, "publish_ready") == 1UL {
      for index, descriptor in descriptors {
        let bytes = descriptor.encode()
        let address = 512 + (sequence + index) % 4 * 32
        for byte in 0..<32 {
          self.host.memory[address + byte] = bytes[byte].to_int()
          expected_memory.memory[address + byte] = bytes[byte].to_int()
        }
      }
      portable_demo_put(
        self.simulator,
        "publish_producer",
        32,
        (sequence + descriptors.length()).to_uint64(),
      )
      portable_demo_put(self.simulator, "publish_valid", 1, 1UL)
      self.tick()
      portable_demo_put(self.simulator, "publish_valid", 1, 0UL)
      return
    }
    self.tick()
  }
  raise DemoError::Timeout(id=42)
}

///|
fn RingConcurrentDemoRun::completion(
  self : RingConcurrentDemoRun,
  bytes : UInt64,
  hold_cycles : Int,
) -> Unit raise {
  for _ in 0..<20000 {
    if demo_read(self.simulator, "completion_valid") == 1UL {
      break
    }
    self.tick()
  }
  for cycle in 0..<=hold_cycles {
    demo_expect(self.simulator, "completion_valid", 1UL)
    demo_expect(self.simulator, "completion_id", 42UL)
    demo_expect(self.simulator, "completion_fault", 0UL)
    demo_expect(self.simulator, "completion_bytes_completed", bytes)
    demo_expect(self.simulator, "completion_fault_address", 0UL)
    if cycle < hold_cycles {
      self.tick()
    }
  }
  portable_demo_put(self.simulator, "completion_ready", 1, 1UL)
  self.tick()
  portable_demo_put(self.simulator, "completion_ready", 1, 0UL)
}
