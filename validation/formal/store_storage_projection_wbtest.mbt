///|
test "Store projection copies every selected operation and original control without private input cuts" {
  let fixture = @flux_tile.queued_concurrent_store_preservation_fixture()
  let source = fixture.hardware()
  assert_eq(
    source,
    @flux_tile.queued_concurrent_tile(
      rows=2,
      columns=2,
      max_reduction=2,
      host_bytes=1024UL,
      queue_depth=3,
    ),
  )
  let before = @ir_codec.serialize(@ir.Design::single("Source", source))
  let slice = store_storage_projection(fixture)
  let repeated = store_storage_projection(fixture)
  let plan = slice.plan
  assert_eq(plan, store_storage_projection_plan(fixture))
  assert_eq(slice.hardware, repeated.hardware)
  assert_eq(slice.original_to_local, repeated.original_to_local)
  assert_eq(slice.original_to_local_memory, repeated.original_to_local_memory)
  assert_eq(plan.observations, fixture.observations())
  assert_eq(plan.probe.roots.length(), 48)
  assert_eq(
    plan.probe.roots
    .iter()
    .fold(init=0, (bits, root) => {
      bits + root.original.signal_type().width().bits()
    }),
    515,
  )
  assert_eq(plan.observations.length(), 83)
  assert_eq(plan.arithmetic.length(), 4)
  assert_eq(
    plan.arithmetic
    .iter()
    .fold(init=0, (bits, node) => bits + node.signal_type().width().bits()),
    128,
  )
  let expected_arithmetic = plan.probe.candidates.filter(candidate => {
    candidate.original.signal_type() == @wire.sint(32)
  })
  assert_eq(
    plan.arithmetic,
    expected_arithmetic.map(candidate => candidate.original),
  )
  for candidate in expected_arithmetic {
    assert_eq(candidate.memory, None)
    assert_eq(candidate.provenance.length(), 2)
    for slot in 0..<2 {
      assert_true(
        candidate.provenance.any(index => {
          plan.probe.seeds[index].origin is WriteData(selected, _) &&
          selected == slot
        }),
      )
    }
  }
  assert_eq(plan.arbiter_roots.length(), 11)
  assert_eq(
    plan.arbiter_roots
    .iter()
    .fold(init=0, (bits, root) => bits + root.signal_type.width().bits()),
    172,
  )
  for
    name in [
      "state", "owner", "preference", "next_tag", "expected_tag", "local_tag", "write",
      "address", "bytes", "mask", "data",
    ] {
    guard plan.arbiter_roots.filter(root => root.name == name) is [root] else {
      fail("missing unique original arbiter role")
    }
    let original = source.nodes()[root.node.ordinal()]
    assert_eq(original.kind(), Register(root.spec))
    assert_eq(original.signal_type(), root.signal_type)
    assert_false(plan.arithmetic.any(cut => cut.id() == root.node))
    if name == "write" ||
      name == "address" ||
      name == "bytes" ||
      name == "mask" ||
      name == "data" ||
      name == "next_tag" {
      let port_name = if name == "next_tag" { "tag" } else { name }
      guard source
        .outputs()
        .filter(output => output.name() == "memory_request_" + port_name)
        is [output] else {
        fail("arbiter payload has no original public output")
      }
      assert_eq(root.node, output.driver())
    }
  }
  assert_eq(slice.original_to_local.length(), source.nodes().length())
  let mut ordinal = 0
  let mut arithmetic_inputs = 0
  for original in source.nodes() {
    let selected = plan.selected.filter(node => node.id() == original.id())
    match slice.original_to_local[original.id().ordinal()] {
      None => assert_true(selected.is_empty())
      Some(mapped) => {
        assert_eq(selected, [original])
        assert_eq(mapped.ordinal(), ordinal)
        ordinal += 1
        let copied = slice.hardware.nodes()[mapped.ordinal()]
        assert_eq(copied.id(), mapped)
        assert_eq(copied.signal_type(), original.signal_type())
        if plan.arithmetic.any(cut => cut.id() == original.id()) {
          arithmetic_inputs += 1
          assert_eq(original.signal_type(), @wire.sint(32))
          assert_true(original.kind() is Register(_))
          assert_eq(
            copied.kind(),
            Input("arithmetic_n\{original.id().ordinal()}"),
          )
        } else {
          match original.kind() {
            Input(name) => assert_eq(copied.kind(), Input(name))
            Register(spec) => {
              let reset = spec
                .reset()
                .map(control => {
                  @ir.ResetSpec::explicit(
                    store_projection_test_node(
                      slice.original_to_local,
                      control.signal(),
                    ),
                    control.value(),
                    control.mode(),
                    control.polarity(),
                  )
                })
              let enable = spec
                .enable()
                .map(id => {
                  store_projection_test_node(slice.original_to_local, id)
                })
              let initial = spec.initial()
              assert_eq(
                copied.kind(),
                Register(
                  @ir.RegisterSpec::new(
                    store_projection_test_domain(
                      spec.domain(),
                      slice.original_to_local,
                    ),
                    store_projection_test_node(
                      slice.original_to_local,
                      spec.next(),
                    ),
                    reset?,
                    enable?,
                    initial?,
                  ),
                ),
              )
              assert_eq(spec.domain(), plan.probe.domain)
              assert_eq(initial, None)
            }
            MemoryRead(memory~, port~) => {
              guard slice.original_to_local_memory[memory.ordinal()]
                is Some(mapped_memory) else {
                fail("read state lost original memory")
              }
              assert_eq(copied.kind(), MemoryRead(memory=mapped_memory, port~))
            }
            AsyncFifoRead(..) => fail("unexpected asynchronous storage")
            kind =>
              assert_eq(
                copied.kind(),
                queue_storage_test_kind(kind, slice.original_to_local),
              )
          }
        }
      }
    }
  }
  assert_eq(ordinal, slice.hardware.nodes().length())
  assert_eq(arithmetic_inputs, 4)
  for root in plan.probe.roots {
    assert_false(plan.arithmetic.any(cut => cut.id() == root.original.id()))
    assert_true(
      slice.hardware.nodes()[store_projection_test_node(
        slice.original_to_local,
        root.original.id(),
      ).ordinal()].kind()
      is Register(_),
    )
  }
  for candidate in plan.probe.candidates {
    ignore(
      store_projection_test_node(
        slice.original_to_local,
        candidate.original.id(),
      ),
    )
  }
  let outputs : Array[@ir.OutputPort] = []
  for output in source.outputs() {
    outputs.push(
      @ir.OutputPort::new(
        output.name(),
        output.signal_type(),
        store_projection_test_node(slice.original_to_local, output.driver()),
      ),
    )
  }
  for index, observation in fixture.observations() {
    outputs.push(
      @ir.OutputPort::new(
        "store_observation_\{index}",
        observation.signal_type(),
        store_projection_test_node(slice.original_to_local, observation.node()),
      ),
    )
  }
  for original in plan.selected {
    if original.kind() is Register(_) &&
      !plan.arithmetic.any(cut => cut.id() == original.id()) {
      outputs.push(
        @ir.OutputPort::new(
          "current_n\{original.id().ordinal()}",
          original.signal_type(),
          store_projection_test_node(slice.original_to_local, original.id()),
        ),
      )
    } else if original.kind() is MemoryRead(..) {
      outputs.push(
        @ir.OutputPort::new(
          "read_n\{original.id().ordinal()}",
          original.signal_type(),
          store_projection_test_node(slice.original_to_local, original.id()),
        ),
      )
    }
  }
  assert_eq(slice.hardware.outputs(), ReadOnlyArray::from_array(outputs))
  assert_eq(slice.hardware.domains(), [
    store_projection_test_domain(plan.probe.domain, slice.original_to_local),
  ])
  assert_true(slice.hardware.cdc_primitives().is_empty())
  assert_eq(@ir_codec.serialize(@ir.Design::single("Source", source)), before)
}

///|
test "Store projection report preserves complete signatures and unknown original startup storage" {
  let fixture = @flux_tile.queued_concurrent_store_preservation_fixture()
  let slice = store_storage_projection(fixture)
  let report = store_storage_projection_report(slice)
  println("STORE-PROJECTION-REPORT-BEGIN\n\{report}STORE-PROJECTION-REPORT-END")
  assert_eq(
    report,
    store_storage_projection_report(store_storage_projection(fixture)),
  )
  assert_true(
    report.has_prefix(
      "STORE-STORAGE-PROJECTION 1\nSCOPE exact-original-control-storage-four-arithmetic-production-values-only-not-MatMul-proof\n",
    ),
  )
  assert_eq(
    report.split("\nNODE original").length() - 1,
    slice.plan.selected.length(),
  )
  assert_eq(
    report.split("\nMEMORY original").length() - 1,
    slice.plan.memories.length(),
  )
  assert_eq(report.split("\nARBITER ").length() - 1, 11)
  assert_eq(report.split("\nESSENTIAL-ROOT ").length() - 1, 48)
  assert_eq(report.split("\nOBSERVATION ").length() - 1, 83)
  for original in slice.plan.selected {
    let mapped = store_projection_test_node(
      slice.original_to_local,
      original.id(),
    )
    let copied = slice.hardware.nodes()[mapped.ordinal()]
    assert_true(
      report.contains(
        "NODE original\{original.id().ordinal()} local\{mapped.ordinal()} type\{Repr(original.signal_type())} original-kind\{Repr(original.kind())} local-kind\{Repr(copied.kind())}\n",
      ),
    )
  }
  for original in slice.plan.memories {
    guard slice.original_to_local_memory[original.id().ordinal()]
      is Some(mapped) else {
      fail("report memory omitted mapping")
    }
    let copied = slice.hardware.memories()[mapped.ordinal()]
    assert_true(
      report.contains(
        "MEMORY original\{original.id().ordinal()} local\{mapped.ordinal()} original-spec\{Repr(original)} local-spec\{Repr(copied)}\n",
      ),
    )
  }
  let source_sim = @sim.Simulator::prepare(fixture.hardware())
  let projected = @sim.Simulator::prepare(slice.hardware)
  for original in slice.plan.selected {
    if (
        original.kind() is Register(_) &&
        !slice.plan.arithmetic.any(cut => cut.id() == original.id())
      ) ||
      original.kind() is MemoryRead(..) {
      let value = projected.value(
        store_projection_test_node(slice.original_to_local, original.id()),
      )
      assert_eq(value, source_sim.value(original.id()))
      assert_true(value.is_fully_unknown())
    }
  }
  for memory in slice.plan.memories {
    for index in 0..<memory.depth().elements() {
      let value = projected.memory_cell(memory.name(), index)
      assert_eq(value, source_sim.memory_cell(memory.name(), index))
      assert_true(value.is_fully_unknown())
    }
  }
}

///|
test "Store projection rejects same-count source report probe and complete plan drift" {
  let fixture = @flux_tile.queued_concurrent_store_preservation_fixture()
  let plan = store_storage_projection_plan(fixture)
  let selected = plan.selected.iter().to_array()
  guard selected.filter(node => node.kind() is Constant(_)) is [constant, ..] &&
    constant.kind() is Constant(value) else {
    fail("missing selected constant")
  }
  for index, node in selected {
    if node.id() == constant.id() {
      selected[index] = @ir.Node::new(
        node.id(),
        node.signal_type(),
        Constant(value ^ 1UL),
      )
    }
  }
  let arithmetic = plan.arithmetic.iter().to_array()
  arithmetic[0] = plan.probe.roots[0].original
  let arbiter = plan.arbiter_roots.iter().to_array()
  arbiter[0] = { ..arbiter[0], name: "changed_state_identity", }
  let seeds = plan.seeds.iter().to_array()
  seeds[0] = plan.probe.reset
  let memories = plan.memories.iter().to_array()
  let memory = memories[0]
  memories[0] = @ir.MemorySpec::new(
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
  let observations = plan.observations.iter().to_array()
  let first_observation = observations[0]
  observations[0] = observations[1]
  observations[1] = first_observation
  let source_nodes = fixture.hardware().nodes().iter().to_array()
  source_nodes[constant.id().ordinal()] = selected.filter(node => {
      node.id() == constant.id()
    })[0]
  let source = fixture.hardware()
  let changed_source = @ir.Module::checked_with_metadata(
    source.name(),
    source.domains(),
    source_nodes,
    source.memories(),
    source.outputs(),
    source.metadata(),
  )
  let source_drift = { ..plan.probe, source: changed_source, }
  // The report uses saved signatures, so fresh-source comparison is necessary.
  assert_eq(
    store_preservation_probe_report(source_drift),
    store_preservation_probe_report(plan.probe),
  )
  ignore(store_storage_projection_arithmetic(source_drift))
  let drifts : Array[StoreStorageProjectionPlan] = [
    { ..plan, selected: ReadOnlyArray::from_array(selected), },
    { ..plan, arithmetic: ReadOnlyArray::from_array(arithmetic), },
    { ..plan, arbiter_roots: ReadOnlyArray::from_array(arbiter), },
    { ..plan, seeds: ReadOnlyArray::from_array(seeds), },
    { ..plan, memories: ReadOnlyArray::from_array(memories), },
    { ..plan, observations: ReadOnlyArray::from_array(observations), },
    { ..plan, probe: source_drift, },
    { ..plan, probe: { ..plan.probe, reset: plan.probe.clock, }, },
    {
      ..plan,
      probe: { ..plan.probe, source_digest: "changed_source_digest", },
    },
  ]
  for drift in drifts {
    assert_eq(drift.selected.length(), plan.selected.length())
    assert_eq(drift.arithmetic.length(), 4)
    assert_eq(drift.memories.length(), plan.memories.length())
    try store_storage_projection_from_plan(fixture, drift) catch {
      InvalidFormalBundleIdentity(message) =>
        assert_eq(message, "Store projection: complete original closure drift")
      _ => fail("unexpected Store plan drift rejection")
    } noraise {
      _ => fail("same-count drift bypassed original rederivation")
    }
  }
  let candidates = plan.probe.candidates.iter().to_array()
  let first = candidates[0]
  candidates[0] = {
    ..first,
    original: @ir.Node::new(
      first.original.id(),
      first.original.signal_type(),
      Input("changed_reset_signature"),
    ),
  }
  let probe_drifts = [
    { ..plan.probe, candidates: ReadOnlyArray::from_array(candidates), },
    { ..plan.probe, source_digest: "changed_digest", },
  ]
  for drift in probe_drifts {
    assert_eq(drift.candidates.length(), plan.probe.candidates.length())
    assert_false(
      store_preservation_probe_report(drift) ==
      store_preservation_probe_report(plan.probe),
    )
    try store_storage_projection_arithmetic(drift) catch {
      InvalidFormalBundleIdentity(_) => ()
      _ => fail("unexpected reviewed inventory rejection")
    } noraise {
      _ =>
        fail(
          "same-count source or signature drift passed arithmetic acceptance",
        )
    }
  }
}
