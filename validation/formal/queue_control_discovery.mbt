///|
fn queue_control_binding(
  fixture : @flux_tile.QueueConservationFixture,
  role : @flux_tile.QueueConservationRole,
) -> QueueControlAlias raise FormalGateError {
  guard fixture.observations().filter(item => item.role() == role)
    is [observation] else {
    raise InvalidFormalBundleIdentity("queue control: missing/repeated role")
  }
  let signal_type = queue_role_type(role)
  if observation.signal_type() != signal_type ||
    dependency_generation_node(fixture.hardware(), observation.node()).signal_type() !=
    signal_type {
    raise InvalidFormalBundleIdentity("queue control: observation type drift")
  }
  { name: queue_role_name(role), node: observation.node(), signal_type, }
}

///|
fn queue_control_root(
  hardware : @ir.Module,
  binding : QueueControlAlias,
  clock : @ir.NodeId,
  reset : @ir.NodeId,
) -> DependencyComputeRoot raise FormalGateError {
  let original = dependency_generation_node(hardware, binding.node)
  guard original.signal_type() == binding.signal_type &&
    original.kind() is Register(spec) else {
    raise InvalidFormalBundleIdentity("queue control: non-register state")
  }
  if spec.domain() != @ir.ClockDomain::rising(clock) || spec.initial() != None {
    raise InvalidFormalBundleIdentity("queue control: state domain/initial")
  }
  guard spec.reset() is Some(control) &&
    control.signal() == reset &&
    control.mode() is Synchronous &&
    control.polarity() is ActiveHigh &&
    control.value() == 0UL else {
    raise InvalidFormalBundleIdentity("queue control: state reset drift")
  }
  if dependency_generation_node(hardware, spec.next()).signal_type() !=
    binding.signal_type {
    raise InvalidFormalBundleIdentity("queue control: next-state type")
  }
  if spec.enable() is Some(enable) {
    let signal_type = dependency_generation_node(hardware, enable).signal_type()
    if !signal_type.is_data() || signal_type.width().bits() != 1 {
      raise InvalidFormalBundleIdentity("queue control: enable type")
    }
  }
  {
    name: binding.name,
    node: binding.node,
    signal_type: binding.signal_type,
    spec,
  }
}

///|
fn queue_control_discover(
  fixture : @flux_tile.QueueConservationFixture,
) -> QueueControlPlan raise FormalGateError {
  let hardware = fixture.hardware()
  let expected = queue_expected_observations()
  if expected.length() != 115 || fixture.observations().length() != 115 {
    raise InvalidFormalBundleIdentity("queue control: observation inventory")
  }
  for (role, _) in expected {
    ignore(queue_control_binding(fixture, role))
  }
  let clock = dependency_generation_input(hardware, "clock", Clock)
  let reset = dependency_generation_input(hardware, "reset", Reset)
  let (public_halted, raw_poison) = dependency_generation_halted(
    hardware, reset,
  )
  let state_roles : Array[@flux_tile.QueueConservationRole] = []
  for lane in 0..<4 {
    state_roles.push(FifoOccupancy(lane))
    state_roles.push(FifoResponseValid(lane))
  }
  for
    role in [
      @flux_tile.QueueConservationRole::HeadState,
      HeadEntry,
      RetirementReadPointer,
      RetirementWritePointer,
      RetirementOccupancy,
    ] {
    state_roles.push(role)
  }
  for entry in 0..<3 {
    state_roles.push(EntryValid(entry))
  }
  let roots : Array[DependencyComputeRoot] = []
  let cuts : Array[DependencyGenerationCut] = []
  let seeds : Array[@ir.NodeId] = []
  let mut state_bits = 0
  for role in state_roles {
    let root = queue_control_root(
      hardware,
      queue_control_binding(fixture, role),
      clock,
      reset,
    )
    if roots.any(previous => previous.node == root.node) {
      raise InvalidFormalBundleIdentity("queue control: aliased state roots")
    }
    roots.push(root)
    state_bits += root.signal_type.width().bits()
    dependency_generation_add_cut(hardware, cuts, root.node, root.name)
    seeds.push(root.spec.next())
    if root.spec.reset() is Some(control) {
      seeds.push(control.signal())
    }
    if root.spec.enable() is Some(enable) {
      seeds.push(enable)
    }
  }
  if roots.length() != 16 || state_bits != 37 {
    raise InvalidFormalBundleIdentity("queue control: state inventory")
  }
  dependency_generation_add_cut(hardware, cuts, reset, "reset")
  dependency_generation_add_cut(hardware, cuts, raw_poison, "raw_poison")
  for name in ["descriptor_valid", "completion_ready"] {
    let node = dependency_generation_input(
      hardware,
      name,
      queue_public_port_type(name, 1),
    )
    dependency_generation_add_cut(hardware, cuts, node, name)
  }
  // Explicit data abstraction: finish is the actual combinational event,
  // consumed by the ORIGINAL Dispatch-state guard, not an injected state.
  let finish = queue_control_binding(fixture, HeadFinish)
  if dependency_generation_node(hardware, finish.node).kind() is Register(_) ||
    dependency_generation_node(hardware, finish.node).kind() is Input(_) {
    raise InvalidFormalBundleIdentity(
      "queue control: finish event is not derived",
    )
  }
  dependency_generation_add_cut(hardware, cuts, finish.node, finish.name)
  for entry in 0..<3 {
    let terminal = queue_control_binding(fixture, EntryTerminal(entry))
    guard dependency_generation_node(hardware, terminal.node).kind()
      is Register(_) else {
      raise InvalidFormalBundleIdentity("queue control: terminal data boundary")
    }
    dependency_generation_add_cut(hardware, cuts, terminal.node, terminal.name)
  }
  let events : Array[QueueControlAlias] = []
  for lane in 0..<4 {
    // Never collapse independently generated lane events into one ghost fire.
    for
      role in [
        @flux_tile.QueueConservationRole::FifoPushValid(lane),
        FifoPushReady(lane),
        FifoPopRequest(lane),
        FifoPopReady(lane),
        FifoFull(lane),
        FifoEmpty(lane),
      ] {
      events.push(queue_control_binding(fixture, role))
    }
  }
  for
    role in [
      @flux_tile.QueueConservationRole::HeadPop,
      HeadCapture,
      HeadReserve,
      RetirementValid,
      RetirementFire,
    ] {
    events.push(queue_control_binding(fixture, role))
  }
  // This raw data input is not itself the state-masked effective finish.
  events.push({ ..finish, name: "dispatch_finish_raw", })
  for entry in 0..<3 {
    for
      role in [
        @flux_tile.QueueConservationRole::EntryAllocate(entry),
        EntryAcknowledge(entry),
      ] {
      events.push(queue_control_binding(fixture, role))
    }
  }
  let ready = hardware
    .outputs()
    .filter(output => output.name() == "descriptor_ready")
  guard ready is [output] &&
    output.signal_type() == queue_public_port_type("descriptor_ready", 1) else {
    raise InvalidFormalBundleIdentity(
      "queue control: public admission boundary",
    )
  }
  events.push({
    name: "descriptor_ready",
    node: output.driver(),
    signal_type: output.signal_type(),
  })
  events.push({
    name: "public_halted",
    node: public_halted,
    signal_type: dependency_generation_node(hardware, public_halted).signal_type(),
  })
  if cuts.length() != 24 ||
    cuts.filter(cut => !roots.any(root => root.node == cut.node)).length() != 8 {
    raise InvalidFormalBundleIdentity("queue control: free boundary inventory")
  }
  for event in events {
    seeds.push(event.node)
  }
  // This rejects any OTHER register, input, or memory-read leaf. Only the
  // named data boundaries can hide production logic; control events cannot.
  let cone = dependency_generation_closure(hardware, cuts, seeds)
  for event in events {
    if event.node != finish.node &&
      (
        cuts.any(cut => cut.node == event.node) ||
        !cone.any(node => node.id() == event.node)
      ) {
      raise InvalidFormalBundleIdentity("queue control: derived event shadowed")
    }
  }
  {
    roots: ReadOnlyArray::from_array(roots),
    cuts: ReadOnlyArray::from_array(cuts),
    cone: ReadOnlyArray::from_array(cone),
    events: ReadOnlyArray::from_array(events),
    clock,
    reset,
  }
}
