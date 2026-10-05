///|
test "joint generation compute copies exact 27 production specs without state shadows" {
  let fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let source = fixture.hardware()
  let before = @ir_codec.serialize(@ir.Design::single("Original", source))
  let slice = dependency_composition_sequential(fixture)
  let again = dependency_composition_sequential(fixture)
  assert_eq(slice.hardware, again.hardware)
  assert_eq(slice.plan, again.plan)
  assert_eq(slice.original_to_local, again.original_to_local)
  assert_eq(@ir_codec.serialize(@ir.Design::single("Original", source)), before)
  assert_eq(slice.plan.generation, dependency_generation_discover(fixture))
  assert_eq(slice.plan.compute, dependency_compute_discover(fixture))
  assert_eq(slice.plan.roots.length(), 27)
  assert_eq(
    slice.plan.roots
    .iter()
    .fold(init=0, (sum, root) => sum + root.signal_type.width().bits()),
    416,
  )
  let inputs = slice.hardware.nodes().filter(node => node.kind() is Input(_))
  assert_eq(inputs.length(), 19)
  assert_eq(
    inputs
    .iter()
    .fold(init=0, (sum, node) => sum + node.signal_type().width().bits()),
    341,
  )
  assert_eq(
    slice.hardware.nodes().filter(node => node.kind() is Register(_)).length(),
    27,
  )
  assert_eq(slice.hardware.memories().length(), 0)
  assert_eq(slice.hardware.domains().length(), 1)
  assert_eq(slice.hardware.outputs().length(), 42)
  assert_eq(
    slice.hardware.nodes().length(),
    slice.plan.cuts.length() + slice.plan.cone.length() + 1,
  )
  let clock = dependency_generation_mapped(
    slice.original_to_local,
    slice.plan.clock,
  )
  assert_eq(
    dependency_generation_node(slice.hardware, clock).kind(),
    Input("clock"),
  )
  assert_eq(slice.hardware.domains()[0], @ir.ClockDomain::rising(clock))
  let mut previous = -1
  for original in source.nodes() {
    if slice.original_to_local[original.id().ordinal()] is Some(mapped) {
      assert_true(mapped.ordinal() > previous)
      previous = mapped.ordinal()
      let copy = dependency_generation_node(slice.hardware, mapped)
      assert_eq(copy.signal_type(), original.signal_type())
      if slice.plan.roots.any(root => root.node == original.id()) {
        guard original.kind() is Register(spec) &&
          copy.kind() is Register(copied) else {
          fail("joint root ceased to be an original register")
        }
        assert_eq(
          copied.next(),
          dependency_generation_mapped(slice.original_to_local, spec.next()),
        )
        assert_eq(
          copied.domain().clock(),
          dependency_generation_mapped(
            slice.original_to_local,
            spec.domain().clock(),
          ),
        )
        assert_eq(copied.domain().edge(), spec.domain().edge())
        assert_eq(copied.initial(), spec.initial())
        assert_eq(copied.initial(), None)
        match (copied.enable(), spec.enable()) {
          (None, None) => ()
          (Some(actual), Some(expected)) =>
            assert_eq(
              actual,
              dependency_generation_mapped(slice.original_to_local, expected),
            )
          _ => fail("joint enable drift")
        }
        guard copied.reset() is Some(actual) && spec.reset() is Some(expected) else {
          fail("joint reset missing")
        }
        assert_eq(
          actual.signal(),
          dependency_generation_mapped(
            slice.original_to_local,
            expected.signal(),
          ),
        )
        assert_eq(actual.value(), expected.value())
        assert_eq(actual.mode(), expected.mode())
        assert_eq(actual.polarity(), expected.polarity())
      } else if original.id() != slice.plan.clock {
        let kind = if slice.plan.cuts.any(cut => cut.node == original.id()) {
          @ir.NodeKind::Input("cut_n\{original.id().ordinal()}")
        } else {
          dependency_generation_remap(original.kind(), slice.original_to_local)
        }
        assert_eq(copy.kind(), kind)
      }
    }
  }
  for root in slice.plan.roots {
    guard slice.hardware
      .outputs()
      .filter(output => output.name() == "current_" + root.name)
      is [output] else {
      fail("joint current-state alias missing")
    }
    assert_eq(
      output.driver(),
      dependency_generation_mapped(slice.original_to_local, root.node),
    )
    assert_eq(output.signal_type(), root.signal_type)
    guard dependency_generation_node(source, root.node).kind()
      is Register(actual) else {
      fail("joint metadata root not production state")
    }
    assert_eq(root.spec, actual)
  }
  for node in slice.plan.cone {
    let mapped = dependency_generation_mapped(
      slice.original_to_local,
      node.id(),
    )
    assert_eq(
      dependency_generation_node(slice.hardware, mapped).kind(),
      dependency_generation_remap(node.kind(), slice.original_to_local),
    )
  }
  for
    (name, id) in [
      ("local_fault", slice.plan.generation.local_fault),
      ("local_reject", slice.plan.generation.local_reject),
      ("public_halted", slice.plan.generation.public_halted),
      ("accept", slice.plan.compute.accept),
      ("preflight", slice.plan.compute.preflight),
      ("inner_valid", slice.plan.compute.inner_valid),
      ("inner_ready", slice.plan.compute.inner_ready),
      ("terminal", slice.plan.compute.terminal),
    ] {
    guard slice.hardware.outputs().filter(output => output.name() == name)
      is [output] else {
      fail("joint event alias missing")
    }
    assert_eq(
      output.driver(),
      dependency_generation_mapped(slice.original_to_local, id),
    )
  }
  for binding in slice.plan.generation.decoder_bindings {
    guard slice.hardware
      .outputs()
      .filter(output => output.name() == binding.name)
      is [output] else {
      fail("joint decoder alias missing")
    }
    assert_eq(
      output.driver(),
      dependency_generation_mapped(slice.original_to_local, binding.node),
    )
    assert_eq(output.signal_type(), binding.signal_type)
  }
  for
    id in [
      slice.plan.compute.accept,
      slice.plan.compute.inner_valid,
      slice.plan.compute.terminal,
      slice.plan.generation.public_halted,
    ] {
    assert_false(slice.plan.cuts.any(cut => cut.node == id))
  }
  // Outer terminal ticket/fault use the very same copied compute registers.
  for
    role in [
      @flux_tile.QueuedConcurrentFormalRole::ComputeTerminalTicket,
      ComputeTerminalFault,
    ] {
    let binding = dependency_generation_binding(
      dependency_generation_bindings(fixture),
      role,
    )
    assert_true(slice.plan.roots.any(root => root.node == binding.node))
    assert_false(
      inputs.any(input => {
        input.kind() == Input("cut_n\{binding.node.ordinal()}")
      }),
    )
  }
}

///|
test "joint generation events derive actual admission and saved identity survives held Issue" {
  let slice = dependency_composition_sequential(
    @flux_tile.queued_concurrent_dependency_formal_fixture(),
  )
  let plan = slice.plan
  let simulator = dependency_composition_test_prepare(slice)
  dependency_composition_test_loads(simulator, plan)
  dependency_composition_test_mat(simulator, plan)
  simulator.rising_edge("clock")
  dependency_composition_test_identity(simulator)
  assert_eq(
    dependency_composition_test_get(simulator, "current_compute_state"),
    1UL,
  )
  assert_eq(dependency_composition_test_get(simulator, "inner_valid"), 1UL)
  // Younger A1 publishes/fails while accepted compute remains in Issue.
  // Head and load terminal are local cuts; this is not a full-device trace.
  dependency_composition_test_command(
    simulator,
    plan,
    [0x0200UL, 0x0002_0001UL, 0x0002_0000_0000UL, 1UL],
    2UL,
    1UL,
  )
  simulator.rising_edge("clock")
  assert_eq(
    dependency_composition_test_get(
      simulator, "current_generation_writer_status_1",
    ),
    1UL,
  )
  assert_eq(
    dependency_composition_test_get(
      simulator, "current_generation_writer_ticket_1",
    ),
    3UL,
  )
  assert_eq(
    dependency_composition_test_get(simulator, "current_generation_head_ticket"),
    3UL,
  )
  dependency_composition_test_put(simulator, plan, "head_reserve", 0UL)
  dependency_composition_test_put(simulator, plan, "head_state", 0UL)
  dependency_composition_test_put(simulator, plan, "load_terminal", 1UL)
  dependency_composition_test_put(simulator, plan, "load_terminal_ticket", 3UL)
  dependency_composition_test_put(simulator, plan, "load_terminal_fault", 7UL)
  simulator.rising_edge("clock")
  assert_eq(
    dependency_composition_test_get(
      simulator, "current_generation_writer_status_1",
    ),
    3UL,
  )
  dependency_composition_test_put(simulator, plan, "load_terminal", 0UL)
  // Arbitrary core-valid before Run is ignored by the actual FSM; injected
  // core values below test the extracted boundary, not full-core reachability.
  dependency_composition_test_put(simulator, plan, "core_completion_valid", 1UL)
  dependency_composition_test_put(simulator, plan, "core_completion_id", 99UL)
  let compute_roots = plan.roots.filter(root => root.name.has_prefix("compute_"))
  let held = compute_roots.map(root => simulator.output("current_" + root.name))
  for phase in 0..<3 {
    simulator.set_input(
      "clock",
      @wave.LogicValue::from_uint64(width=1, value=(phase % 2).to_uint64()),
    )
    simulator.settle()
    for index, root in compute_roots {
      assert_eq(simulator.output("current_" + root.name), held[index])
    }
    simulator.rising_edge("clock")
    for index, root in compute_roots {
      assert_eq(simulator.output("current_" + root.name), held[index])
    }
    dependency_composition_test_identity(simulator)
    assert_eq(
      dependency_composition_test_get(simulator, "current_compute_state"),
      1UL,
    )
    assert_eq(dependency_composition_test_get(simulator, "accept"), 0UL)
    assert_eq(dependency_composition_test_get(simulator, "terminal"), 0UL)
  }
  dependency_composition_test_put(simulator, plan, "core_completion_valid", 0UL)
  dependency_composition_test_put(simulator, plan, "inner_ready", 1UL)
  simulator.rising_edge("clock")
  assert_eq(
    dependency_composition_test_get(simulator, "current_compute_state"),
    2UL,
  )
  dependency_composition_test_identity(simulator)
  dependency_composition_test_put(simulator, plan, "core_completion_valid", 1UL)
  dependency_composition_test_put(simulator, plan, "core_completion_id", 2UL)
  dependency_composition_test_put(simulator, plan, "core_completion_fault", 0UL)
  simulator.rising_edge("clock")
  assert_eq(dependency_composition_test_get(simulator, "terminal"), 1UL)
  assert_eq(
    dependency_composition_test_get(simulator, "current_compute_fault"),
    0UL,
  )
  assert_eq(
    dependency_composition_test_get(
      simulator, "current_generation_writer_status_5",
    ),
    1UL,
  )
  simulator.rising_edge("clock")
  assert_eq(
    dependency_composition_test_get(simulator, "current_compute_state"),
    0UL,
  )
  assert_eq(
    dependency_composition_test_get(
      simulator, "current_generation_writer_status_5",
    ),
    2UL,
  )
  assert_eq(
    dependency_composition_test_get(
      simulator, "current_generation_writer_ticket_5",
    ),
    2UL,
  )
  dependency_composition_test_identity(simulator)
}

///|
test "joint preflight failure and reset interruption preserve actual generation priority" {
  let slice = dependency_composition_sequential(
    @flux_tile.queued_concurrent_dependency_formal_fixture(),
  )
  let plan = slice.plan
  let simulator = dependency_composition_test_prepare(slice)
  dependency_composition_test_loads(simulator, plan)
  dependency_composition_test_mat(simulator, plan)
  // Preflight is the declared physical-shape/core boundary, not an oracle.
  dependency_composition_test_put(simulator, plan, "preflight", 4UL)
  simulator.rising_edge("clock")
  dependency_composition_test_identity(simulator)
  assert_eq(
    dependency_composition_test_get(simulator, "current_compute_state"),
    3UL,
  )
  assert_eq(
    dependency_composition_test_get(simulator, "current_compute_fault"),
    4UL,
  )
  assert_eq(dependency_composition_test_get(simulator, "inner_valid"), 0UL)
  assert_eq(
    dependency_composition_test_get(
      simulator, "current_generation_writer_status_5",
    ),
    1UL,
  )
  dependency_composition_test_put(simulator, plan, "head_state", 0UL)
  simulator.rising_edge("clock")
  assert_eq(
    dependency_composition_test_get(
      simulator, "current_generation_writer_status_5",
    ),
    3UL,
  )
  assert_eq(
    dependency_composition_test_get(simulator, "current_compute_state"),
    0UL,
  )
  // Start afresh, reach Issue, then make every event compete with reset.
  dependency_composition_test_put(simulator, plan, "reset", 1UL)
  simulator.rising_edge("clock")
  dependency_composition_test_put(simulator, plan, "reset", 0UL)
  dependency_composition_test_put(simulator, plan, "preflight", 0UL)
  dependency_composition_test_loads(simulator, plan)
  dependency_composition_test_mat(simulator, plan)
  simulator.rising_edge("clock")
  assert_eq(
    dependency_composition_test_get(simulator, "current_compute_state"),
    1UL,
  )
  dependency_composition_test_put(simulator, plan, "head_reserve", 1UL)
  dependency_composition_test_put(simulator, plan, "load_terminal", 1UL)
  dependency_composition_test_put(simulator, plan, "load_terminal_ticket", 0UL)
  dependency_composition_test_put(simulator, plan, "inner_ready", 1UL)
  dependency_composition_test_put(simulator, plan, "core_completion_valid", 1UL)
  dependency_composition_test_put(simulator, plan, "reset", 1UL)
  simulator.settle()
  dependency_composition_test_identity(simulator)
  for name in ["accept", "inner_valid", "terminal", "public_halted"] {
    assert_eq(dependency_composition_test_get(simulator, name), 0UL)
  }
  simulator.rising_edge("clock")
  for root in plan.roots {
    assert_eq(
      dependency_composition_test_get(simulator, "current_" + root.name),
      0UL,
    )
  }
}
