///|
priv struct FetchedPacketNative {
  source : @ir.Module
  aliases : Array[QueueControlAlias]
  words : Array[Array[UInt64]]
  mut expected : Array[UInt64]
  mut read_pointer : Int32
  mut write_pointer : Int32
  mut count : Int32
  mut phase : Int32
}

///|
fn FetchedPacketNative::new(source : @ir.Module) -> FetchedPacketNative raise {
  {
    source,
    aliases: fetched_retirement_aliases(source),
    words: [[], []],
    expected: [],
    read_pointer: 0,
    write_pointer: 0,
    count: 0,
    phase: 0,
  }
}

///|
fn FetchedPacketNative::role(
  self : FetchedPacketNative,
  simulator : @sim.Simulator,
  role : @flux_tile.QueueConservationRole,
) -> UInt64 raise {
  guard self.aliases.filter(binding => {
      binding.name == "composition_queue_" + queue_role_name(role)
    })
    is [binding] else {
    fail("missing packet role")
  }
  let value = simulator.value(binding.node)
  assert_true(value.is_fully_known())
  value.to_uint64()
}

///|
fn FetchedPacketNative::step(
  self : FetchedPacketNative,
  simulator : @sim.Simulator,
  reset : Bool,
) -> Unit raise {
  if reset {
    self.read_pointer = 0
    self.write_pointer = 0
    self.count = 0
    self.phase = 0
    return
  }
  let pop = self.role(simulator, HeadPop) == 1UL
  let memories = self.source
    .memories()
    .filter(memory => memory.name().has_prefix("descriptor_lane_"))
  assert_eq(memories.length(), 4)
  let push = simulator
    .value(memories[0].write_ports()[0].enable().unwrap())
    .to_uint64() ==
    1UL
  if pop {
    assert_true(self.count > 0)
    self.expected = self.words[self.read_pointer].copy()
    self.read_pointer = 1 - self.read_pointer
  }
  if push {
    assert_true(self.count < 2 || pop)
    let packet : Array[UInt64] = []
    for memory in memories {
      packet.push(simulator.value(memory.write_ports()[0].data()).to_uint64())
    }
    self.words[self.write_pointer] = packet
    self.write_pointer = 1 - self.write_pointer
  }
  self.count += (if push { 1 } else { 0 }) - (if pop { 1 } else { 0 })
  self.phase = match self.phase {
    0 if pop => 1
    1 if self.role(simulator, HeadCapture) == 1UL => 2
    2 if self.role(simulator, HeadReserve) == 1UL => 3
    3 if self.role(simulator, HeadFinish) == 1UL => 0
    _ => self.phase
  }
}

///|
fn FetchedPacketNative::check(
  self : FetchedPacketNative,
  simulator : @sim.Simulator,
) -> Unit raise {
  assert_eq(self.role(simulator, HeadState), self.phase.to_uint64())
  assert_true(self.count >= 0 && self.count <= 2)
  for lane in 0..<4 {
    guard self.source
      .memories()
      .filter(memory => memory.name() == "descriptor_lane_\{lane}.storage")
      is [memory] else {
      fail("missing lane")
    }
    assert_eq(
      simulator.value(memory.read_ports()[0].address()).to_uint64(),
      self.read_pointer.to_uint64(),
    )
    assert_eq(
      simulator.value(memory.write_ports()[0].address()).to_uint64(),
      self.write_pointer.to_uint64(),
    )
    assert_eq(self.role(simulator, FifoOccupancy(lane)), self.count.to_uint64())
    assert_eq(
      self.role(simulator, FifoResponseValid(lane)),
      if self.phase == 1 {
        1UL
      } else {
        0UL
      },
    )
    for rank in 0..<self.count {
      let slot = (self.read_pointer + rank) % 2
      let value = simulator.memory_cell(memory.name(), slot)
      assert_true(value.is_fully_known())
      assert_eq(value.to_uint64(), self.words[slot][lane])
    }
    if self.phase == 1 {
      assert_eq(
        self.role(simulator, FifoResponseData(lane)),
        self.expected[lane],
      )
    }
    if self.phase >= 2 {
      assert_eq(self.role(simulator, HeadLane(lane)), self.expected[lane])
    }
  }
}
