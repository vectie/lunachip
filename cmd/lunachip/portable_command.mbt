///|
fn portable_demo_prepare() -> @sim.Simulator raise {
  let simulator = @sim.Simulator::prepare(
    @flux_tile.portable_tile(
      rows=2,
      columns=3,
      max_reduction=3,
      host_bytes=1024UL,
    ),
  )
  for
    (name, width) in [
      ("reset", 1),
      ("command_valid", 1),
      ("command_opcode", 3),
      ("command_id", 32),
      ("command_rows", 13),
      ("command_columns", 13),
      ("command_reduction", 13),
      ("command_base", 32),
      ("command_stride", 32),
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
  demo_expect(simulator, "command_ready", 1UL)
  simulator
}

///|
fn DemoHost::command(
  self : DemoHost,
  simulator : @sim.Simulator,
  opcode : Int32,
  id : Int32,
  rows : Int32,
  columns : Int32,
  reduction : Int32,
  base : Int32,
  stride : Int32,
  bytes : UInt64,
) -> Unit raise {
  demo_expect(simulator, "command_ready", 1UL)
  for
    (name, width, value) in [
      ("opcode", 3, opcode),
      ("id", 32, id),
      ("rows", 13, rows),
      ("columns", 13, columns),
      ("reduction", 13, reduction),
      ("base", 32, base),
      ("stride", 32, stride),
      ("valid", 1, 1),
    ] {
    portable_demo_put(simulator, "command_" + name, width, value.to_uint64())
  }
  self.tick(simulator)
  portable_demo_put(simulator, "command_valid", 1, 0UL)
  for _ in 0..<2000 {
    if demo_read(simulator, "completion_valid") == 1UL {
      break
    }
    self.tick(simulator)
  }
  if demo_read(simulator, "completion_valid") != 1UL {
    raise DemoError::Timeout(id~)
  }
  if self.pending is Some(_) || self.held is Some(_) {
    raise DemoError::Transport("completion preceded retirement of memory work")
  }
  let requests = self.requests
  for held in 0..<3 {
    demo_expect(simulator, "completion_valid", 1UL)
    demo_expect(simulator, "completion_id", id.to_uint64())
    demo_expect(simulator, "completion_fault", 0UL)
    demo_expect(simulator, "completion_bytes_completed", bytes)
    demo_expect(simulator, "completion_fault_address", 0UL)
    demo_expect(simulator, "command_ready", 0UL)
    demo_expect(simulator, "memory_request_valid", 0UL)
    if self.requests != requests {
      raise DemoError::Transport("held completion issued memory work")
    }
    if held < 2 {
      self.tick(simulator)
    }
  }
  portable_demo_put(simulator, "completion_ready", 1, 1UL)
  self.tick(simulator)
  portable_demo_put(simulator, "completion_ready", 1, 0UL)
  demo_expect(simulator, "completion_valid", 0UL)
  demo_expect(simulator, "command_ready", 1UL)
}
