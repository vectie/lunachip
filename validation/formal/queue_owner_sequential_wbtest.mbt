///|
test "queue owner sequential copies all reviewed original state leaves cone and aliases" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let source = fixture.hardware()
  let before = @ir_codec.serialize(@ir.Design::single("Original", source))
  let slice = queue_owner_sequential(fixture)
  let repeated = queue_owner_sequential(fixture)
  let probe = slice.plan.probe
  assert_eq(slice.hardware, repeated.hardware)
  assert_eq(slice.plan.probe, repeated.plan.probe)
  assert_eq(slice.plan.cuts, repeated.plan.cuts)
  assert_eq(slice.plan.inventory_digest, repeated.plan.inventory_digest)
  assert_eq(slice.original_to_local, repeated.original_to_local)
  assert_eq(
    @ir_codec.serialize(@ir.Design::single("Projection", slice.hardware)),
    @ir_codec.serialize(@ir.Design::single("Projection", repeated.hardware)),
  )
  assert_eq(@ir_codec.serialize(@ir.Design::single("Original", source)), before)
  assert_eq(probe, queue_owner_probe(fixture))
  assert_eq(
    slice.plan.inventory_digest,
    "ad6dc56cf01fc55a28eacc6be5dc16493f882b665e1d9570e6e737f9985b289a",
  )
  assert_eq(
    sha256_hex(queue_owner_probe_report(probe)),
    slice.plan.inventory_digest,
  )
  assert_eq(probe.roots.length(), 30)
  assert_eq(
    probe.roots
    .iter()
    .fold(init=0, (bits, root) => bits + root.signal_type.width().bits()),
    304,
  )
  assert_eq(slice.plan.cuts.length(), 82)
  assert_eq(probe.cone.length(), 1155)
  assert_eq(probe.events.length(), 59)
  assert_eq(slice.hardware.nodes().length(), 1268)
  assert_eq(slice.hardware.outputs().length(), 89)
  assert_eq(
    slice.hardware.nodes().filter(node => node.kind() is Input(_)).length(),
    83,
  )
  assert_eq(
    slice.hardware.nodes().filter(node => node.kind() is Register(_)).length(),
    30,
  )
  assert_eq(slice.hardware.memories().length(), 0)
  assert_eq(slice.hardware.domains().length(), 1)
  assert_eq(slice.original_to_local.length(), source.nodes().length())
  let clock = dependency_generation_mapped(slice.original_to_local, probe.clock)
  assert_eq(
    dependency_generation_node(slice.hardware, clock).kind(),
    Input("clock"),
  )
  assert_eq(
    dependency_generation_node(slice.hardware, clock).signal_type(),
    Clock,
  )
  assert_eq(slice.hardware.domains()[0], @ir.ClockDomain::rising(clock))
  let reset = dependency_generation_mapped(slice.original_to_local, probe.reset)
  assert_eq(
    dependency_generation_node(slice.hardware, reset).signal_type(),
    Reset,
  )
  assert_eq(
    dependency_generation_node(slice.hardware, reset).kind(),
    Input("cut_n\{probe.reset.ordinal()}"),
  )
  let mut expected_ordinal = 0
  for original in source.nodes() {
    let roots = probe.roots.filter(root => root.node == original.id())
    let cuts = slice.plan.cuts.filter(cut => cut.node == original.id())
    let cone = probe.cone.filter(node => node.id() == original.id())
    let count = roots.length() +
      cuts.length() +
      cone.length() +
      (if original.id() == probe.clock { 1 } else { 0 })
    assert_true(count <= 1)
    match slice.original_to_local[original.id().ordinal()] {
      None => assert_eq(count, 0)
      Some(mapped) => {
        assert_eq(count, 1)
        assert_eq(mapped.ordinal(), expected_ordinal)
        expected_ordinal += 1
        let copied = dependency_generation_node(slice.hardware, mapped)
        assert_eq(copied.signal_type(), original.signal_type())
        match roots {
          [root] => {
            guard original.kind() is Register(actual) &&
              copied.kind() is Register(copy) else {
              fail("essential state was shadowed by an input")
            }
            assert_eq(root.spec, actual)
            assert_eq(copy.domain().clock(), clock)
            assert_eq(actual.domain().clock(), probe.clock)
            assert_eq(copy.domain().edge(), actual.domain().edge())
            assert_eq(copy.initial(), actual.initial())
            assert_eq(copy.initial(), None)
            assert_eq(
              copy.next(),
              dependency_generation_mapped(
                slice.original_to_local,
                actual.next(),
              ),
            )
            match (copy.enable(), actual.enable()) {
              (None, None) => ()
              (Some(value), Some(expected)) =>
                assert_eq(
                  value,
                  dependency_generation_mapped(
                    slice.original_to_local,
                    expected,
                  ),
                )
              _ => fail("retained register enable drift")
            }
            guard copy.reset() is Some(copied_reset) &&
              actual.reset() is Some(actual_reset) else {
              fail("retained register reset missing")
            }
            assert_eq(copied_reset.signal(), reset)
            assert_eq(actual_reset.signal(), probe.reset)
            assert_eq(copied_reset.value(), actual_reset.value())
            assert_eq(copied_reset.mode(), actual_reset.mode())
            assert_eq(copied_reset.polarity(), actual_reset.polarity())
          }
          [] =>
            if original.id() == probe.clock {
              assert_eq(copied.kind(), original.kind())
            } else if cuts is [cut] {
              assert_eq(cut.signal_type, original.signal_type())
              assert_eq(copied.kind(), Input("cut_n\{original.id().ordinal()}"))
              guard probe.candidates.filter(leaf => {
                  leaf.original.id() == original.id()
                })
                is [candidate] else {
                fail("accepted boundary lacks its original candidate")
              }
              assert_eq(candidate.original, original)
              assert_eq(candidate.memory, None)
              let role = match original.kind() {
                Input(name) => name
                Register(_) => "foreign_n\{original.id().ordinal()}"
                _ => fail("unreviewed accepted leaf kind")
              }
              assert_eq(cut.roles, ReadOnlyArray::from_array([role]))
            } else {
              assert_eq(cone.length(), 1)
              assert_eq(cone[0], original)
              assert_eq(
                copied.kind(),
                dependency_generation_remap(
                  original.kind(),
                  slice.original_to_local,
                ),
              )
              let expected_operands = dependency_generation_operands(
                original.kind(),
              )
              let copied_operands = dependency_generation_operands(
                copied.kind(),
              )
              assert_eq(copied_operands.length(), expected_operands.length())
              for index, operand in expected_operands {
                assert_eq(
                  copied_operands[index],
                  dependency_generation_mapped(slice.original_to_local, operand),
                )
              }
              match (original.kind(), copied.kind()) {
                (Constant(expected), Constant(actual)) =>
                  assert_eq(actual, expected)
                (
                  Slice(msb=expected_msb, lsb=expected_lsb, ..),
                  Slice(msb=actual_msb, lsb=actual_lsb, ..),
                ) => {
                  assert_eq(actual_msb, expected_msb)
                  assert_eq(actual_lsb, expected_lsb)
                }
                _ => ()
              }
            }
          _ => fail("repeated essential root")
        }
      }
    }
  }
  assert_eq(expected_ordinal, 1268)
  for root in probe.roots {
    guard slice.hardware
      .outputs()
      .filter(output => output.name() == "current_" + root.name)
      is [output] else {
      fail("missing or repeated current-state alias")
    }
    assert_eq(output.signal_type(), root.signal_type)
    assert_eq(
      output.driver(),
      dependency_generation_mapped(slice.original_to_local, root.node),
    )
  }
  for event in probe.events {
    guard slice.hardware.outputs().filter(output => output.name() == event.name)
      is [output] else {
      fail("missing or repeated derived-event alias")
    }
    assert_eq(output.signal_type(), event.signal_type)
    assert_eq(
      output.driver(),
      dependency_generation_mapped(slice.original_to_local, event.node),
    )
    assert_false(slice.plan.cuts.any(cut => cut.node == event.node))
    assert_true(probe.cone.any(node => node.id() == event.node))
  }
}

///|
test "queue owner inventory rejects same-count changed complete signatures" {
  let probe = queue_owner_probe(
    @flux_tile.queued_concurrent_queue_formal_fixture(),
  )
  queue_owner_require_inventory(probe)
  let candidates = probe.candidates.iter().to_array()
  let original = candidates[0].original
  candidates[0] = {
    original: @ir.Node::new(
      original.id(),
      original.signal_type(),
      Input("changed_reset"),
    ),
    memory: None,
  }
  let roots = probe.roots.iter().to_array()
  roots[0] = { ..roots[0], name: "changed_fifo_occupancy_0", }
  let events = probe.events.iter().to_array()
  events[0] = { ..events[0], node: probe.clock, }
  guard probe.candidates.filter(leaf => leaf.original.kind() is Register(_))
    is [foreign, ..] &&
    foreign.original.kind() is Register(spec) else {
    fail("missing original foreign register signature")
  }
  let reset = spec.reset()
  let enable = spec.enable()
  let changed_spec = @ir.RegisterSpec::new(
    spec.domain(),
    spec.next(),
    reset?,
    enable?,
    initial=0UL,
  )
  let changed_registers = probe.candidates
    .iter()
    .map(leaf => {
      if leaf.original.id() == foreign.original.id() {
        {
          original: @ir.Node::new(
            leaf.original.id(),
            leaf.original.signal_type(),
            Register(changed_spec),
          ),
          memory: leaf.memory,
        }
      } else {
        leaf
      }
    })
    .to_array()
  let changes : Array[QueueOwnerProbe] = [
    { ..probe, candidates: ReadOnlyArray::from_array(candidates), },
    { ..probe, candidates: ReadOnlyArray::from_array(changed_registers), },
    { ..probe, roots: ReadOnlyArray::from_array(roots), },
    { ..probe, events: ReadOnlyArray::from_array(events), },
    { ..probe, production_digest: "changed-source", },
  ]
  for changed in changes {
    assert_eq(changed.roots.length(), probe.roots.length())
    assert_eq(changed.candidates.length(), probe.candidates.length())
    assert_eq(changed.events.length(), probe.events.length())
    assert_eq(changed.cone.length(), probe.cone.length())
    try queue_owner_require_inventory(changed) catch {
      InvalidFormalBundleIdentity(_) => ()
      _ => fail("wrong reviewed inventory rejection")
    } noraise {
      _ => fail("same-count changed signature was accepted")
    }
  }
}

///|
test "queue owner retained mapping rejects an omitted original leaf" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let slice = queue_owner_sequential(fixture)
  guard fixture
    .hardware()
    .nodes()
    .filter(node => {
      node.kind() is Input(_) &&
      slice.original_to_local[node.id().ordinal()] is None
    })
    is [omitted, ..] else {
    fail("expected an omitted payload input")
  }
  try
    dependency_generation_mapped(slice.original_to_local, omitted.id())
  catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("wrong missing operand rejection")
  } noraise {
    _ => fail("unlisted leaf acquired a mapped fallback")
  }
}
