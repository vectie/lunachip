///|
fn dependency_compute_register(
  hardware : @ir.Module,
  name : String,
  node : @ir.NodeId,
  signal_type : @ir.SignalType,
  clock : @ir.NodeId,
  reset : @ir.NodeId,
) -> DependencyComputeRoot raise FormalGateError {
  let original = dependency_generation_node(hardware, node)
  guard original.signal_type() == signal_type &&
    original.kind() is Register(spec) else {
    raise InvalidFormalBundleIdentity("compute discovery: register " + name)
  }
  guard spec.domain() == @ir.ClockDomain::rising(clock) &&
    spec.initial() == None &&
    spec.reset() is Some(control) &&
    control == @ir.ResetSpec::new(reset, 0UL) else {
    raise InvalidFormalBundleIdentity(
      "compute discovery: register controls " + name,
    )
  }
  { name, node, signal_type, spec, }
}

///|
fn dependency_compute_state_gate(
  hardware : @ir.Module,
  gate : @ir.NodeId,
  inactive : @ir.NodeId,
  value : UInt64,
) -> @ir.NodeId raise {
  let (reset_gate, comparison) = dependency_generation_decoder_and(
    hardware, gate,
  )
  if reset_gate != inactive {
    raise InvalidFormalBundleIdentity("compute discovery: reset-inactive alias")
  }
  dependency_generation_decoder_equal_constant(hardware, comparison, 2, value)
}

///|
fn dependency_compute_complement(
  hardware : @ir.Module,
  id : @ir.NodeId,
) -> @ir.NodeId raise {
  let node = dependency_generation_node(hardware, id)
  guard node.signal_type() == @wire.bits(1) && node.kind() is BitNot(source) else {
    raise InvalidFormalBundleIdentity("compute discovery: complement")
  }
  source
}

///|
// Keep the real Idle/live/conflict masks and entire dispatch-valid cone. Only
// the two raw conflict results are free cuts; no ready/accept predicate is cut.
fn dependency_compute_admission_cuts(
  hardware : @ir.Module,
  cuts : Array[DependencyGenerationCut],
  accept : @ir.NodeId,
  state : @ir.NodeId,
  inactive : @ir.NodeId,
  poison : @ir.NodeId,
  head_state : @ir.NodeId,
  local_fault : @ir.NodeId,
) -> Unit raise {
  let (ready, command_valid) = dependency_generation_decoder_and(
    hardware, accept,
  )
  let (load_masked, store_clear) = dependency_generation_decoder_and(
    hardware, ready,
  )
  let (live_masked, load_clear) = dependency_generation_decoder_and(
    hardware, load_masked,
  )
  let (idle, live) = dependency_generation_decoder_and(hardware, live_masked)
  let (live_reset, not_poison) = dependency_generation_decoder_and(
    hardware, live,
  )
  if dependency_compute_state_gate(hardware, idle, inactive, 0UL) != state ||
    live_reset != inactive ||
    dependency_compute_complement(hardware, not_poison) != poison {
    raise InvalidFormalBundleIdentity(
      "compute discovery: admission state/live masks",
    )
  }
  let (issue, mat) = dependency_generation_decoder_and(hardware, command_valid)
  let (dependencies_masked, fault_clear) = dependency_generation_decoder_and(
    hardware, issue,
  )
  let (dispatching, _) = dependency_generation_decoder_and(
    hardware, dependencies_masked,
  )
  let (fault_poison, _, dispatch_fault) = dependency_generation_decoder_mux(
    hardware, local_fault,
  )
  if dependency_compute_state_gate(hardware, dispatching, inactive, 3UL) !=
    head_state ||
    fault_poison != poison ||
    dependency_generation_decoder_equal_constant(hardware, fault_clear, 4, 0UL) !=
    dispatch_fault {
    raise InvalidFormalBundleIdentity(
      "compute discovery: dispatch admission masks",
    )
  }
  let _ = dependency_generation_decoder_equal_constant(hardware, mat, 3, 2UL)
  dependency_generation_add_cut(
    hardware,
    cuts,
    dependency_compute_complement(hardware, load_clear),
    "load_conflict",
  )
  dependency_generation_add_cut(
    hardware,
    cuts,
    dependency_compute_complement(hardware, store_clear),
    "store_conflict",
  )
}

///|
// Resolve actual Run terminal and its status/identity payload from the copied
// FSM and fault next expressions. Never replace either update with a model.
fn dependency_compute_controller_cuts(
  hardware : @ir.Module,
  cuts : Array[DependencyGenerationCut],
  state : DependencyComputeRoot,
  fault : DependencyComputeRoot,
  ticket : @ir.NodeId,
  accept : @ir.NodeId,
  preflight : @ir.NodeId,
  issue : @ir.NodeId,
  ready : @ir.NodeId,
  done : @ir.NodeId,
  inactive : @ir.NodeId,
) -> Unit raise {
  let (accepted, accepted_state, waiting) = dependency_generation_decoder_mux(
    hardware,
    state.spec.next(),
  )
  let (legal, issue_value, rejected_value) = dependency_generation_decoder_mux(
    hardware, accepted_state,
  )
  if accepted != accept ||
    dependency_generation_decoder_equal_constant(hardware, legal, 4, 0UL) !=
    preflight {
    raise InvalidFormalBundleIdentity(
      "compute discovery: FSM accepted preflight",
    )
  }
  dependency_generation_decoder_constant(
    hardware,
    issue_value,
    @wire.uint(2),
    1UL,
  )
  dependency_generation_decoder_constant(
    hardware,
    rejected_value,
    @wire.uint(2),
    3UL,
  )
  let (inner_accept, run_value, running) = dependency_generation_decoder_mux(
    hardware, waiting,
  )
  if dependency_generation_decoder_and(hardware, inner_accept) != (issue, ready) {
    raise InvalidFormalBundleIdentity("compute discovery: inner handshake")
  }
  dependency_generation_decoder_constant(
    hardware,
    run_value,
    @wire.uint(2),
    2UL,
  )
  let (inner_terminal, done_value, completing) = dependency_generation_decoder_mux(
    hardware, running,
  )
  dependency_generation_decoder_constant(
    hardware,
    done_value,
    @wire.uint(2),
    3UL,
  )
  let (run_gate, core_valid) = dependency_generation_decoder_and(
    hardware, inner_terminal,
  )
  if dependency_compute_state_gate(hardware, run_gate, inactive, 2UL) !=
    state.node {
    raise InvalidFormalBundleIdentity("compute discovery: Run terminal state")
  }
  let (ack, idle_value, hold) = dependency_generation_decoder_mux(
    hardware, completing,
  )
  dependency_generation_decoder_constant(
    hardware,
    idle_value,
    @wire.uint(2),
    0UL,
  )
  if dependency_generation_decoder_and(hardware, ack) != (done, inactive) ||
    hold != state.node {
    raise InvalidFormalBundleIdentity("compute discovery: Done ACK or hold")
  }
  let (fault_accept, accepted_fault, fault_waiting) = dependency_generation_decoder_mux(
    hardware,
    fault.spec.next(),
  )
  let (fault_terminal, terminal_fault, fault_hold) = dependency_generation_decoder_mux(
    hardware, fault_waiting,
  )
  if fault_accept != accept ||
    accepted_fault != preflight ||
    fault_terminal != inner_terminal ||
    fault_hold != fault.node {
    raise InvalidFormalBundleIdentity(
      "compute discovery: fault update priority",
    )
  }
  let (good, success, mismatch) = dependency_generation_decoder_mux(
    hardware, terminal_fault,
  )
  dependency_generation_decoder_constant(hardware, success, @wire.uint(4), 0UL)
  dependency_generation_decoder_constant(
    hardware,
    mismatch,
    @wire.uint(4),
    11UL,
  )
  let (fault_good, ticket_good) = dependency_generation_decoder_and(
    hardware, good,
  )
  let core_fault = dependency_generation_decoder_equal_constant(
    hardware, fault_good, 2, 0UL,
  )
  guard dependency_generation_node(hardware, ticket_good).kind()
    is Equal(core_ticket, held_ticket) &&
    held_ticket == ticket else {
    raise InvalidFormalBundleIdentity("compute discovery: core terminal ticket")
  }
  dependency_generation_add_cut(
    hardware, cuts, core_valid, "core_completion_valid",
  )
  dependency_generation_add_cut(
    hardware, cuts, core_fault, "core_completion_fault",
  )
  dependency_generation_add_cut(
    hardware, cuts, core_ticket, "core_completion_id",
  )
}

///|
fn dependency_compute_plan(
  hardware : @ir.Module,
  bindings : ArrayView[DependencyGenerationBinding],
) -> DependencyComputePlan raise {
  let generation = dependency_generation_plan(hardware, bindings)
  let clock = generation.clock
  let reset = generation.reset
  let (inactive, _) = dependency_generation_decoder_and(
    hardware,
    generation.public_halted,
  )
  let inner_valid = dependency_generation_binding(bindings, InnerCommandValid).node
  let inner_ready = dependency_generation_binding(bindings, InnerCommandReady).node
  let terminal = dependency_generation_binding(bindings, ComputeTerminal).node
  let state_node = dependency_compute_state_gate(
    hardware, inner_valid, inactive, 1UL,
  )
  if dependency_compute_state_gate(hardware, terminal, inactive, 3UL) !=
    state_node {
    raise InvalidFormalBundleIdentity(
      "compute discovery: Issue/Done FSM mismatch",
    )
  }
  let roots : Array[DependencyComputeRoot] = [
    dependency_compute_register(
      hardware,
      "state",
      state_node,
      @wire.uint(2),
      clock,
      reset,
    ),
  ]
  let captured_roles : Array[
    (String, @flux_tile.QueuedConcurrentFormalRole, Int),
  ] = [
    ("ticket", ComputeLatchedTicket, 32),
    ("a", ComputeLatchedA, 1),
    ("b", ComputeLatchedB, 1),
    ("c", ComputeLatchedC, 1),
    ("rows", ComputeLatchedRows, 13),
    ("columns", ComputeLatchedColumns, 13),
    ("reduction", ComputeLatchedReduction, 13),
    ("fault", ComputeTerminalFault, 4),
  ]
  for (name, role, width) in captured_roles {
    let node = dependency_generation_binding(bindings, role).node
    if roots.any(root => root.node == node) {
      raise InvalidFormalBundleIdentity(
        "compute discovery: aliased state roots",
      )
    }
    roots.push(
      dependency_compute_register(
        hardware,
        name,
        node,
        @wire.uint(width),
        clock,
        reset,
      ),
    )
  }
  let accept = dependency_generation_binding(bindings, ComputeAccept).node
  let preflight = dependency_generation_binding(bindings, ComputePreflight).node
  if dependency_generation_binding(bindings, ComputeTerminalTicket).node !=
    roots[1].node {
    raise InvalidFormalBundleIdentity(
      "compute discovery: terminal/latched identity alias",
    )
  }
  for root in roots[1:8] {
    let (capture, payload, hold) = dependency_generation_decoder_mux(
      hardware,
      root.spec.next(),
    )
    if capture != accept ||
      hold != root.node ||
      (
        root.name == "ticket" &&
        payload != dependency_generation_binding(bindings, HeadTicket).node
      ) {
      raise InvalidFormalBundleIdentity(
        "compute discovery: capture/hold " + root.name,
      )
    }
  }
  let cuts : Array[DependencyGenerationCut] = []
  let seeds : Array[@ir.NodeId] = [
    accept,
    preflight,
    inner_valid,
    inner_ready,
    terminal,
    generation.public_halted,
  ]
  for root in roots {
    dependency_generation_add_cut(
      hardware,
      cuts,
      root.node,
      "compute_" + root.name,
    )
    seeds.push(root.spec.next())
    if root.spec.reset() is Some(control) {
      seeds.push(control.signal())
    }
    if root.spec.enable() is Some(enable) {
      seeds.push(enable)
    }
  }
  let head_roles : Array[@flux_tile.QueuedConcurrentFormalRole] = [
    HeadTicket,
    HeadState,
    HeadLane(0),
    HeadLane(1),
    HeadLane(2),
    HeadLane(3),
  ]
  for role in head_roles {
    let binding = dependency_generation_binding(bindings, role)
    dependency_generation_add_cut(
      hardware,
      cuts,
      binding.node,
      dependency_role_name(role),
    )
  }
  for role in dependency_generation_state_roles() {
    match role {
      WriterStatus(_)
      | WriterTicket(_)
      | DependencyStatus(_)
      | DependencyTicket(_) => {
        let binding = dependency_generation_binding(bindings, role)
        dependency_generation_add_cut(
          hardware,
          cuts,
          binding.node,
          dependency_role_name(role),
        )
      }
      _ => ()
    }
  }
  dependency_generation_add_cut(hardware, cuts, reset, "reset")
  dependency_generation_add_cut(
    hardware,
    cuts,
    generation.raw_poison,
    "raw_poison",
  )
  dependency_generation_add_cut(hardware, cuts, preflight, "preflight")
  dependency_generation_add_cut(hardware, cuts, inner_ready, "inner_ready")
  dependency_compute_admission_cuts(
    hardware,
    cuts,
    accept,
    state_node,
    inactive,
    generation.raw_poison,
    dependency_generation_binding(bindings, HeadState).node,
    generation.local_fault,
  )
  dependency_compute_controller_cuts(
    hardware,
    cuts,
    roots[0],
    roots[8],
    roots[1].node,
    accept,
    preflight,
    inner_valid,
    inner_ready,
    terminal,
    inactive,
  )
  let cone = dependency_generation_closure(hardware, cuts, seeds)
  for retained in [accept, inner_valid, terminal, generation.public_halted] {
    if cuts.any(cut => cut.node == retained) ||
      !cone.any(node => node.id() == retained) {
      raise InvalidFormalBundleIdentity(
        "compute discovery: masked event cut or omitted",
      )
    }
  }
  {
    roots: ReadOnlyArray::from_array(roots),
    cuts: ReadOnlyArray::from_array(cuts),
    cone: ReadOnlyArray::from_array(cone),
    clock,
    reset,
    raw_poison: generation.raw_poison,
    public_halted: generation.public_halted,
    accept,
    preflight,
    inner_valid,
    inner_ready,
    terminal,
  }
}

///|
fn dependency_compute_discover(
  fixture : @flux_tile.QueuedConcurrentFormalFixture,
) -> DependencyComputePlan raise {
  dependency_compute_plan(
    fixture.hardware(),
    dependency_generation_bindings(fixture),
  )
}
