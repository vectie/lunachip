///|
// Validate an exact authoritative source record, including memory-port and
// register controls. The separate entry point permits fail-closed tests.
fn queue_storage_validate_lane(
  hardware : @ir.Module,
  lane : QueueStorageLane,
  clock : @ir.NodeId,
  reset : @ir.NodeId,
) -> Unit raise FormalGateError {
  if lane.lane < 0 || lane.lane >= 4 {
    raise InvalidFormalBundleIdentity("queue storage probe: lane range")
  }
  guard hardware.memories().filter(memory => memory.id() == lane.memory.id())
    is [original] &&
    original == lane.memory else {
    raise InvalidFormalBundleIdentity(
      "queue storage probe: memory source drift",
    )
  }
  let domain = @ir.ClockDomain::rising(clock)
  let packet_type = queue_role_type(FifoResponseData(lane.lane))
  let pointer_type = queue_role_type(FifoOccupancy(lane.lane))
  if lane.memory.element_type() != packet_type ||
    lane.memory.depth().elements() != 3 ||
    lane.memory.domain() != domain ||
    !(lane.memory.read_write_policy() is ReadOld) ||
    !(lane.memory.multi_write_policy() is Reject) ||
    !(lane.memory.bounds_policy() is Fault) ||
    lane.memory.read_ports().length() != 1 ||
    lane.memory.write_ports().length() != 1 ||
    lane.memory.read_ports()[0] != lane.read ||
    lane.memory.write_ports()[0] != lane.write {
    raise InvalidFormalBundleIdentity(
      "queue storage probe: storage policy/ports",
    )
  }
  if lane.read.domain() != domain ||
    lane.write.domain() != domain ||
    !(lane.read.latency() is OneCycle) ||
    !(lane.read.enable_behavior() is HoldLast) ||
    !(lane.write.mask() is All) ||
    lane.read.enable() is None ||
    lane.write.enable() is None {
    raise InvalidFormalBundleIdentity("queue storage probe: port semantics")
  }
  guard lane.result == dependency_generation_node(hardware, lane.result.id()) &&
    lane.result.signal_type() == packet_type &&
    lane.result.kind() is MemoryRead(memory~, port~) &&
    memory == lane.memory.id() &&
    port == lane.read.id() &&
    lane.read.result() == lane.result.id() else {
    raise InvalidFormalBundleIdentity(
      "queue storage probe: original read identity",
    )
  }
  let public_data = dependency_generation_input(
    hardware,
    "descriptor_lane_\{lane.lane}",
    packet_type,
  )
  if lane.public_data != public_data ||
    lane.write.data() != public_data ||
    lane.read.address() != lane.read_pointer.node ||
    lane.write.address() != lane.write_pointer.node ||
    lane.read_pointer.node == lane.write_pointer.node {
    raise InvalidFormalBundleIdentity(
      "queue storage probe: address/data identity",
    )
  }
  for root in [lane.read_pointer, lane.write_pointer] {
    if root.signal_type != pointer_type ||
      queue_control_root(
        hardware,
        { name: root.name, node: root.node, signal_type: root.signal_type, },
        clock,
        reset,
      ) !=
      root {
      raise InvalidFormalBundleIdentity(
        "queue storage probe: pointer source drift",
      )
    }
  }
}

///|
// Resolve storage from the typed actual response, never a guessed memory ID,
// storage name or register ordinal. Public port names remain contract names.
fn queue_storage_lane(
  fixture : @flux_tile.QueueConservationFixture,
  lane : Int32,
  clock : @ir.NodeId,
  reset : @ir.NodeId,
) -> QueueStorageLane raise FormalGateError {
  if lane < 0 || lane >= 4 {
    raise InvalidFormalBundleIdentity("queue storage probe: lane range")
  }
  let hardware = fixture.hardware()
  let response = queue_control_binding(fixture, FifoResponseData(lane))
  let result = dependency_generation_node(hardware, response.node)
  guard result.kind() is MemoryRead(memory~, port~) &&
    hardware.memories().filter(spec => spec.id() == memory) is [spec] &&
    spec.read_ports().filter(read => read.id() == port) is [read] &&
    spec.write_ports() is [write] else {
    raise InvalidFormalBundleIdentity(
      "queue storage probe: typed response storage",
    )
  }
  let pointer = (name : String, node : @ir.NodeId) => {
    queue_control_root(
      hardware,
      { name, node, signal_type: queue_role_type(FifoOccupancy(lane)), },
      clock,
      reset,
    )
  }
  let discovered : QueueStorageLane = {
    lane,
    memory: spec,
    read,
    write,
    result,
    read_pointer: pointer("fifo_read_pointer_\{lane}", read.address()),
    write_pointer: pointer("fifo_write_pointer_\{lane}", write.address()),
    public_data: dependency_generation_input(
      hardware,
      "descriptor_lane_\{lane}",
      queue_role_type(FifoResponseData(lane)),
    ),
  }
  queue_storage_validate_lane(hardware, discovered, clock, reset)
  guard read.enable() is Some(pop_fire) &&
    write.enable() is Some(push_fire) &&
    dependency_generation_node(hardware, pop_fire).kind() is BitAnd(pop, ready) &&
    pop == queue_control_binding(fixture, FifoPopRequest(lane)).node &&
    ready == queue_control_binding(fixture, FifoPopReady(lane)).node &&
    dependency_generation_node(hardware, push_fire).kind()
    is BitAnd(push, accept) &&
    push == queue_control_binding(fixture, FifoPushValid(lane)).node &&
    accept == queue_control_binding(fixture, FifoPushReady(lane)).node else {
    raise InvalidFormalBundleIdentity("queue storage probe: actual port fires")
  }
  let response_valid = queue_control_root(
    hardware,
    queue_control_binding(fixture, FifoResponseValid(lane)),
    clock,
    reset,
  )
  let head = queue_control_root(
    hardware,
    queue_control_binding(fixture, HeadLane(lane)),
    clock,
    reset,
  )
  guard response_valid.spec.next() == pop_fire &&
    head.spec.enable() is None &&
    dependency_generation_node(hardware, head.spec.next()).kind()
    is Mux(select~, when_true~, when_false~) &&
    select == queue_control_binding(fixture, HeadCapture).node &&
    when_true == result.id() &&
    when_false == head.node else {
    raise InvalidFormalBundleIdentity(
      "queue storage probe: response/head transfer",
    )
  }
  discovered
}
