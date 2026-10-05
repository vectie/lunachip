///|
fn dependency_generation_validate_bindings(
  hardware : @ir.Module,
  bindings : ArrayView[DependencyGenerationBinding],
) -> Unit raise FormalGateError {
  let expected = dependency_expected_observations()
  if bindings.length() != expected.length() {
    raise InvalidFormalBundleIdentity("generation discovery: observation count")
  }
  for index, binding in bindings {
    let (role, width) = expected[index]
    let actual = dependency_generation_node(hardware, binding.node)
    if binding.role != role ||
      binding.signal_type.width().bits() != width ||
      actual.signal_type() != binding.signal_type {
      raise InvalidFormalBundleIdentity(
        "generation discovery: exact observation binding drift",
      )
    }
  }
}

///|
fn dependency_generation_input(
  hardware : @ir.Module,
  name : String,
  expected : @ir.SignalType,
) -> @ir.NodeId raise FormalGateError {
  let matching = hardware
    .nodes()
    .iter()
    .filter(node => node.kind() is Input(actual) && actual == name)
    .to_array()
  guard matching is [node] && node.signal_type() == expected else {
    raise InvalidFormalBundleIdentity("generation discovery: input " + name)
  }
  node.id()
}

///|
fn dependency_generation_halted(
  hardware : @ir.Module,
  reset : @ir.NodeId,
) -> (@ir.NodeId, @ir.NodeId) raise FormalGateError {
  let outputs = hardware
    .outputs()
    .iter()
    .filter(output => output.name() == "halted")
    .to_array()
  guard outputs is [output] else {
    raise InvalidFormalBundleIdentity("generation discovery: halted output")
  }
  let node = dependency_generation_node(hardware, output.driver())
  if output.signal_type() != node.signal_type() ||
    !(node.signal_type() is Bits(width) && width.bits() == 1) {
    raise InvalidFormalBundleIdentity("generation discovery: halted type")
  }
  guard node.kind() is BitAnd(inactive, raw) else {
    raise InvalidFormalBundleIdentity(
      "generation discovery: halted alias shape",
    )
  }
  guard dependency_generation_node(hardware, inactive).kind()
    is BitNot(asserted) &&
    dependency_generation_node(hardware, asserted).kind() is Reinterpret(source) &&
    source == reset else {
    raise InvalidFormalBundleIdentity(
      "generation discovery: reset-inactive alias",
    )
  }
  if !(dependency_generation_node(hardware, raw).signal_type() is Bits(width) &&
    width.bits() == 1) {
    raise InvalidFormalBundleIdentity("generation discovery: raw poison type")
  }
  // Publication and local fault consume raw; public halted is derived, never
  // a second independently free input. Raw may itself be reset-aware upstream.
  (output.driver(), raw)
}

///|
fn dependency_generation_root(
  hardware : @ir.Module,
  binding : DependencyGenerationBinding,
  clock : @ir.NodeId,
  reset : @ir.NodeId,
) -> DependencyGenerationRoot raise FormalGateError {
  let node = dependency_generation_node(hardware, binding.node)
  guard node.kind() is Register(spec) else {
    raise InvalidFormalBundleIdentity("generation discovery: non-register root")
  }
  let expected_width = match binding.role {
    WriterStatus(_) | DependencyStatus(_) => 2
    NextTicket | HeadTicket | WriterTicket(_) | DependencyTicket(_) => 32
    _ =>
      raise InvalidFormalBundleIdentity("generation discovery: non-state role")
  }
  if node.signal_type() != binding.signal_type ||
    !(node.signal_type() is UInt(width) && width.bits() == expected_width) ||
    spec.domain() != @ir.ClockDomain::rising(clock) ||
    spec.initial() != None {
    raise InvalidFormalBundleIdentity("generation discovery: state type/domain")
  }
  guard spec.reset() is Some(control) &&
    control.signal() == reset &&
    control.mode() is Synchronous &&
    control.polarity() is ActiveHigh &&
    control.value() == 0UL else {
    raise InvalidFormalBundleIdentity("generation discovery: state reset drift")
  }
  if dependency_generation_node(hardware, spec.next()).signal_type() !=
    node.signal_type() {
    raise InvalidFormalBundleIdentity("generation discovery: next-state type")
  }
  if spec.enable() is Some(enable) {
    let enable_type = dependency_generation_node(hardware, enable).signal_type()
    if !enable_type.is_data() || enable_type.width().bits() != 1 {
      raise InvalidFormalBundleIdentity("generation discovery: enable type")
    }
  }
  { binding, spec, }
}

///|
fn dependency_generation_add_cut(
  hardware : @ir.Module,
  cuts : Array[DependencyGenerationCut],
  id : @ir.NodeId,
  role : String,
) -> Unit raise FormalGateError {
  let node = dependency_generation_node(hardware, id)
  for index, cut in cuts {
    if cut.node == id {
      let roles = cut.roles.iter().to_array()
      roles.push(role)
      cuts[index] = { ..cut, roles: ReadOnlyArray::from_array(roles), }
      return
    }
  }
  cuts.push({
    node: id,
    signal_type: node.signal_type(),
    roles: ReadOnlyArray::from_array([role]),
  })
}

///|
// The secondary entry accepts exact typed bindings for corruption tests only.
// A role/type table is not evidence that a substituted binding is authoritative.
fn dependency_generation_plan(
  hardware : @ir.Module,
  bindings : ArrayView[DependencyGenerationBinding],
) -> DependencyGenerationPlan raise FormalGateError {
  dependency_generation_validate_bindings(hardware, bindings)
  let clock = dependency_generation_input(hardware, "clock", Clock)
  let reset = dependency_generation_input(hardware, "reset", Reset)
  let (public_halted, raw_poison) = dependency_generation_halted(
    hardware, reset,
  )
  let roots : Array[DependencyGenerationRoot] = []
  let cuts : Array[DependencyGenerationCut] = []
  let seeds : Array[@ir.NodeId] = []
  let mut bits = 0
  for role in dependency_generation_state_roles() {
    let binding = dependency_generation_binding(bindings, role)
    if roots.any(root => root.binding.node == binding.node) {
      raise InvalidFormalBundleIdentity(
        "generation discovery: aliased state roots",
      )
    }
    let root = dependency_generation_root(hardware, binding, clock, reset)
    bits += binding.signal_type.width().bits()
    roots.push(root)
    dependency_generation_add_cut(
      hardware,
      cuts,
      binding.node,
      dependency_role_name(role),
    )
    seeds.push(root.spec.next())
    if root.spec.reset() is Some(control) {
      seeds.push(control.signal())
    }
    if root.spec.enable() is Some(enable) {
      seeds.push(enable)
    }
  }
  if roots.length() != 18 || bits != 336 {
    raise InvalidFormalBundleIdentity("generation discovery: state inventory")
  }
  dependency_generation_add_cut(hardware, cuts, reset, "reset")
  dependency_generation_add_cut(hardware, cuts, raw_poison, "raw_poison")
  for role in dependency_generation_boundary_roles() {
    let binding = dependency_generation_binding(bindings, role)
    dependency_generation_add_cut(
      hardware,
      cuts,
      binding.node,
      dependency_role_name(role),
    )
  }
  let local_fault = dependency_generation_binding(bindings, LocalFault).node
  let local_reject = dependency_generation_binding(bindings, LocalReject).node
  guard dependency_generation_node(hardware, local_fault).kind()
    is Mux(select~, when_true~, ..) &&
    select == raw_poison &&
    dependency_generation_node(hardware, when_true).kind() is Constant(15UL) else {
    raise InvalidFormalBundleIdentity(
      "generation discovery: local-fault poison alias",
    )
  }
  if cuts.any(cut => cut.node == local_fault || cut.node == local_reject) {
    raise InvalidFormalBundleIdentity("generation discovery: oracle output cut")
  }
  seeds.push(local_fault)
  seeds.push(local_reject)
  seeds.push(public_halted)
  let cone = dependency_generation_closure(hardware, cuts, seeds)
  let decoder_bindings = dependency_generation_decoder_bindings(
    hardware, bindings, local_fault, raw_poison,
  ) catch {
    InvalidFormalBundleIdentity(message) =>
      raise InvalidFormalBundleIdentity(message)
    error =>
      raise InvalidFormalBundleIdentity("generation decoder: \{Repr(error)}")
  }
  for binding in decoder_bindings {
    if cuts.any(cut => cut.node == binding.node) ||
      !cone.any(node => node.id() == binding.node) {
      raise InvalidFormalBundleIdentity(
        "generation decoder: projection outside exact cone",
      )
    }
  }
  {
    roots: ReadOnlyArray::from_array(roots),
    cuts: ReadOnlyArray::from_array(cuts),
    cone: ReadOnlyArray::from_array(cone),
    local_fault,
    local_reject,
    clock,
    reset,
    public_halted,
    raw_poison,
    decoder_bindings: ReadOnlyArray::from_array(decoder_bindings),
  }
}

///|
fn dependency_generation_discover(
  fixture : @flux_tile.QueuedConcurrentFormalFixture,
) -> DependencyGenerationPlan raise FormalGateError {
  dependency_generation_plan(
    fixture.hardware(),
    dependency_generation_bindings(fixture),
  )
}
