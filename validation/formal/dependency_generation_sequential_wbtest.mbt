///|
test "generation sequential copies exact production registers cone and aliases" {
  let fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let source = fixture.hardware()
  let before = @ir_codec.serialize(@ir.Design::single("Original", source))
  let sequential = dependency_generation_sequential(fixture)
  let repeated = dependency_generation_sequential(fixture)
  assert_eq(sequential.hardware, repeated.hardware)
  assert_eq(sequential.plan, repeated.plan)
  assert_eq(sequential.original_to_local, repeated.original_to_local)
  assert_eq(@ir_codec.serialize(@ir.Design::single("Original", source)), before)
  let plan = sequential.plan
  let inputs = sequential.hardware
    .nodes()
    .filter(node => node.kind() is Input(_))
  let registers = sequential.hardware
    .nodes()
    .filter(node => node.kind() is Register(_))
  assert_eq(inputs.length(), 15)
  assert_eq(registers.length(), 18)
  assert_eq(
    inputs
    .iter()
    .fold(init=0, (sum, node) => sum + node.signal_type().width().bits()),
    336,
  )
  assert_eq(
    registers
    .iter()
    .fold(init=0, (sum, node) => sum + node.signal_type().width().bits()),
    336,
  )
  assert_eq(sequential.hardware.domains().length(), 1)
  assert_eq(sequential.hardware.memories().length(), 0)
  assert_eq(sequential.hardware.outputs().length(), 28)
  assert_eq(
    sequential.hardware.nodes().length(),
    plan.cuts.length() + plan.cone.length() + 1,
  )
  let mapped_clock = dependency_generation_mapped(
    sequential.original_to_local,
    plan.clock,
  )
  assert_eq(
    dependency_generation_node(sequential.hardware, mapped_clock).kind(),
    Input("clock"),
  )
  assert_eq(
    sequential.hardware.domains()[0],
    @ir.ClockDomain::rising(mapped_clock),
  )
  let mut previous = -1
  for original in source.nodes() {
    if sequential.original_to_local[original.id().ordinal()] is Some(mapped) {
      assert_true(mapped.ordinal() > previous)
      previous = mapped.ordinal()
      assert_eq(
        dependency_generation_node(sequential.hardware, mapped).signal_type(),
        original.signal_type(),
      )
    }
  }
  for index, root in plan.roots {
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      root.binding.node,
    )
    guard dependency_generation_node(sequential.hardware, mapped).kind()
      is Register(spec) else {
      fail("state root is not a copied register")
    }
    assert_eq(
      spec.next(),
      dependency_generation_mapped(
        sequential.original_to_local,
        root.spec.next(),
      ),
    )
    assert_eq(
      spec.domain().clock(),
      dependency_generation_mapped(
        sequential.original_to_local,
        root.spec.domain().clock(),
      ),
    )
    assert_eq(spec.domain().edge(), root.spec.domain().edge())
    assert_eq(spec.initial(), root.spec.initial())
    assert_eq(spec.initial(), None)
    match (spec.enable(), root.spec.enable()) {
      (None, None) => ()
      (Some(copy), Some(original)) =>
        assert_eq(
          copy,
          dependency_generation_mapped(sequential.original_to_local, original),
        )
      _ => fail("register enable drift")
    }
    guard spec.reset() is Some(copy) && root.spec.reset() is Some(original) else {
      fail("missing copied synchronous reset")
    }
    assert_eq(
      copy.signal(),
      dependency_generation_mapped(
        sequential.original_to_local,
        original.signal(),
      ),
    )
    assert_eq(copy.value(), original.value())
    assert_eq(copy.mode(), original.mode())
    assert_eq(copy.polarity(), original.polarity())
    let output = sequential.hardware.outputs()[index]
    assert_eq(
      output.name(),
      "current_" + dependency_role_name(root.binding.role),
    )
    assert_eq(output.driver(), mapped)
    assert_eq(output.signal_type(), root.binding.signal_type)
  }
  for cut in plan.cuts {
    if !plan.roots.any(root => root.binding.node == cut.node) {
      let mapped = dependency_generation_mapped(
        sequential.original_to_local,
        cut.node,
      )
      assert_eq(
        dependency_generation_node(sequential.hardware, mapped).kind(),
        Input("cut_n\{cut.node.ordinal()}"),
      )
    }
  }
  for original in plan.cone {
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      original.id(),
    )
    assert_eq(
      dependency_generation_node(sequential.hardware, mapped).kind(),
      dependency_generation_remap(original.kind(), sequential.original_to_local),
    )
  }
  for
    index, (name, original) in [
      ("local_fault", plan.local_fault),
      ("local_reject", plan.local_reject),
      ("public_halted", plan.public_halted),
    ] {
    assert_eq(sequential.hardware.outputs()[18 + index].name(), name)
    assert_eq(
      sequential.hardware.outputs()[18 + index].driver(),
      dependency_generation_mapped(sequential.original_to_local, original),
    )
  }
  for index, binding in plan.decoder_bindings {
    assert_eq(sequential.hardware.outputs()[21 + index].name(), binding.name)
    assert_eq(
      sequential.hardware.outputs()[21 + index].driver(),
      dependency_generation_mapped(sequential.original_to_local, binding.node),
    )
  }
}

///|
test "generation sequential retains unknown initialization and synchronous reset" {
  let sequential = dependency_generation_sequential(
    @flux_tile.queued_concurrent_dependency_formal_fixture(),
  )
  let simulator = @sim.Simulator::prepare(sequential.hardware)
  for cut in sequential.plan.cuts {
    if !sequential.plan.roots.any(root => root.binding.node == cut.node) {
      dependency_generation_drive_cut(simulator, cut, 0xffff_ffff_ffff_ffffUL)
    }
  }
  simulator.set_input(
    "clock",
    @wave.LogicValue::from_uint64(width=1, value=1UL),
  )
  simulator.settle()
  // Setting Clock/Reset inputs is not an active-domain event. Synchronous
  // reset must not silently initialize an otherwise arbitrary register bank.
  for root in sequential.plan.roots {
    assert_true(
      simulator
      .output("current_" + dependency_role_name(root.binding.role))
      .is_fully_unknown(),
    )
  }
  assert_eq(simulator.output("public_halted").to_uint64(), 0UL)
  simulator.rising_edge("clock")
  for root in sequential.plan.roots {
    assert_eq(
      simulator
      .output("current_" + dependency_role_name(root.binding.role))
      .to_uint64(),
      0UL,
    )
  }
  assert_eq(simulator.cycle().value(), 1UL)
}

///|
fn dependency_generation_sequential_role_cut(
  simulator : @sim.Simulator,
  plan : DependencyGenerationPlan,
  role : @flux_tile.QueuedConcurrentFormalRole,
  value : UInt64,
) -> Unit raise {
  guard plan.cuts.filter(cut => cut.roles.contains(dependency_role_name(role)))
    is [cut] else {
    fail("missing unique sequential boundary cut")
  }
  dependency_generation_drive_cut(simulator, cut, value)
}

///|
test "generation sequential active edges equal exact transfer and nonedges hold" {
  let fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let sequential = dependency_generation_sequential(fixture)
  let transfer = dependency_generation_materialize(fixture)
  let simulator = @sim.Simulator::prepare(sequential.hardware)
  let combinational = @sim.Simulator::prepare(transfer.hardware)
  for step in 0..<6 {
    for cut in sequential.plan.cuts {
      if !sequential.plan.roots.any(root => root.binding.node == cut.node) {
        dependency_generation_drive_cut(simulator, cut, 0UL)
      }
    }
    guard sequential.plan.cuts.filter(cut => cut.node == sequential.plan.reset)
      is [reset] else {
      fail("missing reset cut")
    }
    dependency_generation_drive_cut(
      simulator,
      reset,
      if step == 0 || step == 5 {
        1UL
      } else {
        0UL
      },
    )
    if step == 1 || step == 3 {
      dependency_generation_sequential_role_cut(
        simulator,
        sequential.plan,
        HeadReserve,
        1UL,
      )
      dependency_generation_sequential_role_cut(
        simulator,
        sequential.plan,
        HeadLane(0),
        0x0200UL,
      )
      dependency_generation_sequential_role_cut(
        simulator,
        sequential.plan,
        HeadLane(1),
        0x0001_0001UL,
      )
    }
    if step >= 2 {
      dependency_generation_sequential_role_cut(
        simulator,
        sequential.plan,
        LoadTerminal,
        1UL,
      )
      dependency_generation_sequential_role_cut(
        simulator,
        sequential.plan,
        LoadTerminalTicket,
        if step == 4 {
          1UL
        } else {
          0UL
        },
      )
      dependency_generation_sequential_role_cut(
        simulator,
        sequential.plan,
        LoadTerminalFault,
        if step == 4 {
          7UL
        } else {
          0UL
        },
      )
    }
    simulator.settle()
    let held : Array[@wave.LogicValue] = []
    for root in sequential.plan.roots {
      held.push(
        simulator.output("current_" + dependency_role_name(root.binding.role)),
      )
    }
    simulator.set_input(
      "clock",
      @wave.LogicValue::from_uint64(width=1, value=(step % 2).to_uint64()),
    )
    simulator.settle()
    for index, root in sequential.plan.roots {
      assert_eq(
        simulator.output("current_" + dependency_role_name(root.binding.role)),
        held[index],
      )
    }
    // Feed the exact current bank and shared boundary into the existing
    // transfer; this checks edge lowering, not independent ghost correctness.
    for cut in transfer.plan.cuts {
      let mapped = dependency_generation_mapped(
        sequential.original_to_local,
        cut.node,
      )
      combinational.set_input(
        "cut_n\{cut.node.ordinal()}",
        simulator.value(mapped),
      )
    }
    combinational.settle()
    let expected : Array[@wave.LogicValue] = []
    for root in sequential.plan.roots {
      expected.push(
        combinational.output("post_" + dependency_role_name(root.binding.role)),
      )
    }
    simulator.rising_edge("clock")
    for index, root in sequential.plan.roots {
      assert_eq(
        simulator.output("current_" + dependency_role_name(root.binding.role)),
        expected[index],
      )
    }
    if step == 1 || step == 3 {
      assert_eq(simulator.output("current_writer_status_0").to_uint64(), 1UL)
      assert_eq(
        simulator.output("current_writer_ticket_0").to_uint64(),
        if step == 1 {
          0UL
        } else {
          1UL
        },
      )
    }
    if step == 2 {
      assert_eq(simulator.output("current_writer_status_0").to_uint64(), 2UL)
    }
    if step == 4 {
      assert_eq(simulator.output("current_writer_status_0").to_uint64(), 3UL)
    }
  }
}
