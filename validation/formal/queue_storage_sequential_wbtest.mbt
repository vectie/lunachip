///|
fn queue_storage_test_node(
  mapping : ArrayView[@ir.NodeId?],
  original : @ir.NodeId,
) -> @ir.NodeId raise {
  guard mapping.get(original.ordinal()) is Some(Some(mapped_node)) else {
    fail("required original queue node was not selected")
  }
  mapped_node
}

///|
// Independent constructor-by-constructor oracle, not the materializer remapper.
fn queue_storage_test_kind(
  kind : @ir.NodeKind,
  mapping : ArrayView[@ir.NodeId?],
) -> @ir.NodeKind raise {
  fn mapped_node(id : @ir.NodeId) -> @ir.NodeId raise {
    queue_storage_test_node(mapping, id)
  }
  match kind {
    Constant(value) => Constant(value)
    Add(a, b) => Add(mapped_node(a), mapped_node(b))
    Sub(a, b) => Sub(mapped_node(a), mapped_node(b))
    MulLow(a, b) => MulLow(mapped_node(a), mapped_node(b))
    MulFull(a, b) => MulFull(mapped_node(a), mapped_node(b))
    BitAnd(a, b) => BitAnd(mapped_node(a), mapped_node(b))
    BitOr(a, b) => BitOr(mapped_node(a), mapped_node(b))
    BitXor(a, b) => BitXor(mapped_node(a), mapped_node(b))
    BitNot(value) => BitNot(mapped_node(value))
    Equal(a, b) => Equal(mapped_node(a), mapped_node(b))
    LessThan(a, b) => LessThan(mapped_node(a), mapped_node(b))
    LessEqual(a, b) => LessEqual(mapped_node(a), mapped_node(b))
    ShiftLeft(value~, amount~) =>
      ShiftLeft(value=mapped_node(value), amount=mapped_node(amount))
    LogicalShiftRight(value~, amount~) =>
      LogicalShiftRight(value=mapped_node(value), amount=mapped_node(amount))
    ArithmeticShiftRight(value~, amount~) =>
      ArithmeticShiftRight(value=mapped_node(value), amount=mapped_node(amount))
    Slice(value~, msb~, lsb~) => Slice(value=mapped_node(value), msb~, lsb~)
    Concat(most_significant~, least_significant~) =>
      Concat(
        most_significant=mapped_node(most_significant),
        least_significant=mapped_node(least_significant),
      )
    ZeroExtend(value) => ZeroExtend(mapped_node(value))
    SignExtend(value) => SignExtend(mapped_node(value))
    Truncate(value) => Truncate(mapped_node(value))
    Reinterpret(value) => Reinterpret(mapped_node(value))
    Mux(select~, when_true~, when_false~) =>
      Mux(
        select=mapped_node(select),
        when_true=mapped_node(when_true),
        when_false=mapped_node(when_false),
      )
    Input(_) | Register(_) | MemoryRead(..) | AsyncFifoRead(..) =>
      fail("a storage projection cone node became a state or input leaf")
  }
}

///|
test "queue storage sequential preserves exact reviewed source selection registers cuts cone and outputs" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let source = fixture.hardware()
  let before = @ir_codec.serialize(@ir.Design::single("Source", source))
  let slice = queue_storage_sequential(fixture)
  let repeated = queue_storage_sequential(fixture)
  let probe = slice.probe
  assert_eq(probe, queue_storage_probe(fixture))
  assert_eq(slice.hardware, repeated.hardware)
  assert_eq(slice.probe, repeated.probe)
  assert_eq(slice.cuts, repeated.cuts)
  assert_eq(slice.original_to_local, repeated.original_to_local)
  assert_eq(slice.original_to_local_memory, repeated.original_to_local_memory)
  assert_eq(slice.inventory_digest, repeated.inventory_digest)
  assert_eq(
    slice.inventory_digest,
    "9a4613301556bfd0229a8696e219e9853047f645813e4f5b27032fdc5476f29d",
  )
  assert_eq(
    sha256_hex(queue_storage_probe_report(probe)),
    slice.inventory_digest,
  )
  assert_eq(
    probe.production_digest,
    "35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc",
  )
  assert_eq(@ir_codec.serialize(@ir.Design::single("Source", source)), before)
  assert_eq(
    @ir_codec.serialize(@ir.Design::single("Projection", slice.hardware)),
    @ir_codec.serialize(@ir.Design::single("Projection", repeated.hardware)),
  )
  assert_eq(slice.hardware.name(), "QueueStorageSequential")
  assert_eq(probe.roots.length(), 28)
  assert_eq(
    probe.roots
    .iter()
    .fold(init=0, (bits, root) => bits + root.signal_type.width().bits()),
    309,
  )
  assert_eq(probe.candidates.length(), 59)
  assert_eq(slice.cuts.length(), 59)
  assert_eq(probe.cone.length(), 801)
  assert_eq(probe.events.length(), 46)
  assert_eq(slice.hardware.nodes().length(), 893)
  assert_eq(
    slice.hardware.nodes().filter(node => node.kind() is Input(_)).length(),
    60,
  )
  assert_eq(
    slice.hardware.nodes().filter(node => node.kind() is Register(_)).length(),
    28,
  )
  assert_eq(
    slice.hardware
    .nodes()
    .filter(node => node.kind() is MemoryRead(..))
    .length(),
    4,
  )
  assert_eq(slice.hardware.memories().length(), 4)
  assert_eq(slice.original_to_local.length(), source.nodes().length())
  let clock = queue_storage_test_node(slice.original_to_local, probe.clock)
  let reset = queue_storage_test_node(slice.original_to_local, probe.reset)
  let domain = @ir.ClockDomain::rising(clock)
  assert_eq(slice.hardware.domains(), [domain])
  assert_eq(
    dependency_generation_node(slice.hardware, clock).kind(),
    Input("clock"),
  )
  assert_eq(
    dependency_generation_node(slice.hardware, clock).signal_type(),
    Clock,
  )
  assert_eq(
    dependency_generation_node(slice.hardware, reset).signal_type(),
    Reset,
  )
  let mut ordinal = 0
  let mut public_cuts = 0
  let mut foreign_cuts = 0
  for original in source.nodes() {
    let roots = probe.roots.filter(root => root.node == original.id())
    let cuts = slice.cuts.filter(cut => cut.node == original.id())
    let cone = probe.cone.filter(node => node.id() == original.id())
    let reads = probe.lanes.filter(lane => lane.result.id() == original.id())
    let membership = roots.length() +
      cuts.length() +
      cone.length() +
      reads.length() +
      (if original.id() == probe.clock { 1 } else { 0 })
    assert_true(membership <= 1)
    match slice.original_to_local[original.id().ordinal()] {
      None => assert_eq(membership, 0)
      Some(mapped) => {
        assert_eq(membership, 1)
        assert_eq(mapped.ordinal(), ordinal)
        ordinal += 1
        let copied = dependency_generation_node(slice.hardware, mapped)
        assert_eq(copied.signal_type(), original.signal_type())
        if roots is [root] {
          guard original.kind() is Register(actual) &&
            copied.kind() is Register(copy) else {
            fail("retained queue register was shadowed by an input")
          }
          assert_eq(actual, root.spec)
          assert_eq(actual.domain(), @ir.ClockDomain::rising(probe.clock))
          assert_eq(copy.domain(), domain)
          assert_eq(copy.initial(), actual.initial())
          assert_eq(copy.initial(), None)
          assert_eq(
            copy.next(),
            queue_storage_test_node(slice.original_to_local, actual.next()),
          )
          assert_eq(
            copy.enable(),
            actual
            .enable()
            .map(id => queue_storage_test_node(slice.original_to_local, id)),
          )
          let expected_reset = actual
            .reset()
            .map(control => {
              @ir.ResetSpec::explicit(
                queue_storage_test_node(
                  slice.original_to_local,
                  control.signal(),
                ),
                control.value(),
                control.mode(),
                control.polarity(),
              )
            })
          assert_eq(copy.reset(), expected_reset)
          assert_eq(copy.reset(), Some(@ir.ResetSpec::new(reset, 0UL)))
        } else if cuts is [cut] {
          guard probe.candidates.filter(leaf => {
              leaf.original.id() == original.id()
            })
            is [candidate] else {
            fail("cut has no unique reviewed source candidate")
          }
          assert_eq(candidate.original, original)
          assert_eq(candidate.memory, None)
          assert_eq(cut.signal_type, original.signal_type())
          assert_eq(copied.kind(), Input("cut_n\{original.id().ordinal()}"))
          let role = match original.kind() {
            Input(name) => {
              public_cuts += 1
              name
            }
            Register(_) => {
              foreign_cuts += 1
              "foreign_n\{original.id().ordinal()}"
            }
            _ => fail("unreviewed storage or derived-event input")
          }
          assert_eq(cut.roles, ReadOnlyArray::from_array([role]))
        } else if reads is [lane] {
          guard original.kind() is MemoryRead(memory~, port~) &&
            slice.original_to_local_memory[memory.ordinal()]
            is Some(local_memory) else {
            fail("retained synchronous read lost its memory mapping")
          }
          assert_eq(original, lane.result)
          assert_eq(copied.kind(), MemoryRead(memory=local_memory, port~))
        } else if original.id() == probe.clock {
          assert_eq(copied.kind(), original.kind())
        } else {
          assert_eq(cone, [original])
          assert_eq(
            copied.kind(),
            queue_storage_test_kind(original.kind(), slice.original_to_local),
          )
        }
      }
    }
  }
  assert_eq(ordinal, 893)
  assert_eq(public_cuts, 7)
  assert_eq(foreign_cuts, 52)
  let outputs : Array[@ir.OutputPort] = []
  for root in probe.roots {
    outputs.push(
      @ir.OutputPort::new(
        "current_" + root.name,
        root.signal_type,
        queue_storage_test_node(slice.original_to_local, root.node),
      ),
    )
  }
  for event in probe.events {
    assert_false(slice.cuts.any(cut => cut.node == event.node))
    assert_true(probe.cone.any(node => node.id() == event.node))
    outputs.push(
      @ir.OutputPort::new(
        event.name,
        event.signal_type,
        queue_storage_test_node(slice.original_to_local, event.node),
      ),
    )
  }
  for lane in probe.lanes {
    outputs.push(
      @ir.OutputPort::new(
        "fifo_response_data_\{lane.lane}",
        lane.result.signal_type(),
        queue_storage_test_node(slice.original_to_local, lane.result.id()),
      ),
    )
  }
  assert_eq(slice.hardware.outputs(), ReadOnlyArray::from_array(outputs))
  assert_eq(outputs.length(), 78)
  for index, output in outputs {
    assert_false(outputs[:index].any(prior => prior.name() == output.name()))
  }
}

///|
test "queue storage sequential rejects complete report drift and unchanged-report source metadata drift" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let probe = queue_storage_probe(fixture)
  queue_storage_require_inventory(probe)
  let candidates = probe.candidates.iter().to_array()
  let first = candidates[0]
  candidates[0] = {
    ..first,
    original: @ir.Node::new(
      first.original.id(),
      first.original.signal_type(),
      Input("different_reset"),
    ),
  }
  let lane = probe.lanes[0]
  let memory = lane.memory
  let changed_memory = @ir.MemorySpec::new(
    memory.id(),
    memory.name(),
    memory.element_type(),
    memory.depth(),
    memory.domain(),
    memory.read_ports(),
    memory.write_ports(),
    NoChange,
    memory.multi_write_policy(),
    memory.bounds_policy(),
  )
  let lanes = probe.lanes.iter().to_array()
  lanes[0] = { ..lane, memory: changed_memory, }
  let cone = probe.cone.iter().to_array()
  guard cone.filter(node => node.kind() is Constant(_)) is [constant, ..] else {
    fail("missing original cone constant")
  }
  guard constant.kind() is Constant(value) else {
    fail("missing cone constant")
  }
  for index, node in cone {
    if node.id() == constant.id() {
      cone[index] = @ir.Node::new(
        constant.id(),
        constant.signal_type(),
        Constant(value ^ 1UL),
      )
    }
  }
  let changed : Array[QueueStorageProbe] = [
    { ..probe, candidates: ReadOnlyArray::from_array(candidates), },
    { ..probe, lanes: ReadOnlyArray::from_array(lanes), },
    { ..probe, cone: ReadOnlyArray::from_array(cone), },
    { ..probe, production_digest: "different_source_digest", },
  ]
  for drift in changed {
    assert_eq(drift.roots.length(), 28)
    assert_eq(drift.candidates.length(), 59)
    assert_eq(drift.cone.length(), 801)
    try queue_storage_require_inventory(drift) catch {
      InvalidFormalBundleIdentity(_) => ()
      _ => fail("unexpected complete inventory rejection")
    } noraise {
      _ => fail("same-count signature drift passed the inventory pin")
    }
  }
  // Report signatures do not serialize these convenience identity fields.
  // The separate fresh-source equality guard must still reject their drift.
  for
    drift in [
      { ..probe, clock: probe.reset, },
      { ..probe, reset: probe.clock, },
    ] {
    assert_eq(
      queue_storage_probe_report(drift),
      queue_storage_probe_report(probe),
    )
    queue_storage_require_inventory(drift)
    try queue_storage_sequential_from_probe(fixture, drift) catch {
      InvalidFormalBundleIdentity(message) =>
        assert_eq(message, "queue storage sequential: original closure drift")
      _ => fail("unexpected fresh source guard rejection")
    } noraise {
      _ => fail("unchanged report bypassed the original source guard")
    }
  }
}
