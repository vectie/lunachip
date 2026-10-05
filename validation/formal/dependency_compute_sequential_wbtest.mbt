///|
fn dependency_compute_put(
  simulator : @sim.Simulator,
  plan : DependencyComputePlan,
  role : String,
  value : UInt64,
) -> Unit raise {
  guard plan.cuts.filter(cut => cut.roles.contains(role)) is [cut] else {
    fail("missing compute boundary: " + role)
  }
  dependency_generation_drive_cut(simulator, cut, value)
}

///|
fn dependency_compute_get(
  simulator : @sim.Simulator,
  name : String,
) -> UInt64 raise {
  simulator.output(name).to_uint64()
}

///|
fn dependency_compute_candidate(
  simulator : @sim.Simulator,
  plan : DependencyComputePlan,
) -> Unit raise {
  for
    (role, value) in [
      ("head_lane_0", 0x0002_0200UL),
      ("head_lane_1", 0x0002_0001_0001UL),
      ("head_lane_2", 0UL),
      ("head_lane_3", 0x0001_0101UL),
      ("head_state", 3UL),
      ("head_ticket", 0x1234UL),
      ("dependency_status_0", 2UL),
      ("dependency_status_1", 2UL),
      ("raw_poison", 0UL),
      ("load_conflict", 0UL),
      ("store_conflict", 0UL),
      ("preflight", 0UL),
      ("inner_ready", 0UL),
      ("core_completion_valid", 0UL),
      ("core_completion_id", 0UL),
      ("core_completion_fault", 0UL),
    ] {
    dependency_compute_put(simulator, plan, role, value)
  }
}

///|
test "compute discovery rejects relocated acceptance FSM and terminal identity bindings" {
  let fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let original = dependency_generation_bindings(fixture)
  let cases : Array[
    (
      @flux_tile.QueuedConcurrentFormalRole,
      @flux_tile.QueuedConcurrentFormalRole,
    ),
  ] = [
    (ComputeAccept, LoadAccept),
    (InnerCommandValid, ComputeTerminal),
    (ComputeTerminalTicket, HeadTicket),
  ]
  for (changed, replacement) in cases {
    let other = dependency_generation_binding(original, replacement)
    let bindings = original.map(binding => {
      if binding.role == changed {
        { ..binding, node: other.node, signal_type: other.signal_type, }
      } else {
        binding
      }
    })
    try dependency_compute_plan(fixture.hardware(), bindings) catch {
      InvalidFormalBundleIdentity(_) => ()
      error => fail("wrong compute discovery error: \{Repr(error)}")
    } noraise {
      _ => fail("relocated compute observation accepted")
    }
  }
  try
    dependency_compute_plan(
      fixture.hardware(),
      original[:original.length() - 1],
    )
  catch {
    InvalidFormalBundleIdentity(_) => ()
    error => fail("wrong incomplete-binding error: \{Repr(error)}")
  } noraise {
    _ => fail("incomplete compute observation inventory accepted")
  }
}

///|
test "compute sequential copies nine exact roots admission cone and aliases" {
  let fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let original = @ir_codec.serialize(
    @ir.Design::single("Original", fixture.hardware()),
  )
  let slice = dependency_compute_sequential(fixture)
  let again = dependency_compute_sequential(fixture)
  assert_eq(slice.hardware, again.hardware)
  assert_eq(slice.plan, again.plan)
  assert_eq(slice.original_to_local, again.original_to_local)
  assert_eq(
    @ir_codec.serialize(@ir.Design::single("Original", fixture.hardware())),
    original,
  )
  assert_eq(slice.plan.roots.length(), 9)
  assert_eq(
    slice.plan.roots
    .iter()
    .fold(init=0, (sum, root) => sum + root.signal_type.width().bits()),
    80,
  )
  assert_eq(slice.hardware.domains().length(), 1)
  assert_eq(slice.hardware.memories().length(), 0)
  assert_eq(slice.hardware.outputs().length(), 15)
  let inputs = slice.hardware.nodes().filter(node => node.kind() is Input(_))
  assert_eq(inputs.length(), 32)
  assert_eq(
    inputs
    .iter()
    .fold(init=0, (sum, node) => sum + node.signal_type().width().bits()),
    607,
  )
  assert_eq(
    slice.hardware.nodes().filter(node => node.kind() is Register(_)).length(),
    9,
  )
  let mut previous = -1
  for original in fixture.hardware().nodes() {
    if slice.original_to_local[original.id().ordinal()] is Some(mapped) {
      assert_true(mapped.ordinal() > previous)
      previous = mapped.ordinal()
      assert_eq(
        dependency_generation_node(slice.hardware, mapped).signal_type(),
        original.signal_type(),
      )
    }
  }
  for index, root in slice.plan.roots {
    let mapped = dependency_generation_mapped(
      slice.original_to_local,
      root.node,
    )
    guard dependency_generation_node(slice.hardware, mapped).kind()
      is Register(copy) else {
      fail("compute root ceased to be a register")
    }
    assert_eq(
      copy.next(),
      dependency_generation_mapped(slice.original_to_local, root.spec.next()),
    )
    assert_eq(
      copy.domain().clock(),
      dependency_generation_mapped(
        slice.original_to_local,
        root.spec.domain().clock(),
      ),
    )
    assert_eq(copy.domain().edge(), root.spec.domain().edge())
    assert_eq(copy.initial(), root.spec.initial())
    assert_eq(copy.initial(), None)
    assert_eq(copy.enable(), root.spec.enable())
    guard copy.reset() is Some(reset) && root.spec.reset() is Some(expected) else {
      fail("compute reset missing")
    }
    assert_eq(
      reset.signal(),
      dependency_generation_mapped(slice.original_to_local, expected.signal()),
    )
    assert_eq(reset.value(), expected.value())
    assert_eq(reset.mode(), expected.mode())
    assert_eq(reset.polarity(), expected.polarity())
    assert_eq(slice.hardware.outputs()[index].name(), "current_" + root.name)
    assert_eq(slice.hardware.outputs()[index].driver(), mapped)
  }
  for cut in slice.plan.cuts {
    if !slice.plan.roots.any(root => root.node == cut.node) {
      assert_eq(
        dependency_generation_node(
          slice.hardware,
          dependency_generation_mapped(slice.original_to_local, cut.node),
        ).kind(),
        Input("cut_n\{cut.node.ordinal()}"),
      )
    }
  }
  for node in slice.plan.cone {
    assert_eq(
      dependency_generation_node(
        slice.hardware,
        dependency_generation_mapped(slice.original_to_local, node.id()),
      ).kind(),
      dependency_generation_remap(node.kind(), slice.original_to_local),
    )
  }
  for
    (name, id) in [
      ("accept", slice.plan.accept),
      ("preflight", slice.plan.preflight),
      ("inner_valid", slice.plan.inner_valid),
      ("inner_ready", slice.plan.inner_ready),
      ("terminal", slice.plan.terminal),
      ("public_halted", slice.plan.public_halted),
    ] {
    guard slice.hardware.outputs().filter(output => output.name() == name)
      is [output] else {
      fail("compute output missing")
    }
    assert_eq(
      output.driver(),
      dependency_generation_mapped(slice.original_to_local, id),
    )
  }
  for id in [slice.plan.accept, slice.plan.inner_valid, slice.plan.terminal] {
    assert_false(slice.plan.cuts.any(cut => cut.node == id))
  }
}

///|
test "compute sequential holds Issue identity and checks terminal ticket fault reset priority" {
  let slice = dependency_compute_sequential(
    @flux_tile.queued_concurrent_dependency_formal_fixture(),
  )
  let plan = slice.plan
  let simulator = @sim.Simulator::prepare(slice.hardware)
  for cut in plan.cuts {
    if !plan.roots.any(root => root.node == cut.node) {
      dependency_generation_drive_cut(simulator, cut, 0UL)
    }
  }
  dependency_compute_put(simulator, plan, "reset", 1UL)
  simulator.settle()
  for root in plan.roots {
    assert_true(simulator.output("current_" + root.name).is_fully_unknown())
  }
  simulator.rising_edge("clock")
  for root in plan.roots {
    assert_eq(dependency_compute_get(simulator, "current_" + root.name), 0UL)
  }
  dependency_compute_put(simulator, plan, "reset", 0UL)
  // Admission is retained, not a free accepted-command input. Every blocker
  // here is an actual production predicate around the same Idle controller.
  dependency_compute_candidate(simulator, plan)
  for
    (role, blocked) in [
      ("load_conflict", 1UL),
      ("store_conflict", 1UL),
      ("raw_poison", 1UL),
      ("head_state", 2UL),
      ("head_lane_0", 0x0002_0000UL),
      ("dependency_status_0", 3UL),
      ("dependency_status_1", 3UL),
    ] {
    dependency_compute_candidate(simulator, plan)
    dependency_compute_put(simulator, plan, role, blocked)
    simulator.settle()
    assert_eq(dependency_compute_get(simulator, "accept"), 0UL)
  }
  // All three terminal cases exercise the exact isolated core boundary.
  // Wrong IDs are not claimed reachable in the complete composed device.
  for
    (id, inner_fault, expected_fault) in [
      (0x1234UL, 0UL, 0UL),
      (0x1235UL, 0UL, 11UL),
      (0x1234UL, 1UL, 11UL),
    ] {
    dependency_compute_candidate(simulator, plan)
    simulator.settle()
    assert_eq(dependency_compute_get(simulator, "accept"), 1UL)
    simulator.rising_edge("clock")
    assert_eq(dependency_compute_get(simulator, "current_state"), 1UL)
    assert_eq(dependency_compute_get(simulator, "inner_valid"), 1UL)
    let held = plan.roots.map(root => simulator.output("current_" + root.name))
    for
      (role, value) in [
        ("head_ticket", 99UL),
        ("head_lane_1", 0UL),
        ("head_lane_3", 0UL),
        ("writer_ticket_1", 77UL),
        ("writer_status_1", 3UL),
        ("dependency_status_0", 3UL),
        ("core_completion_valid", 1UL),
      ] {
      dependency_compute_put(simulator, plan, role, value)
    }
    for phase in 0..<3 {
      simulator.set_input(
        "clock",
        @wave.LogicValue::from_uint64(width=1, value=(phase % 2).to_uint64()),
      )
      simulator.settle()
      for index, root in plan.roots {
        assert_eq(simulator.output("current_" + root.name), held[index])
      }
      simulator.rising_edge("clock")
      for index, root in plan.roots {
        assert_eq(simulator.output("current_" + root.name), held[index])
      }
      assert_eq(dependency_compute_get(simulator, "accept"), 0UL)
    }
    assert_eq(dependency_compute_get(simulator, "current_ticket"), 0x1234UL)
    for name in ["a", "b", "c", "rows", "columns"] {
      assert_eq(dependency_compute_get(simulator, "current_" + name), 1UL)
    }
    assert_eq(dependency_compute_get(simulator, "current_reduction"), 2UL)
    dependency_compute_put(simulator, plan, "core_completion_valid", 0UL)
    dependency_compute_put(simulator, plan, "inner_ready", 1UL)
    simulator.rising_edge("clock")
    assert_eq(dependency_compute_get(simulator, "current_state"), 2UL)
    dependency_compute_put(simulator, plan, "core_completion_valid", 1UL)
    dependency_compute_put(simulator, plan, "core_completion_id", id)
    dependency_compute_put(
      simulator, plan, "core_completion_fault", inner_fault,
    )
    simulator.rising_edge("clock")
    assert_eq(dependency_compute_get(simulator, "terminal"), 1UL)
    assert_eq(
      dependency_compute_get(simulator, "current_fault"),
      expected_fault,
    )
    simulator.rising_edge("clock")
    assert_eq(dependency_compute_get(simulator, "current_state"), 0UL)
  }
  dependency_compute_candidate(simulator, plan)
  dependency_compute_put(simulator, plan, "preflight", 4UL)
  simulator.rising_edge("clock")
  assert_eq(dependency_compute_get(simulator, "current_state"), 3UL)
  assert_eq(dependency_compute_get(simulator, "current_fault"), 4UL)
  assert_eq(dependency_compute_get(simulator, "inner_valid"), 0UL)
  simulator.rising_edge("clock")
  dependency_compute_candidate(simulator, plan)
  simulator.rising_edge("clock")
  assert_eq(dependency_compute_get(simulator, "current_state"), 1UL)
  dependency_compute_put(simulator, plan, "reset", 1UL)
  dependency_compute_put(simulator, plan, "inner_ready", 1UL)
  dependency_compute_put(simulator, plan, "core_completion_valid", 1UL)
  simulator.rising_edge("clock")
  for root in plan.roots {
    assert_eq(dependency_compute_get(simulator, "current_" + root.name), 0UL)
  }
  assert_eq(dependency_compute_get(simulator, "inner_valid"), 0UL)
  assert_eq(dependency_compute_get(simulator, "terminal"), 0UL)
}
