///|
fn queue_control_test_put(
  simulator : @sim.Simulator,
  plan : QueueControlPlan,
  role : String,
  value : UInt64,
) -> Unit raise {
  guard plan.cuts.filter(cut => cut.roles.contains(role)) is [cut] else {
    fail("missing queue-control boundary: " + role)
  }
  assert_false(plan.roots.any(root => root.node == cut.node))
  dependency_generation_drive_cut(simulator, cut, value)
}

///|
fn queue_control_test_get(
  simulator : @sim.Simulator,
  name : String,
) -> UInt64 raise {
  simulator.output(name).to_uint64()
}

///|
fn queue_control_test_prepare(
  slice : QueueControlSequential,
) -> @sim.Simulator raise {
  let simulator = @sim.Simulator::prepare(slice.hardware)
  for cut in slice.plan.cuts {
    if !slice.plan.roots.any(root => root.node == cut.node) {
      dependency_generation_drive_cut(simulator, cut, 0UL)
    }
  }
  queue_control_test_put(simulator, slice.plan, "reset", 1UL)
  simulator.settle()
  for root in slice.plan.roots {
    assert_true(simulator.output("current_" + root.name).is_fully_unknown())
  }
  simulator.rising_edge("clock")
  for root in slice.plan.roots {
    assert_eq(queue_control_test_get(simulator, "current_" + root.name), 0UL)
  }
  queue_control_test_put(simulator, slice.plan, "reset", 0UL)
  simulator.settle()
  simulator
}

///|
fn queue_control_test_lanes(
  simulator : @sim.Simulator,
  occupancy : UInt64,
  response : UInt64,
) -> Unit raise {
  for lane in 0..<4 {
    assert_eq(
      queue_control_test_get(simulator, "current_fifo_occupancy_\{lane}"),
      occupancy,
    )
    assert_eq(
      queue_control_test_get(simulator, "current_fifo_response_valid_\{lane}"),
      response,
    )
  }
}

///|
fn queue_control_test_ring(
  simulator : @sim.Simulator,
  read : UInt64,
  write : UInt64,
  occupancy : UInt64,
  valid : ArrayView[UInt64],
) -> Unit raise {
  assert_eq(valid.length(), 3)
  assert_eq(
    queue_control_test_get(simulator, "current_retirement_read_pointer"),
    read,
  )
  assert_eq(
    queue_control_test_get(simulator, "current_retirement_write_pointer"),
    write,
  )
  assert_eq(
    queue_control_test_get(simulator, "current_retirement_occupancy"),
    occupancy,
  )
  for entry, value in valid {
    assert_eq(
      queue_control_test_get(simulator, "current_entry_valid_\{entry}"),
      value,
    )
  }
}

///|
test "queue control copies sixteen exact production specs and no extra graph leaves" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let source = fixture.hardware()
  let before = @ir_codec.serialize(@ir.Design::single("Original", source))
  let slice = queue_control_sequential(fixture)
  let repeated = queue_control_sequential(fixture)
  assert_eq(slice, repeated)
  assert_eq(@ir_codec.serialize(@ir.Design::single("Original", source)), before)
  assert_eq(slice.plan.roots.length(), 16)
  assert_eq(
    slice.plan.roots
    .iter()
    .fold(init=0, (sum, root) => sum + root.signal_type.width().bits()),
    37,
  )
  assert_eq(slice.plan.cuts.length(), 24)
  assert_eq(
    slice.hardware.nodes().filter(node => node.kind() is Input(_)).length(),
    9,
  )
  assert_eq(
    slice.hardware.nodes().filter(node => node.kind() is Register(_)).length(),
    16,
  )
  assert_eq(slice.hardware.memories().length(), 0)
  assert_eq(slice.hardware.domains().length(), 1)
  assert_eq(
    slice.hardware.nodes().length(),
    slice.plan.cuts.length() + slice.plan.cone.length() + 1,
  )
  assert_eq(
    slice.hardware.outputs().length(),
    slice.plan.roots.length() + slice.plan.events.length(),
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
      let copied = dependency_generation_node(slice.hardware, mapped)
      assert_eq(copied.signal_type(), original.signal_type())
      match slice.plan.roots.filter(root => root.node == original.id()) {
        [root] => {
          guard original.kind() is Register(actual) else {
            fail("root lost original register")
          }
          assert_eq(root.spec, actual)
          // Full kind equality checks edge, initial unknown, next, enable,
          // synchronous reset value/polarity and every mapped control.
          assert_eq(
            copied.kind(),
            dependency_sequential_register_kind(actual, slice.original_to_local),
          )
        }
        [] => {
          let kind : @ir.NodeKind = if original.id() == slice.plan.clock {
            Input("clock")
          } else if slice.plan.cuts.any(cut => cut.node == original.id()) {
            Input("cut_n\{original.id().ordinal()}")
          } else {
            dependency_generation_remap(
              original.kind(),
              slice.original_to_local,
            )
          }
          assert_eq(copied.kind(), kind)
        }
        _ => fail("aliased state roots")
      }
    }
  }
  for root in slice.plan.roots {
    guard slice.hardware
      .outputs()
      .filter(output => output.name() == "current_" + root.name)
      is [output] else {
      fail("missing current-state alias")
    }
    assert_eq(
      output.driver(),
      dependency_generation_mapped(slice.original_to_local, root.node),
    )
    assert_eq(output.signal_type(), root.signal_type)
  }
  for event in slice.plan.events {
    guard slice.hardware.outputs().filter(output => output.name() == event.name)
      is [output] else {
      fail("missing original event alias")
    }
    assert_eq(
      output.driver(),
      dependency_generation_mapped(slice.original_to_local, event.node),
    )
    assert_eq(output.signal_type(), event.signal_type)
    if event.name != "dispatch_finish_raw" {
      assert_false(slice.plan.cuts.any(cut => cut.node == event.node))
    }
  }
  let boundaries = slice.plan.cuts.filter(cut => {
    !slice.plan.roots.any(root => root.node == cut.node)
  })
  assert_eq(boundaries.length(), 8)
  for
    role in [
      "reset", "descriptor_valid", "completion_ready", "raw_poison", "head_finish",
      "entry_terminal_0", "entry_terminal_1", "entry_terminal_2",
    ] {
    assert_eq(boundaries.filter(cut => cut.roles.contains(role)).length(), 1)
  }
}

///|
test "queue control discovery rejects a false ground type and an unlisted next-state leaf" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let hardware = fixture.hardware()
  let plan = queue_control_discover(fixture)
  let binding = queue_control_binding(fixture, HeadState)
  try
    queue_control_root(
      hardware,
      { ..binding, signal_type: @wire.bits(2), },
      plan.clock,
      plan.reset,
    )
  catch {
    InvalidFormalBundleIdentity(_) => ()
    error => fail("unexpected root type error: \{Repr(error)}")
  } noraise {
    _ => fail("wrong ground type was accepted")
  }
  // A changed next expression cannot silently pull packet storage or an
  // unretained sequential owner into this deliberately control-only cone.
  for node in hardware.nodes() {
    if !plan.cuts.any(cut => cut.node == node.id()) &&
      (node.kind() is Register(_) || node.kind() is MemoryRead(..)) {
      try
        dependency_generation_closure(hardware, plan.cuts, [node.id()])
      catch {
        InvalidFormalBundleIdentity(_) => ()
        error => fail("unexpected closure error: \{Repr(error)}")
      } noraise {
        _ => fail("unlisted next-state leaf was accepted")
      }
    }
  }
}

///|
test "queue control preserves synchronous response gap full pop refill and held state" {
  let slice = queue_control_sequential(
    @flux_tile.queued_concurrent_queue_formal_fixture(),
  )
  let plan = slice.plan
  let simulator = queue_control_test_prepare(slice)
  queue_control_test_put(simulator, plan, "descriptor_valid", 1UL)
  // A raw finish in Idle must not bypass the actual state-zero transition.
  queue_control_test_put(simulator, plan, "head_finish", 1UL)
  simulator.rising_edge("clock")
  assert_eq(queue_control_test_get(simulator, "current_head_state"), 0UL)
  queue_control_test_lanes(simulator, 1UL, 0UL)
  assert_eq(queue_control_test_get(simulator, "head_pop"), 1UL)
  simulator.rising_edge("clock")
  assert_eq(queue_control_test_get(simulator, "current_head_state"), 1UL)
  queue_control_test_lanes(simulator, 1UL, 1UL)
  assert_eq(queue_control_test_get(simulator, "head_capture"), 1UL)
  queue_control_test_put(simulator, plan, "descriptor_valid", 0UL)
  simulator.rising_edge("clock")
  assert_eq(queue_control_test_get(simulator, "current_head_state"), 2UL)
  queue_control_test_lanes(simulator, 1UL, 0UL)
  assert_eq(queue_control_test_get(simulator, "head_reserve"), 1UL)
  simulator.rising_edge("clock")
  assert_eq(queue_control_test_get(simulator, "current_head_state"), 3UL)
  assert_eq(queue_control_test_get(simulator, "current_head_entry"), 0UL)
  queue_control_test_ring(simulator, 0UL, 1UL, 1UL, [1UL, 0UL, 0UL])
  queue_control_test_put(simulator, plan, "head_finish", 0UL)
  queue_control_test_put(simulator, plan, "descriptor_valid", 1UL)
  simulator.rising_edge("clock")
  simulator.rising_edge("clock")
  queue_control_test_lanes(simulator, 3UL, 0UL)
  assert_eq(queue_control_test_get(simulator, "descriptor_ready"), 0UL)
  // No rising edge: data peers may change, but all original state must hold.
  let held : Array[UInt64] = []
  for root in plan.roots {
    held.push(queue_control_test_get(simulator, "current_" + root.name))
  }
  queue_control_test_put(simulator, plan, "head_finish", 1UL)
  queue_control_test_put(simulator, plan, "entry_terminal_2", 1UL)
  simulator.settle()
  for index, root in plan.roots {
    assert_eq(
      queue_control_test_get(simulator, "current_" + root.name),
      held[index],
    )
  }
  simulator.rising_edge("clock")
  assert_eq(queue_control_test_get(simulator, "current_head_state"), 0UL)
  assert_eq(queue_control_test_get(simulator, "descriptor_ready"), 1UL)
  for lane in 0..<4 {
    assert_eq(queue_control_test_get(simulator, "fifo_full_\{lane}"), 1UL)
    assert_eq(queue_control_test_get(simulator, "fifo_push_ready_\{lane}"), 1UL)
    assert_eq(
      queue_control_test_get(simulator, "fifo_pop_request_\{lane}"),
      1UL,
    )
  }
  simulator.rising_edge("clock")
  // Original per-lane full pop/refill holds occupancy; response arrives now.
  queue_control_test_lanes(simulator, 3UL, 1UL)
  assert_eq(queue_control_test_get(simulator, "current_head_state"), 1UL)
  queue_control_test_put(simulator, plan, "raw_poison", 1UL)
  simulator.settle()
  assert_eq(queue_control_test_get(simulator, "public_halted"), 1UL)
  assert_eq(queue_control_test_get(simulator, "descriptor_ready"), 0UL)
  queue_control_test_put(simulator, plan, "reset", 1UL)
  simulator.settle()
  assert_eq(queue_control_test_get(simulator, "public_halted"), 0UL)
  assert_eq(queue_control_test_get(simulator, "head_capture"), 0UL)
  assert_eq(queue_control_test_get(simulator, "head_reserve"), 0UL)
  assert_eq(queue_control_test_get(simulator, "retirement_fire"), 0UL)
  simulator.rising_edge("clock")
  for root in plan.roots {
    assert_eq(queue_control_test_get(simulator, "current_" + root.name), 0UL)
  }
}

///|
test "queue control keeps contiguous ring through full hold simultaneous reserve retire and wrap" {
  let slice = queue_control_sequential(
    @flux_tile.queued_concurrent_queue_formal_fixture(),
  )
  let plan = slice.plan
  let simulator = queue_control_test_prepare(slice)
  for command in 0..<4 {
    assert_eq(queue_control_test_get(simulator, "current_head_state"), 0UL)
    queue_control_test_put(simulator, plan, "descriptor_valid", 1UL)
    simulator.rising_edge("clock") // admit
    queue_control_test_put(simulator, plan, "descriptor_valid", 0UL)
    simulator.rising_edge("clock") // pop
    queue_control_test_lanes(simulator, 0UL, 1UL)
    simulator.rising_edge("clock") // capture
    assert_eq(queue_control_test_get(simulator, "current_head_state"), 2UL)
    if command == 3 {
      break
    }
    assert_eq(queue_control_test_get(simulator, "head_reserve"), 1UL)
    simulator.rising_edge("clock") // reserve
    assert_eq(
      queue_control_test_get(simulator, "current_head_entry"),
      command.to_uint64(),
    )
    queue_control_test_put(simulator, plan, "head_finish", 1UL)
    simulator.rising_edge("clock") // actual state-three consumption
    queue_control_test_put(simulator, plan, "head_finish", 0UL)
  }
  queue_control_test_ring(simulator, 0UL, 0UL, 3UL, [1UL, 1UL, 1UL])
  assert_eq(queue_control_test_get(simulator, "head_reserve"), 0UL)
  for entry in 0..<3 {
    queue_control_test_put(simulator, plan, "entry_terminal_\{entry}", 1UL)
  }
  simulator.settle()
  assert_eq(queue_control_test_get(simulator, "retirement_valid"), 1UL)
  assert_eq(queue_control_test_get(simulator, "retirement_fire"), 0UL)
  simulator.rising_edge("clock")
  queue_control_test_ring(simulator, 0UL, 0UL, 3UL, [1UL, 1UL, 1UL])
  assert_eq(queue_control_test_get(simulator, "current_head_state"), 2UL)
  queue_control_test_put(simulator, plan, "completion_ready", 1UL)
  simulator.rising_edge("clock") // pre-full reserve still false, ACK entry0
  queue_control_test_ring(simulator, 1UL, 0UL, 2UL, [0UL, 1UL, 1UL])
  assert_eq(queue_control_test_get(simulator, "entry_allocate_0"), 1UL)
  assert_eq(queue_control_test_get(simulator, "entry_acknowledge_1"), 1UL)
  simulator.rising_edge("clock") // reserve entry0 + retire entry1
  queue_control_test_ring(simulator, 2UL, 1UL, 2UL, [1UL, 0UL, 1UL])
  assert_eq(queue_control_test_get(simulator, "current_head_entry"), 0UL)
  assert_eq(queue_control_test_get(simulator, "current_head_state"), 3UL)
  queue_control_test_put(simulator, plan, "completion_ready", 0UL)
  queue_control_test_put(simulator, plan, "head_finish", 1UL)
  simulator.rising_edge("clock")
  queue_control_test_ring(simulator, 2UL, 1UL, 2UL, [1UL, 0UL, 1UL])
  queue_control_test_put(simulator, plan, "completion_ready", 1UL)
  simulator.rising_edge("clock")
  queue_control_test_ring(simulator, 0UL, 1UL, 1UL, [1UL, 0UL, 0UL])
  simulator.rising_edge("clock")
  queue_control_test_ring(simulator, 1UL, 1UL, 0UL, [0UL, 0UL, 0UL])
  assert_eq(queue_control_test_get(simulator, "retirement_valid"), 0UL)
  // Terminals are arbitrary data peers, not proof of actual engine completion.
  // A later reset cancels pending/free observations and clears saved head entry.
  queue_control_test_put(simulator, plan, "reset", 1UL)
  simulator.rising_edge("clock")
  for root in plan.roots {
    assert_eq(queue_control_test_get(simulator, "current_" + root.name), 0UL)
  }
}
