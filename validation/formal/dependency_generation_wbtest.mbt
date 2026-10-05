///|
fn dependency_generation_expect_failure(
  hardware : @ir.Module,
  bindings : ArrayView[DependencyGenerationBinding],
) -> Unit raise {
  try dependency_generation_plan(hardware, bindings) catch {
    InvalidFormalBundleIdentity(_) => ()
    error => fail("unexpected generation-discovery error: \{Repr(error)}")
  } noraise {
    _ => fail("generation discovery accepted malformed binding/graph")
  }
}

///|
fn dependency_generation_replace_register(
  hardware : @ir.Module,
  root : DependencyGenerationRoot,
  spec : @ir.RegisterSpec,
) -> @ir.Module raise {
  let nodes = hardware
    .nodes()
    .iter()
    .map(node => {
      if node.id() == root.binding.node {
        @ir.Node::new(node.id(), node.signal_type(), Register(spec))
      } else {
        node
      }
    })
    .to_array()
  @ir.Module::checked_with_metadata(
    hardware.name(),
    hardware.domains(),
    nodes,
    hardware.memories(),
    hardware.outputs(),
    hardware.metadata(),
  )
}

///|
test "dependency generation discovery binds 18 exact state roots and canonical closure without changing production" {
  let fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let hardware = fixture.hardware()
  let before = @ir_codec.serialize(
    @ir.Design::single("GenerationDiscovery", hardware),
  )
  let plan = dependency_generation_discover(fixture)
  assert_eq(plan, dependency_generation_discover(fixture))
  assert_eq(plan.roots.length(), 18)
  assert_eq(
    plan.roots
    .iter()
    .fold(init=0, (sum, root) => sum + root.binding.signal_type.width().bits()),
    336,
  )
  assert_eq(plan.cuts.length(), 32)
  assert_eq(
    plan.cuts
    .iter()
    .fold(init=0, (sum, cut) => sum + cut.signal_type.width().bits()),
    671,
  )
  assert_eq(
    plan.roots.iter().map(root => root.binding.role).to_array(),
    dependency_generation_state_roles(),
  )
  for root in plan.roots {
    let node = dependency_generation_node(hardware, root.binding.node)
    assert_eq(node.kind(), Register(root.spec))
    assert_eq(root.spec.domain(), @ir.ClockDomain::rising(plan.clock))
    assert_eq(root.spec.initial(), None)
    assert_eq(root.spec.enable(), None)
    assert_eq(root.spec.reset(), Some(@ir.ResetSpec::new(plan.reset, 0UL)))
    assert_true(plan.cuts.any(cut => cut.node == root.binding.node))
    assert_true(plan.cone.any(node => node.id() == root.spec.next()))
  }
  assert_true(
    plan.cone.length() > 0 && plan.cone.length() < hardware.nodes().length(),
  )
  for index, node in plan.cone {
    assert_eq(node, dependency_generation_node(hardware, node.id()))
    assert_false(plan.cuts.any(cut => cut.node == node.id()))
    if index > 0 {
      assert_true(plan.cone[index - 1].id().ordinal() < node.id().ordinal())
    }
    for operand in dependency_generation_operands(node.kind()) {
      assert_true(
        plan.cone.any(item => item.id() == operand) ||
        plan.cuts.any(cut => cut.node == operand),
      )
    }
  }
  assert_true(plan.cone.any(node => node.id() == plan.local_fault))
  assert_true(plan.cone.any(node => node.id() == plan.local_reject))
  assert_eq(
    before,
    @ir_codec.serialize(@ir.Design::single("GenerationDiscovery", hardware)),
  )
  assert_eq(
    hardware,
    @flux_tile.queued_concurrent_dependency_formal_fixture().hardware(),
  )
}

///|
test "dependency generation discovery binds raw poison once and retains public reset-gated halted" {
  let fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let hardware = fixture.hardware()
  let plan = dependency_generation_discover(fixture)
  assert_true(plan.public_halted != plan.raw_poison)
  assert_eq(plan.cuts.filter(cut => cut.node == plan.raw_poison).length(), 1)
  assert_false(plan.cuts.any(cut => cut.node == plan.public_halted))
  assert_true(plan.cone.any(node => node.id() == plan.public_halted))
  guard dependency_generation_node(hardware, plan.public_halted).kind()
    is BitAnd(inactive, raw) else {
    fail("missing public halted derivation")
  }
  assert_eq(raw, plan.raw_poison)
  guard dependency_generation_node(hardware, inactive).kind()
    is BitNot(asserted) &&
    dependency_generation_node(hardware, asserted).kind() is Reinterpret(reset) else {
    fail("missing reset-inactive derivation")
  }
  assert_eq(reset, plan.reset)
  guard dependency_generation_node(hardware, plan.local_fault).kind()
    is Mux(select~, ..) else {
    fail("missing local-fault poison priority")
  }
  assert_eq(select, plan.raw_poison)
  assert_true(
    plan.cone.any(node => node.kind() is BitNot(value) && value == raw),
  )
  for cut in plan.cuts {
    assert_eq(
      cut.signal_type,
      dependency_generation_node(hardware, cut.node).signal_type(),
    )
    assert_false(cut.roles.is_empty())
    assert_eq(plan.cuts.filter(other => other.node == cut.node).length(), 1)
  }
}

///|
test "dependency generation discovery rejects independent public-halted substitution and wrong clock binding" {
  let fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let hardware = fixture.hardware()
  let bindings = dependency_generation_bindings(fixture)
  let plan = dependency_generation_discover(fixture)
  let outputs = hardware
    .outputs()
    .iter()
    .map(output => {
      if output.name() == "halted" {
        @ir.OutputPort::new(
          output.name(),
          output.signal_type(),
          plan.raw_poison,
        )
      } else {
        output
      }
    })
    .to_array()
  let substituted = @ir.Module::checked_with_metadata(
    hardware.name(),
    hardware.domains(),
    hardware.nodes(),
    hardware.memories(),
    outputs,
    hardware.metadata(),
  )
  dependency_generation_expect_failure(substituted, bindings)
  try
    dependency_generation_root(
      hardware,
      plan.roots[0].binding,
      plan.reset,
      plan.reset,
    )
  catch {
    InvalidFormalBundleIdentity(_) => ()
    error => fail("unexpected domain error: \{Repr(error)}")
  } noraise {
    _ => fail("wrong clock binding was accepted")
  }
}

///|
test "dependency generation discovery rejects missing repeated reordered mistyped and aliased roots" {
  let fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let hardware = fixture.hardware()
  let bindings = dependency_generation_bindings(fixture)
  dependency_generation_expect_failure(
    hardware,
    bindings[:bindings.length() - 1],
  )
  let repeated = bindings.copy()
  repeated[0] = bindings[1]
  dependency_generation_expect_failure(hardware, repeated)
  let reordered = bindings.copy()
  reordered[0] = bindings[1]
  reordered[1] = bindings[0]
  dependency_generation_expect_failure(hardware, reordered)
  let next = dependency_generation_binding(bindings, NextTicket)
  let head = dependency_generation_binding(bindings, HeadTicket)
  for
    signal_type in [
      @ir.SignalType::UInt(@ir.Width::new(31)),
      SInt(@ir.Width::new(32)),
    ] {
    let changed = bindings.map(binding => {
      if binding.role is NextTicket {
        { ..binding, signal_type, }
      } else {
        binding
      }
    })
    dependency_generation_expect_failure(hardware, changed)
  }
  let aliased = bindings.map(binding => {
    if binding.role is NextTicket {
      { ..binding, node: head.node, }
    } else {
      binding
    }
  })
  dependency_generation_expect_failure(hardware, aliased)
  let absent = bindings.map(binding => {
    if binding.role is NextTicket {
      { ..binding, node: @ir.NodeId::new(hardware.nodes().length()), }
    } else {
      binding
    }
  })
  dependency_generation_expect_failure(hardware, absent)
  let nonregister = dependency_generation_input(
    hardware,
    "memory_response_tag",
    next.signal_type,
  )
  let changed = bindings.map(binding => {
    if binding.role is NextTicket {
      { ..binding, node: nonregister, }
    } else {
      binding
    }
  })
  dependency_generation_expect_failure(hardware, changed)
}

///|
test "dependency generation discovery rejects reset drift but preserves an exact explicit enable" {
  let fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let hardware = fixture.hardware()
  let bindings = dependency_generation_bindings(fixture)
  let plan = dependency_generation_discover(fixture)
  let root = plan.roots[0]
  for
    reset in [
      @ir.ResetSpec::new(plan.reset, 1UL),
      @ir.ResetSpec::explicit(plan.reset, 0UL, Asynchronous, ActiveHigh),
      @ir.ResetSpec::explicit(plan.reset, 0UL, Synchronous, ActiveLow),
    ] {
    let spec = @ir.RegisterSpec::new(
      root.spec.domain(),
      root.spec.next(),
      reset~,
    )
    dependency_generation_expect_failure(
      dependency_generation_replace_register(hardware, root, spec),
      bindings,
    )
  }
  let initial = @ir.RegisterSpec::new(
    root.spec.domain(),
    root.spec.next(),
    reset=@ir.ResetSpec::new(plan.reset, 0UL),
    initial=0UL,
  )
  dependency_generation_expect_failure(
    dependency_generation_replace_register(hardware, root, initial),
    bindings,
  )
  guard dependency_generation_node(hardware, plan.public_halted).kind()
    is BitAnd(enable, _) else {
    fail("missing exact enable candidate")
  }
  let enabled = @ir.RegisterSpec::new(
    root.spec.domain(),
    root.spec.next(),
    reset=@ir.ResetSpec::new(plan.reset, 0UL),
    enable~,
  )
  let changed = dependency_generation_plan(
    dependency_generation_replace_register(hardware, root, enabled),
    bindings,
  )
  assert_eq(changed.roots[0].spec.enable(), Some(enable))
  assert_true(changed.cone.any(node => node.id() == enable))
}

///|
test "dependency generation closure rejects every unlisted state input memory or CDC leaf" {
  let fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let hardware = fixture.hardware()
  let plan = dependency_generation_discover(fixture)
  let unlisted = hardware
    .nodes()
    .iter()
    .filter(node => {
      !plan.cuts.any(cut => cut.node == node.id()) &&
      (
        node.kind() is Input(_) ||
        node.kind() is Register(_) ||
        node.kind() is MemoryRead(..)
      )
    })
    .to_array()
  assert_true(unlisted.any(node => node.kind() is Input(_)))
  assert_true(unlisted.any(node => node.kind() is Register(_)))
  assert_true(unlisted.any(node => node.kind() is MemoryRead(..)))
  for node in unlisted {
    try dependency_generation_closure(hardware, plan.cuts, [node.id()]) catch {
      InvalidFormalBundleIdentity(_) => ()
      error => fail("unexpected unlisted-leaf error: \{Repr(error)}")
    } noraise {
      _ => fail("unlisted graph leaf was accepted")
    }
  }
  let unlisted_tickets = unlisted.filter(node => {
    node.kind() is Register(_) &&
    node.signal_type() == plan.roots[0].binding.signal_type
  })
  guard unlisted_tickets is [node, ..] else {
    fail("missing unlisted state test")
  }
  let root = plan.roots[0]
  let spec = @ir.RegisterSpec::new(
    root.spec.domain(),
    node.id(),
    reset=@ir.ResetSpec::new(plan.reset, 0UL),
  )
  dependency_generation_expect_failure(
    dependency_generation_replace_register(hardware, root, spec),
    dependency_generation_bindings(fixture),
  )
  try
    dependency_generation_operands(
      AsyncFifoRead(primitive=@ir.CdcPrimitiveId::new(0), leaf=0),
    )
  catch {
    InvalidFormalBundleIdentity(_) => ()
    error => fail("unexpected CDC-leaf error: \{Repr(error)}")
  } noraise {
    _ => fail("unlisted CDC leaf was accepted")
  }
}
