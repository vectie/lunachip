///|
fn dependency_generation_drive_cut(
  simulator : @sim.Simulator,
  cut : DependencyGenerationCut,
  value : UInt64,
) -> Unit raise {
  simulator.set_input(
    "cut_n\{cut.node.ordinal()}",
    @wave.LogicValue::from_uint64(width=cut.signal_type.width().bits(), value~),
  )
}

///|
test "generation transfer preserves the production graph and exact typed cut inventory" {
  let fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let before = @ir_codec.serialize(
    @ir.Design::single("Original", fixture.hardware()),
  )
  let transfer = dependency_generation_materialize(fixture)
  let repeated = dependency_generation_materialize(fixture)
  assert_eq(transfer.hardware, repeated.hardware)
  assert_eq(transfer.plan, repeated.plan)
  assert_eq(transfer.original_to_local, repeated.original_to_local)
  assert_eq(
    @ir_codec.serialize(@ir.Design::single("Original", fixture.hardware())),
    before,
  )
  assert_eq(transfer.hardware.memories().length(), 0)
  assert_eq(transfer.hardware.domains().length(), 0)
  assert_eq(transfer.hardware.outputs().length(), 28)
  let inputs = transfer.hardware.nodes().filter(node => node.kind() is Input(_))
  assert_eq(inputs.length(), transfer.plan.cuts.length())
  for index, cut in transfer.plan.cuts {
    assert_eq(inputs[index].signal_type(), cut.signal_type)
    assert_eq(inputs[index].kind(), Input("cut_n\{cut.node.ordinal()}"))
  }
  for original in transfer.plan.cone {
    let mapped_id = dependency_generation_mapped(
      transfer.original_to_local,
      original.id(),
    )
    guard transfer.hardware.node(mapped_id) is Some(copy) else {
      fail("missing copied node")
    }
    assert_eq(copy.signal_type(), original.signal_type())
    assert_eq(
      copy.kind(),
      dependency_generation_remap(original.kind(), transfer.original_to_local),
    )
    assert_false(copy.kind() is Register(_) || copy.kind() is MemoryRead(..))
  }
  let emitted = @rtl.emit_design(
    @ir.Design::single("Transfer", transfer.hardware),
  )
  assert_false(emitted.source().contains("always_ff"))
  assert_eq(transfer.hardware.outputs()[0].name(), "post_next_ticket")
}

///|
test "generation transfer reset dominates arbitrary prestate and event payloads" {
  let transfer = dependency_generation_materialize(
    @flux_tile.queued_concurrent_dependency_formal_fixture(),
  )
  let simulator = @sim.Simulator::prepare(transfer.hardware)
  for cut in transfer.plan.cuts {
    dependency_generation_drive_cut(simulator, cut, 0xffff_ffff_ffff_ffffUL)
  }
  simulator.settle()
  for root in transfer.plan.roots {
    assert_eq(
      simulator
      .output("post_" + dependency_role_name(root.binding.role))
      .to_uint64(),
      0UL,
    )
  }
  assert_eq(simulator.output("public_halted").to_uint64(), 0UL)
}

///|
test "generation transfer holds all free current fields without agreed events" {
  let transfer = dependency_generation_materialize(
    @flux_tile.queued_concurrent_dependency_formal_fixture(),
  )
  let simulator = @sim.Simulator::prepare(transfer.hardware)
  for cut in transfer.plan.cuts {
    dependency_generation_drive_cut(simulator, cut, 0UL)
  }
  for index, root in transfer.plan.roots {
    // Nonzero and deliberately unrelated fields; no initial-zero clamping.
    let value = if root.binding.signal_type.width().bits() == 2 {
      (index % 4).to_uint64()
    } else {
      0xffff_fff0UL + index.to_uint64()
    }
    guard transfer.plan.cuts.filter(cut => cut.node == root.binding.node)
      is [cut] else {
      fail("missing unique state cut")
    }
    dependency_generation_drive_cut(simulator, cut, value)
  }
  simulator.settle()
  for root in transfer.plan.roots {
    let current = dependency_generation_mapped(
      transfer.original_to_local,
      root.binding.node,
    )
    assert_eq(
      simulator.output("post_" + dependency_role_name(root.binding.role)),
      simulator.value(current),
    )
  }
}

///|
test "generation edge transfer gives reset priority over enable and disabled hold" {
  let nodes : Array[@ir.Node] = []
  let clock = dependency_generation_append(nodes, Clock, Input("clock"))
  let current = dependency_generation_append(
    nodes,
    @wire.uint(32),
    Input("current"),
  )
  let next = dependency_generation_append(nodes, @wire.uint(32), Input("next"))
  let enable = dependency_generation_append(
    nodes,
    @wire.bits(1),
    Input("enable"),
  )
  let reset = dependency_generation_append(nodes, Reset, Input("reset"))
  let reset_select = dependency_generation_append(
    nodes,
    @wire.bits(1),
    Reinterpret(reset),
  )
  let root : DependencyGenerationRoot = {
    binding: { role: NextTicket, node: current, signal_type: @wire.uint(32), },
    spec: @ir.RegisterSpec::new(
      @ir.ClockDomain::rising(clock),
      next,
      enable~,
      reset=@ir.ResetSpec::new(reset, 0UL),
    ),
  }
  let mapping : Array[@ir.NodeId?] = [
    Some(clock),
    Some(current),
    Some(next),
    Some(enable),
    Some(reset),
  ]
  let post = dependency_generation_edge_transfer(
    nodes, mapping, root, reset_select,
  )
  let hardware = @ir.Module::checked("EnabledGenerationTransfer", nodes, [
    @ir.OutputPort::new("post", @wire.uint(32), post),
  ])
  let simulator = @sim.Simulator::prepare(hardware)
  simulator.set_input(
    "current",
    @wave.LogicValue::from_uint64(width=32, value=0xffff_ffffUL),
  )
  simulator.set_input(
    "next",
    @wave.LogicValue::from_uint64(width=32, value=17UL),
  )
  for reset_value in 0..<2 {
    for enable_value in 0..<2 {
      simulator.set_input(
        "reset",
        @wave.LogicValue::from_uint64(width=1, value=reset_value.to_uint64()),
      )
      simulator.set_input(
        "enable",
        @wave.LogicValue::from_uint64(width=1, value=enable_value.to_uint64()),
      )
      simulator.settle()
      let expected = if reset_value == 1 {
        0UL
      } else if enable_value == 1 {
        17UL
      } else {
        0xffff_ffffUL
      }
      assert_eq(simulator.output("post").to_uint64(), expected)
    }
  }
}
