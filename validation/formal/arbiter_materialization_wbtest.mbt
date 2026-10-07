///|
fn arbiter_materialization_test_id(
  mapping : ArrayView[@ir.NodeId?],
  original : @ir.NodeId,
) -> @ir.NodeId raise {
  guard mapping.get(original.ordinal()) is Some(Some(mapped)) else {
    fail("original arbiter operand missing from materialization")
  }
  mapped
}

///|
// This independent comparator covers the operations of the accepted original
// arbiter cone. It does not invoke the materializer's shared remapping helper.
fn arbiter_materialization_test_kind(
  original : @ir.NodeKind,
  mapping : ArrayView[@ir.NodeId?],
) -> @ir.NodeKind raise {
  fn mapped(id) raise {
    arbiter_materialization_test_id(mapping, id)
  }
  match original {
    Constant(value) => Constant(value)
    Reinterpret(value) => Reinterpret(mapped(value))
    BitNot(value) => BitNot(mapped(value))
    BitAnd(left, right) => BitAnd(mapped(left), mapped(right))
    BitOr(left, right) => BitOr(mapped(left), mapped(right))
    Equal(left, right) => Equal(mapped(left), mapped(right))
    LessEqual(left, right) => LessEqual(mapped(left), mapped(right))
    Add(left, right) => Add(mapped(left), mapped(right))
    Mux(select~, when_true~, when_false~) =>
      Mux(
        select=mapped(select),
        when_true=mapped(when_true),
        when_false=mapped(when_false),
      )
    _ => fail("operation outside the accepted original arbiter cone")
  }
}

///|
test "arbiter materialization copies exactly reviewed original nodes state and named cuts" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let source = fixture.hardware()
  let before = @ir_codec.serialize(
    @ir.Design::single("QueuedConcurrentQueueConservationPilot", source),
  )
  let accepted = two_client_arbiter_probe(fixture)
  assert_eq(
    sha256_hex(two_client_arbiter_probe_report(accepted)),
    "cc867599656fda1bc3897b42d971feb75736de72e22112a6ef1d0364af32d138",
  )
  let slice = two_client_arbiter_sequential(fixture)
  let repeated = two_client_arbiter_sequential(fixture)
  assert_eq(slice.probe, accepted)
  assert_eq(slice.probe, repeated.probe)
  assert_eq(slice.hardware, repeated.hardware)
  assert_eq(slice.original_to_local, repeated.original_to_local)
  assert_eq(
    @ir_codec.serialize(
      @ir.Design::single("ArbiterMaterialization", slice.hardware),
    ),
    @ir_codec.serialize(
      @ir.Design::single("ArbiterMaterialization", repeated.hardware),
    ),
  )
  assert_eq(sha256_hex(before), accepted.production_digest)
  assert_eq(accepted.roots.length(), 11)
  assert_eq(
    accepted.roots
    .iter()
    .fold(init=0, (sum, root) => sum + root.signal_type.width().bits()),
    172,
  )
  assert_eq(accepted.candidates.length(), 15)
  assert_eq(accepted.cone.length(), 81)
  assert_eq(accepted.events.length(), 17)
  assert_eq(slice.hardware.name(), "TwoClientArbiterSequential")
  assert_eq(slice.hardware.nodes().length(), 108)
  assert_eq(
    slice.hardware.nodes().filter(node => node.kind() is Input(_)).length(),
    16,
  )
  assert_eq(
    slice.hardware.nodes().filter(node => node.kind() is Register(_)).length(),
    11,
  )
  assert_eq(slice.hardware.outputs().length(), 28)
  assert_eq(slice.hardware.memories().length(), 0)
  assert_eq(slice.hardware.cdc_primitives().length(), 0)
  assert_eq(slice.hardware.domains().length(), 1)
  assert_eq(slice.original_to_local.length(), source.nodes().length())
  let clock = arbiter_materialization_test_id(
    slice.original_to_local,
    accepted.clock,
  )
  let reset = arbiter_materialization_test_id(
    slice.original_to_local,
    accepted.reset,
  )
  assert_eq(slice.hardware.domains()[0], @ir.ClockDomain::rising(clock))
  // Compare the actual source graph, including every omitted node. A forward
  // next-state reference must already have a unique consecutive local ID.
  let mut ordinal = 0
  for original in source.nodes() {
    let roots = accepted.roots.filter(root => root.node == original.id())
    let cuts = accepted.candidates.filter(candidate => {
      candidate.original.id() == original.id()
    })
    let cone = accepted.cone.filter(node => node.id() == original.id())
    let membership = roots.length() +
      cuts.length() +
      cone.length() +
      (if original.id() == accepted.clock { 1 } else { 0 })
    assert_true(membership <= 1)
    match slice.original_to_local[original.id().ordinal()] {
      None => assert_eq(membership, 0)
      Some(local_id) => {
        assert_eq(membership, 1)
        assert_eq(local_id.ordinal(), ordinal)
        ordinal += 1
        let copied = dependency_generation_node(slice.hardware, local_id)
        assert_eq(copied.id(), local_id)
        assert_eq(copied.signal_type(), original.signal_type())
        if original.id() == accepted.clock {
          assert_eq(original.signal_type(), Clock)
          assert_eq(original.kind(), Input("clock"))
          assert_eq(copied.kind(), original.kind())
        } else if roots is [root] {
          guard original.kind() is Register(spec) &&
            copied.kind() is Register(copy) else {
            fail(
              "original arbiter register was replaced by an input or new logic",
            )
          }
          assert_eq(root.spec, spec)
          assert_eq(root.signal_type, original.signal_type())
          assert_eq(spec.domain(), @ir.ClockDomain::rising(accepted.clock))
          assert_eq(copy.domain(), @ir.ClockDomain::rising(clock))
          assert_eq(
            copy.next(),
            arbiter_materialization_test_id(
              slice.original_to_local,
              spec.next(),
            ),
          )
          assert_eq(copy.enable(), spec.enable())
          assert_eq(copy.enable(), None)
          assert_eq(copy.initial(), spec.initial())
          assert_eq(copy.initial(), None)
          guard spec.reset() is Some(actual_reset) &&
            copy.reset() is Some(copied_reset) else {
            fail("original arbiter reset was removed")
          }
          assert_eq(actual_reset.signal(), accepted.reset)
          assert_eq(copied_reset.signal(), reset)
          assert_eq(copied_reset.value(), actual_reset.value())
          assert_eq(copied_reset.value(), 0UL)
          assert_eq(copied_reset.mode(), actual_reset.mode())
          assert_eq(copied_reset.mode(), Synchronous)
          assert_eq(copied_reset.polarity(), actual_reset.polarity())
          assert_eq(copied_reset.polarity(), ActiveHigh)
        } else if cuts is [cut] {
          assert_eq(cut.original, original)
          assert_false(original.kind() is Constant(_))
          assert_eq(copied.kind(), Input("cut_n\{original.id().ordinal()}"))
          guard accepted.boundaries.filter(boundary => {
              boundary.original.id() == original.id()
            })
            is [boundary] else {
            fail("symbolic cut lacked reviewed original semantic boundary")
          }
          assert_eq(cut, boundary)
          assert_true(cut.roles.length() > 0)
        } else {
          guard cone is [node] else {
            fail("unexpected synthetic node in arbiter materialization")
          }
          assert_eq(node, original)
          assert_eq(
            copied.kind(),
            arbiter_materialization_test_kind(
              original.kind(),
              slice.original_to_local,
            ),
          )
        }
      }
    }
  }
  assert_eq(ordinal, slice.hardware.nodes().length())
  let constants = accepted.boundaries.filter(boundary => {
    boundary.original.kind() is Constant(_)
  })
  assert_eq(constants.length(), 7)
  for constant in constants {
    let original = constant.original
    let copied = dependency_generation_node(
      slice.hardware,
      arbiter_materialization_test_id(slice.original_to_local, original.id()),
    )
    assert_eq(original, dependency_generation_node(source, original.id()))
    assert_eq(copied.kind(), original.kind())
    assert_eq(copied.signal_type(), original.signal_type())
    assert_false(
      accepted.candidates.any(candidate => {
        candidate.original.id() == original.id()
      }),
    )
  }
  for root in accepted.roots {
    guard slice.hardware
      .outputs()
      .filter(output => output.name() == "current_" + root.name)
      is [output] else {
      fail("missing or repeated original-state output")
    }
    assert_eq(output.signal_type(), root.signal_type)
    assert_eq(
      output.driver(),
      arbiter_materialization_test_id(slice.original_to_local, root.node),
    )
  }
  for event in accepted.events {
    guard slice.hardware.outputs().filter(output => output.name() == event.name)
      is [output] else {
      fail("missing or repeated original derived-event output")
    }
    assert_eq(
      event.signal_type,
      dependency_generation_node(source, event.node).signal_type(),
    )
    assert_eq(output.signal_type(), event.signal_type)
    assert_eq(
      output.driver(),
      arbiter_materialization_test_id(slice.original_to_local, event.node),
    )
    assert_false(
      accepted.candidates.any(candidate => candidate.original.id() == event.node),
    )
    assert_false(
      dependency_generation_node(slice.hardware, output.driver()).kind()
      is Input(_),
    )
  }
  assert_eq(
    @ir_codec.serialize(
      @ir.Design::single("QueuedConcurrentQueueConservationPilot", source),
    ),
    before,
  )
}

///|
test "arbiter materialization preserves unknown startup state without implicit initialization" {
  let slice = two_client_arbiter_sequential(
    @flux_tile.queued_concurrent_queue_formal_fixture(),
  )
  let simulator = @sim.Simulator::prepare(slice.hardware)
  simulator.settle()
  for root in slice.probe.roots {
    assert_true(simulator.output("current_" + root.name).is_fully_unknown())
  }
}
