///|
fn arbiter_identity_output(
  hardware : @ir.Module,
  name : String,
) -> @ir.NodeId raise {
  guard hardware.outputs().filter(output => output.name() == name) is [output] else {
    fail("missing independent arbiter output")
  }
  assert_eq(
    output.signal_type(),
    dependency_generation_node(hardware, output.driver()).signal_type(),
  )
  output.driver()
}

///|
fn arbiter_identity_register(
  hardware : @ir.Module,
  node : @ir.NodeId,
) -> @ir.RegisterSpec raise {
  guard dependency_generation_node(hardware, node).kind() is Register(spec) else {
    fail("independent arbiter selector did not reach original state")
  }
  spec
}

///|
test "two client arbiter probe preserves independently selected original state and boundaries" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let hardware = fixture.hardware()
  let before = @ir_codec.serialize(
    @ir.Design::single("QueuedConcurrentQueueConservationPilot", hardware),
  )
  let probe = two_client_arbiter_probe(fixture)
  assert_eq(probe, two_client_arbiter_probe(fixture))
  assert_eq(probe.production_digest, sha256_hex(before))
  assert_eq(
    probe.production_digest,
    "35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc",
  )
  let clock = dependency_generation_input(hardware, "clock", @wire.clock())
  let reset = dependency_generation_input(hardware, "reset", @wire.reset())
  assert_eq(probe.clock, clock)
  assert_eq(probe.reset, reset)
  // Recover state from the published Offer decoder, not probe roles or IDs.
  let request_valid = arbiter_identity_output(hardware, "memory_request_valid")
  let (offer_comparison, inactive) = dependency_generation_decoder_and(
    hardware, request_valid,
  )
  let state = dependency_generation_decoder_equal_constant(
    hardware, offer_comparison, 2, 1UL,
  )
  guard dependency_generation_node(hardware, inactive).kind()
    is BitNot(asserted) &&
    dependency_generation_node(hardware, asserted).kind() is Reinterpret(source) else {
    fail("original arbiter reset mask changed")
  }
  assert_eq(source, reset)
  let response_ready = arbiter_identity_output(
    hardware, "memory_response_ready",
  )
  let (wait, selected_ready) = dependency_generation_decoder_and(
    hardware, response_ready,
  )
  let (wait_comparison, wait_inactive) = dependency_generation_decoder_and(
    hardware, wait,
  )
  assert_eq(wait_inactive, inactive)
  assert_eq(
    dependency_generation_decoder_equal_constant(
      hardware, wait_comparison, 2, 2UL,
    ),
    state,
  )
  let (owner, engine_ready, reader_ready) = dependency_generation_decoder_mux(
    hardware, selected_ready,
  )
  let (grant, selected_owner, owner_hold) = dependency_generation_decoder_mux(
    hardware,
    arbiter_identity_register(hardware, owner).next(),
  )
  assert_eq(owner_hold, owner)
  guard dependency_generation_node(hardware, selected_owner).kind()
    is BitAnd(engine_valid, reader_absent_or_preference) &&
    dependency_generation_node(hardware, reader_absent_or_preference).kind()
    is BitOr(reader_absent, preference) &&
    dependency_generation_node(hardware, reader_absent).kind()
    is BitNot(reader_valid) else {
    fail("original selected-owner equation changed")
  }
  // Public payload registers and original local-tag latch share one grant and
  // one selected-owner mux. No ordinal or construction-range lookup is used.
  let expected : Array[(String, @ir.NodeId, @ir.SignalType)] = [
    ("state", state, @wire.uint(2)),
    ("owner", owner, @wire.bits(1)),
    ("preference", preference, @wire.bits(1)),
  ]
  let held : Array[(String, @ir.NodeId)] = []
  for
    (name, signal_type) in [
      ("write", @wire.bits(1)),
      ("address", @wire.uint(32)),
      ("bytes", @wire.uint(3)),
      ("mask", @wire.bits(4)),
      ("data", @wire.bits(32)),
    ] {
    let node = arbiter_identity_output(hardware, "memory_request_" + name)
    expected.push((name, node, signal_type))
    held.push((name, node))
  }
  let address = held.filter(pair => pair.0 == "address")[0].1
  let local_tags : Array[@ir.NodeId] = []
  for node in hardware.nodes() {
    if node.id() != address && node.signal_type() == @wire.uint(32) {
      if node.kind() is Register(spec) &&
        dependency_generation_node(hardware, spec.next()).kind()
        is Mux(select~, when_true~, when_false~) &&
        select == grant &&
        when_false == node.id() &&
        dependency_generation_node(hardware, when_true).kind()
        is Mux(select=selector, ..) &&
        selector == selected_owner {
        local_tags.push(node.id())
      }
    }
  }
  guard local_tags is [local_tag] else {
    fail("original local-tag grant latch was not unique")
  }
  expected.push(("local_tag", local_tag, @wire.uint(32)))
  held.push(("tag", local_tag))
  let next_tag = arbiter_identity_output(hardware, "memory_request_tag")
  expected.push(("next_tag", next_tag, @wire.uint(32)))
  let (response_accept, response_state, request_transition) = dependency_generation_decoder_mux(
    hardware,
    arbiter_identity_register(hardware, state).next(),
  )
  let (request_accept, _, grant_transition) = dependency_generation_decoder_mux(
    hardware, request_transition,
  )
  let (original_grant, _, state_hold) = dependency_generation_decoder_mux(
    hardware, grant_transition,
  )
  assert_eq(original_grant, grant)
  assert_eq(state_hold, state)
  let (malformed, _, _) = dependency_generation_decoder_mux(
    hardware, response_state,
  )
  guard dependency_generation_node(hardware, malformed).kind()
    is BitOr(tag_mismatch, _) &&
    dependency_generation_node(hardware, tag_mismatch).kind()
    is BitNot(tag_equal) &&
    dependency_generation_node(hardware, tag_equal).kind()
    is Equal(bus_tag, expected_tag) else {
    fail("original expected-tag malformed selector changed")
  }
  assert_eq(
    bus_tag,
    dependency_generation_input(hardware, "memory_response_tag", @wire.uint(32)),
  )
  expected.push(("expected_tag", expected_tag, @wire.uint(32)))
  assert_eq(probe.roots.length(), expected.length())
  assert_eq(expected.length(), 11)
  assert_eq(
    expected.iter().fold(init=0, (sum, root) => sum + root.2.width().bits()),
    172,
  )
  for (name, node, signal_type) in expected {
    guard probe.roots.filter(root => root.name == name) is [root] else {
      fail("missing independently selected arbiter role")
    }
    assert_eq(root.node, node)
    assert_eq(root.signal_type, signal_type)
    assert_eq(
      dependency_generation_node(hardware, node).signal_type(),
      signal_type,
    )
    let spec = arbiter_identity_register(hardware, node)
    assert_eq(root.spec, spec)
    assert_eq(spec.domain(), @ir.ClockDomain::rising(clock))
    assert_eq(spec.enable(), None)
    assert_eq(spec.initial(), None)
    guard spec.reset() is Some(control) else {
      fail("original arbiter root lost reset")
    }
    assert_eq(control.signal(), reset)
    assert_eq(control.value(), 0UL)
    assert_eq(control.mode(), Synchronous)
    assert_eq(control.polarity(), ActiveHigh)
  }
  let boundaries : Array[(String, @ir.NodeId)] = [
    ("reader_valid", reader_valid),
    ("engine_valid", engine_valid),
    ("reader_response_ready", reader_ready),
    ("engine_response_ready", engine_ready),
  ]
  for (name, node) in held {
    let (original_grant, selected, hold) = dependency_generation_decoder_mux(
      hardware,
      arbiter_identity_register(hardware, node).next(),
    )
    assert_eq(original_grant, grant)
    assert_eq(hold, node)
    let (selector, engine, reader) = dependency_generation_decoder_mux(
      hardware, selected,
    )
    assert_eq(selector, selected_owner)
    boundaries.push(("engine_" + name, engine))
    boundaries.push(("reader_" + name, reader))
  }
  boundaries.push(("reset", reset))
  for
    (name, signal_type) in [
      ("request_ready", @wire.bits(1)),
      ("response_valid", @wire.bits(1)),
      ("response_tag", @wire.uint(32)),
      ("response_fault", @wire.uint(2)),
      ("response_data", @wire.bits(32)),
    ] {
    boundaries.push(
      (
        name,
        dependency_generation_input(hardware, "memory_" + name, signal_type),
      ),
    )
  }
  assert_eq(boundaries.length(), 22)
  assert_eq(
    probe.boundaries
    .iter()
    .fold(init=0, (sum, boundary) => sum + boundary.roles.length()),
    boundaries.length(),
  )
  for (role, boundary) in boundaries {
    let original = dependency_generation_node(hardware, boundary)
    guard probe.boundaries.filter(boundary => boundary.roles.contains(role))
      is [binding] else {
      fail("raw semantic boundary role was not uniquely inventoried")
    }
    assert_eq(binding.original, original)
    if original.kind() is Constant(_) {
      assert_false(
        probe.candidates.any(candidate => candidate.original.id() == boundary),
      )
      assert_true(probe.cone.any(node => node == original))
    } else {
      guard probe.candidates.filter(candidate => {
          candidate.original.id() == boundary
        })
        is [candidate] else {
        fail("original raw client or bus boundary was not retained")
      }
      assert_eq(candidate.original, original)
      assert_true(candidate.roles.contains(role))
    }
  }
  let mut previous = -1
  for candidate in probe.candidates {
    let node = candidate.original
    assert_true(node.id().ordinal() > previous)
    previous = node.id().ordinal()
    assert_eq(node, dependency_generation_node(hardware, node.id()))
    let expected_roles = boundaries.filter(pair => pair.1 == node.id())
    assert_true(expected_roles.length() > 0)
    assert_eq(candidate.roles.length(), expected_roles.length())
    for (role, _) in expected_roles {
      assert_true(candidate.roles.contains(role))
    }
    assert_false(node.kind() is Constant(_))
    assert_false(probe.roots.any(root => root.node == node.id()))
    assert_false(probe.cone.any(original => original.id() == node.id()))
    assert_false(node.id() == clock)
  }
  for root in probe.roots {
    assert_false(probe.cone.any(node => node.id() == root.node))
    assert_false(root.node == clock || root.node == reset)
    for operand in [root.spec.next(), reset] {
      assert_true(
        operand == clock ||
        probe.roots.any(root => root.node == operand) ||
        probe.candidates.any(candidate => candidate.original.id() == operand) ||
        probe.cone.any(node => node.id() == operand),
      )
    }
  }
  for node in probe.cone {
    assert_eq(node, dependency_generation_node(hardware, node.id()))
    assert_true(node.signal_type().is_data())
    assert_false(node.id() == clock || node.id() == reset)
    for operand in dependency_generation_operands(node.kind()) {
      assert_true(
        probe.roots.any(root => root.node == operand) ||
        probe.candidates.any(candidate => candidate.original.id() == operand) ||
        probe.cone.any(node => node.id() == operand),
      )
    }
  }
  for
    decision in [
      grant, selected_owner, request_accept, response_accept, malformed, response_ready,
      request_valid,
    ] {
    assert_true(probe.cone.any(node => node.id() == decision))
    assert_false(
      probe.candidates.any(candidate => candidate.original.id() == decision),
    )
  }
  for event in probe.events {
    assert_eq(
      event.signal_type,
      dependency_generation_node(hardware, event.node).signal_type(),
    )
    assert_true(probe.cone.any(node => node.id() == event.node))
    assert_false(
      probe.candidates.any(candidate => candidate.original.id() == event.node),
    )
  }
  assert_eq(
    @ir_codec.serialize(
      @ir.Design::single("QueuedConcurrentQueueConservationPilot", hardware),
    ),
    before,
  )
}
