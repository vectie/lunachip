///|
// Resolve progress and lease events from the actual state/latch equations.
// No construction-order register offsets or guessed emitted names are used.
fn direct8_engine_compute_bindings(
  fixture : @flux_tile.QueueConservationFixture,
) -> Array[QueueControlAlias] raise {
  let source = fixture.hardware()
  let aliases = fetched_safety_shape_roots(
    source,
    rows=8,
    columns=8,
    max_reduction=16,
  )
  for binding in fetched_capture_roots(source, columns=8, depth=64) {
    aliases.push(binding)
  }
  let find = name => {
    guard aliases.filter(binding => binding.name == name) is [binding] else {
      fail("direct8 engines: unique core binding")
    }
    binding.node
  }
  let core_state = find("composition_shape_core_state")
  let capture_state = find("composition_capture_state")
  let compute_state = queue_control_binding(fixture, EngineState(1)).node
  guard dependency_generation_node(source, capture_state).kind()
    is Register(capture_spec) &&
    dependency_generation_node(source, capture_spec.next()).kind()
    is Mux(select=slotted_accept, when_false=capture_next, ..) &&
    dependency_generation_node(source, capture_next).kind()
    is Mux(select=capture, when_true=capture_transition, ..) &&
    capture == find("composition_shape_capture") &&
    dependency_generation_node(source, capture_transition).kind()
    is Mux(select=final_capture, when_true=capture_done, when_false=capturing) &&
    fetched_transport_constant(source, capture_done, 2, 3UL) &&
    fetched_transport_constant(source, capturing, 2, 2UL) &&
    dependency_generation_node(source, compute_state).kind()
    is Register(compute_spec) &&
    dependency_generation_node(source, compute_spec.next()).kind()
    is Mux(
      select=compute_accept,
      when_true=compute_start,
      when_false=compute_next
    ) &&
    compute_accept == queue_control_binding(fixture, EngineAccept(1)).node &&
    dependency_generation_node(source, compute_start).kind()
    is Mux(select=legal, when_true=issue, when_false=done) &&
    fetched_transport_constant(source, issue, 2, 1UL) &&
    fetched_transport_constant(source, done, 2, 3UL) &&
    dependency_generation_node(source, compute_next).kind()
    is Mux(select=issue_accept, when_true=run, when_false=compute_running) &&
    fetched_transport_constant(source, run, 2, 2UL) &&
    dependency_generation_node(source, compute_running).kind()
    is Mux(select=terminal, ..) else {
    fail("direct8 engines: actual capture and compute transitions")
  }
  let lease = fetched_transport_unique(source, "compute lease", node => {
    guard node.signal_type() == @wire.bits(1) &&
      node.kind() is Register(spec) &&
      dependency_generation_node(source, spec.next()).kind()
      is Mux(select=legal_accept, when_true=one, when_false=lease_next) &&
      fetched_transport_constant(source, one, 1, 1UL) &&
      dependency_generation_node(source, legal_accept).kind()
      is BitAnd(event, allowed) &&
      event == compute_accept &&
      allowed == legal &&
      dependency_generation_node(source, lease_next).kind()
      is Mux(select=release, when_true=zero, when_false=held) &&
      held == node.id() &&
      fetched_transport_constant(source, zero, 1, 0UL) &&
      dependency_generation_node(source, release).kind()
      is BitOr(last_capture, terminal_free) &&
      last_capture == final_capture &&
      dependency_generation_node(source, terminal_free).kind()
      is BitAnd(actual_terminal, _) &&
      actual_terminal == terminal else {
      return false
    }
    true
  })
  guard dependency_generation_node(source, lease).kind() is Register(lease_spec) &&
    dependency_generation_node(source, lease_spec.next()).kind()
    is Mux(select=legal_accept, when_false=lease_next, ..) &&
    dependency_generation_node(source, lease_next).kind()
    is Mux(select=release, ..) &&
    dependency_generation_node(source, release).kind()
    is BitOr(_, terminal_free) &&
    dependency_generation_node(source, terminal_free).kind()
    is BitAnd(_, not_owned) &&
    dependency_generation_node(source, not_owned).kind() is BitNot(ownership) &&
    dependency_generation_node(source, core_state).kind() is Register(core_spec) &&
    dependency_generation_node(source, core_spec.next()).kind()
    is Mux(select=core_accept, when_false=core_next, ..) &&
    dependency_generation_node(source, core_next).kind()
    is Mux(select=clear, when_false=core_run, ..) &&
    dependency_generation_node(source, core_run).kind()
    is Mux(select=running, when_true=run_next, ..) &&
    dependency_generation_node(source, run_next).kind()
    is Mux(select=advance_final, ..) &&
    dependency_generation_node(source, advance_final).kind()
    is BitAnd(advance, final_step) &&
    dependency_generation_node(source, final_step).kind()
    is Equal(next_step, total_steps) &&
    dependency_generation_node(source, next_step).kind() is Add(steps, one) &&
    fetched_transport_constant(source, one, 13, 1UL) &&
    dependency_generation_node(source, steps).kind() is Register(steps_spec) &&
    steps_spec.enable() is Some(enabled) &&
    dependency_generation_node(source, enabled).kind()
    is BitOr(accepted, advanced) &&
    accepted == core_accept &&
    advanced == advance else {
    fail("direct8 engines: original lease and core rank equations")
  }
  for
    (name, id) in [
      ("slotted_accept", slotted_accept),
      ("final_capture", final_capture),
      ("compute_accept", compute_accept),
      ("compute_legal_accept", legal_accept),
      ("issue_accept", issue_accept),
      ("compute_terminal", terminal),
      ("lease", lease),
      ("release", release),
      ("ownership", ownership),
      ("core_accept", core_accept),
      ("clear", clear),
      ("running", running),
      ("core_advance", advance),
      ("core_final_step", final_step),
      ("core_steps", steps),
      ("core_total", total_steps),
    ] {
    aliases.push({
      name: "x_" + name,
      node: id,
      signal_type: dependency_generation_node(source, id).signal_type(),
    })
  }
  aliases
}
