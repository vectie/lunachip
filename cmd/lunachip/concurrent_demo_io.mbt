///|
priv struct ConcurrentDemoRun {
  host : DemoHost
  simulator : @sim.Simulator
  mut read_overlap : Int32
  mut write_overlap : Int32
}

///|
fn concurrent_demo_prepare(host : DemoHost) -> ConcurrentDemoRun raise {
  let simulator = @sim.Simulator::prepare(
    @flux_tile.queued_concurrent_tile(
      rows=8,
      columns=8,
      max_reduction=8,
      host_bytes=1024UL,
      queue_depth=8,
    ),
  )
  for
    (name, width) in [
      ("reset", 1),
      ("descriptor_valid", 1),
      ("completion_ready", 1),
      ("memory_request_ready", 1),
      ("memory_response_valid", 1),
      ("memory_response_tag", 32),
      ("memory_response_fault", 2),
      ("memory_response_data", 32),
    ] {
    portable_demo_put(simulator, name, width, 0UL)
  }
  for lane in 0..<4 {
    portable_demo_put(simulator, "descriptor_lane_\{lane}", 64, 0UL)
  }
  portable_demo_put(simulator, "reset", 1, 1UL)
  simulator.rising_edge("clock")
  portable_demo_put(simulator, "reset", 1, 0UL)
  demo_expect(simulator, "descriptor_ready", 1UL)
  { host, simulator, read_overlap: 0, write_overlap: 0, }
}

///|
fn ConcurrentDemoRun::tick(self : ConcurrentDemoRun) -> Unit raise {
  let active = demo_read(self.simulator, "active_cycles")
  let capture = demo_read(self.simulator, "capture_cycles")
  let reads = self.host.read_bytes
  let writes = self.host.write_bytes
  self.host.tick(self.simulator)
  let advanced = demo_read(self.simulator, "active_cycles") > active ||
    demo_read(self.simulator, "capture_cycles") > capture
  // DemoHost advances byte counts only for observed accepted requests.
  // Count an overlap only if that same rising edge advanced the real core.
  if advanced && self.host.read_bytes > reads {
    self.read_overlap += 1
  }
  if advanced && self.host.write_bytes > writes {
    self.write_overlap += 1
  }
}

///|
fn ConcurrentDemoRun::enqueue(
  self : ConcurrentDemoRun,
  descriptor : @slotted_descriptor.Descriptor,
) -> Unit raise {
  let bytes = descriptor.encode()
  for lane in 0..<4 {
    let mut bits = 0UL
    for byte in 0..<8 {
      bits = bits | (bytes[lane * 8 + byte].to_uint64() << (byte * 8))
    }
    portable_demo_put(self.simulator, "descriptor_lane_\{lane}", 64, bits)
  }
  portable_demo_put(self.simulator, "descriptor_valid", 1, 1UL)
  for _ in 0..<20000 {
    if demo_read(self.simulator, "descriptor_ready") == 1UL {
      self.tick()
      portable_demo_put(self.simulator, "descriptor_valid", 1, 0UL)
      return
    }
    self.tick()
  }
  raise DemoError::Timeout(id=42)
}

///|
fn ConcurrentDemoRun::completion(
  self : ConcurrentDemoRun,
  bytes : UInt64,
  hold_cycles : Int32,
) -> Int32 raise {
  for _ in 0..<20000 {
    if demo_read(self.simulator, "completion_valid") == 1UL {
      break
    }
    self.tick()
  }
  if demo_read(self.simulator, "completion_valid") != 1UL {
    raise DemoError::Timeout(id=42)
  }
  let writes = self.host.write_bytes
  for _ in 0..<hold_cycles {
    self.check_completion(bytes)
    self.tick()
  }
  self.check_completion(bytes)
  let held_write_bytes = self.host.write_bytes - writes
  portable_demo_put(self.simulator, "completion_ready", 1, 1UL)
  self.tick()
  portable_demo_put(self.simulator, "completion_ready", 1, 0UL)
  // An already terminal next entry may be visible immediately after ACK.
  // Do not insert a serial-engine completion bubble into ordered retirement.
  held_write_bytes
}

///|
fn ConcurrentDemoRun::check_completion(
  self : ConcurrentDemoRun,
  bytes : UInt64,
) -> Unit raise {
  demo_expect(self.simulator, "completion_valid", 1UL)
  demo_expect(self.simulator, "completion_id", 42UL)
  demo_expect(self.simulator, "completion_fault", 0UL)
  demo_expect(self.simulator, "completion_bytes_completed", bytes)
  demo_expect(self.simulator, "completion_fault_address", 0UL)
}
