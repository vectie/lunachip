///|
fn dependency_composition_test_put(
  simulator : @sim.Simulator,
  plan : DependencyCompositionPlan,
  role : String,
  value : UInt64,
) -> Unit raise {
  guard plan.cuts.filter(cut => cut.roles.contains(role)) is [cut] else {
    fail("missing composition boundary: " + role)
  }
  assert_false(plan.roots.any(root => root.node == cut.node))
  dependency_generation_drive_cut(simulator, cut, value)
}

///|
fn dependency_composition_test_get(
  simulator : @sim.Simulator,
  name : String,
) -> UInt64 raise {
  simulator.output(name).to_uint64()
}

///|
fn dependency_composition_test_prepare(
  slice : DependencyCompositionSequential,
) -> @sim.Simulator raise {
  let simulator = @sim.Simulator::prepare(slice.hardware)
  for cut in slice.plan.cuts {
    if !slice.plan.roots.any(root => root.node == cut.node) {
      dependency_generation_drive_cut(simulator, cut, 0UL)
    }
  }
  dependency_composition_test_put(simulator, slice.plan, "reset", 1UL)
  simulator.settle()
  for root in slice.plan.roots {
    assert_true(simulator.output("current_" + root.name).is_fully_unknown())
  }
  simulator.rising_edge("clock")
  for root in slice.plan.roots {
    assert_eq(
      dependency_composition_test_get(simulator, "current_" + root.name),
      0UL,
    )
  }
  dependency_composition_test_put(simulator, slice.plan, "reset", 0UL)
  simulator.settle()
  simulator
}

///|
fn dependency_composition_test_command(
  simulator : @sim.Simulator,
  plan : DependencyCompositionPlan,
  lanes : ArrayView[UInt64],
  state : UInt64,
  reserve : UInt64,
) -> Unit raise {
  assert_eq(lanes.length(), 4)
  for lane, value in lanes {
    dependency_composition_test_put(simulator, plan, "head_lane_\{lane}", value)
  }
  dependency_composition_test_put(simulator, plan, "head_state", state)
  dependency_composition_test_put(simulator, plan, "head_reserve", reserve)
  simulator.settle()
}

///|
fn dependency_composition_test_loads(
  simulator : @sim.Simulator,
  plan : DependencyCompositionPlan,
) -> Unit raise {
  // Local environment events: reserve/host-load completion are explicit cuts.
  // Generation state itself is never injected; the original registers update.
  for
    (lanes, writer, ticket) in [
      ([0x0200UL, 0x0002_0001UL, 0x0002_0000_0000UL, 1UL], 1, 0UL),
      ([0x0001_0200UL, 0x0001_0002UL, 0x0001_0000_0000UL, 0UL], 2, 1UL),
    ] {
    dependency_composition_test_command(simulator, plan, lanes, 2UL, 1UL)
    simulator.rising_edge("clock")
    assert_eq(
      dependency_composition_test_get(
        simulator, "current_generation_head_ticket",
      ),
      ticket,
    )
    assert_eq(
      dependency_composition_test_get(
        simulator, "current_generation_next_ticket",
      ),
      ticket + 1UL,
    )
    assert_eq(
      dependency_composition_test_get(
        simulator,
        "current_generation_writer_status_\{writer}",
      ),
      1UL,
    )
    assert_eq(
      dependency_composition_test_get(
        simulator,
        "current_generation_writer_ticket_\{writer}",
      ),
      ticket,
    )
    dependency_composition_test_put(simulator, plan, "head_reserve", 0UL)
    dependency_composition_test_put(simulator, plan, "head_state", 0UL)
    dependency_composition_test_put(simulator, plan, "load_terminal", 1UL)
    dependency_composition_test_put(
      simulator, plan, "load_terminal_ticket", ticket,
    )
    dependency_composition_test_put(simulator, plan, "load_terminal_fault", 0UL)
    simulator.rising_edge("clock")
    assert_eq(
      dependency_composition_test_get(
        simulator,
        "current_generation_writer_status_\{writer}",
      ),
      2UL,
    )
    dependency_composition_test_put(simulator, plan, "load_terminal", 0UL)
  }
}

///|
fn dependency_composition_test_mat(
  simulator : @sim.Simulator,
  plan : DependencyCompositionPlan,
) -> Unit raise {
  dependency_composition_test_command(
    simulator,
    plan,
    [0x0002_0200UL, 0x0002_0001_0001UL, 0UL, 0x0001_0001UL],
    2UL,
    1UL,
  )
  simulator.rising_edge("clock")
  assert_eq(
    dependency_composition_test_get(simulator, "current_generation_head_ticket"),
    2UL,
  )
  assert_eq(
    dependency_composition_test_get(
      simulator, "current_generation_writer_status_5",
    ),
    1UL,
  )
  assert_eq(
    dependency_composition_test_get(
      simulator, "current_generation_writer_ticket_5",
    ),
    2UL,
  )
  for index in 0..<2 {
    assert_eq(
      dependency_composition_test_get(
        simulator,
        "current_generation_dependency_status_\{index}",
      ),
      2UL,
    )
    assert_eq(
      dependency_composition_test_get(
        simulator,
        "current_generation_dependency_ticket_\{index}",
      ),
      index.to_uint64(),
    )
  }
  dependency_composition_test_put(simulator, plan, "head_reserve", 0UL)
  dependency_composition_test_put(simulator, plan, "head_state", 3UL)
  simulator.settle()
  assert_eq(dependency_composition_test_get(simulator, "local_fault"), 0UL)
  assert_eq(dependency_composition_test_get(simulator, "accept"), 1UL)
}

///|
fn dependency_composition_test_identity(
  simulator : @sim.Simulator,
) -> Unit raise {
  for
    (name, expected) in [
      ("ticket", 2UL),
      ("a", 1UL),
      ("b", 0UL),
      ("c", 1UL),
      ("rows", 1UL),
      ("columns", 1UL),
      ("reduction", 2UL),
    ] {
    assert_eq(
      dependency_composition_test_get(simulator, "current_compute_" + name),
      expected,
    )
  }
}
