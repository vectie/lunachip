///|
fn store_probe_expect_rejection(action : () -> Unit raise) -> Unit raise {
  try action() catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("Store candidate discovery raised an unrelated error")
  } noraise {
    _ =>
      fail("Store candidate discovery accepted an incomplete or invalid source")
  }
}

///|
test "Store discovery rejects incomplete roles storage and every omitted dependency seed" {
  let fixture = @flux_tile.queued_concurrent_store_preservation_fixture()
  let source = fixture.hardware()
  let probe = store_preservation_probe(fixture)
  store_probe_expect_rejection(() => {
    ignore(
      store_preservation_probe_from_parts(
        source,
        fixture.observations()[1:],
        fixture.c_memories(),
      ),
    )
  })
  store_probe_expect_rejection(() => {
    ignore(
      store_preservation_probe_from_parts(
        source,
        fixture.observations(),
        fixture.c_memories()[1:],
      ),
    )
  })
  store_probe_expect_rejection(() => {
    ignore(
      store_preservation_probe_walk(
        source,
        probe.roots[1:],
        probe.events,
        probe.memories,
        probe.seeds,
        probe.clock,
        probe.reset,
        probe.domain,
      ),
    )
  })
  assert_eq(probe.seeds.length(), 154)
  for omitted in 0..<probe.seeds.length() {
    let incomplete : Array[StorePreservationProbeSeed] = []
    for index, seed in probe.seeds {
      if index != omitted {
        incomplete.push(seed)
      }
    }
    store_probe_expect_rejection(() => {
      ignore(
        store_preservation_probe_walk(
          source,
          probe.roots,
          probe.events,
          probe.memories,
          incomplete,
          probe.clock,
          probe.reset,
          probe.domain,
        ),
      )
    })
  }
  // Same count is insufficient: the full origin and node pair must match.
  for index, seed in probe.seeds {
    if seed.origin is WriteAddress(_, _) ||
      seed.origin is WriteData(_, _) ||
      seed.origin is WriteEnable(_, _) ||
      seed.origin is ReadAddress(_, _) ||
      seed.origin is ReadEnable(_, _) ||
      seed.origin is ReadResult(_) {
      let changed = probe.seeds.iter().to_array()
      changed[index] = { ..seed, node: probe.clock, }
      store_probe_expect_rejection(() => {
        ignore(
          store_preservation_probe_walk(
            source,
            probe.roots,
            probe.events,
            probe.memories,
            changed,
            probe.clock,
            probe.reset,
            probe.domain,
          ),
        )
      })
    }
  }
  let reordered : Array[@flux_tile.StorePreservationObservation] = []
  for index in 0..<fixture.observations().length() {
    reordered.push(
      fixture.observations()[fixture.observations().length() - 1 - index],
    )
  }
  assert_eq(
    probe,
    store_preservation_probe_from_parts(source, reordered, [
      fixture.c_memories()[1],
      fixture.c_memories()[0],
    ]),
  )
}

///|
test "Store discovery rejects complete memory specification drift and a derived event leaf" {
  let fixture = @flux_tile.queued_concurrent_store_preservation_fixture()
  let probe = store_preservation_probe(fixture)
  let source = probe.source
  let binding = probe.memories[0]
  let original = binding.memory()
  let changed = @ir.MemorySpec::new(
    original.id(),
    original.name(),
    original.element_type(),
    original.depth(),
    original.domain(),
    original.read_ports(),
    original.write_ports(),
    NoChange,
    original.multi_write_policy(),
    original.bounds_policy(),
  )
  store_probe_expect_rejection(() => {
    store_preservation_probe_memory_spec(source, changed, probe.domain)
  })
  let memories = source.memories().iter().to_array()
  for index, memory in memories {
    if memory.id() == changed.id() {
      memories[index] = changed
    }
  }
  let changed_source = @ir.Module::checked_with_metadata(
    source.name(),
    source.domains(),
    source.nodes(),
    memories,
    source.outputs(),
    source.metadata(),
  )
  store_probe_expect_rejection(() => {
    store_preservation_probe_memory(changed_source, binding, probe.domain)
  })
  store_probe_expect_rejection(() => {
    ignore(
      store_preservation_probe_from_parts(
        changed_source,
        fixture.observations(),
        fixture.c_memories(),
      ),
    )
  })
  let event = probe.events.filter(item => {
      item.role() == Event(StoreRequestAccept)
    })[0]
  store_probe_expect_rejection(() => {
    ignore(
      store_preservation_probe_candidate(
        source,
        dependency_generation_node(source, event.node()),
        probe.domain,
        probe.reset,
      ),
    )
  })
  let clock = dependency_generation_node(source, probe.clock)
  store_probe_expect_rejection(() => {
    ignore(
      store_preservation_probe_candidate(
        source,
        clock,
        probe.domain,
        probe.reset,
      ),
    )
  })
}

///|
test "Store discovery rejects genuine original foreign-clock registers and asynchronous FIFO read state" {
  // Reuse an existing checked original graph; do not fabricate an AsyncFifoRead
  // that fails merely because it is absent from its alleged source module.
  let design = async_fifo_formal_design().design
  let source = design.modules()[0]
  let source_clock = dependency_generation_input(source, "source_clock", Clock)
  let reset = dependency_generation_input(source, "source_reset", Reset)
  let domain = @ir.ClockDomain::rising(source_clock)
  let asynchronous = source
    .nodes()
    .filter(node => node.kind() is AsyncFifoRead(..))
  assert_false(asynchronous.is_empty())
  for node in asynchronous {
    try store_preservation_probe_candidate(source, node, domain, reset) catch {
      InvalidFormalBundleIdentity(message) =>
        assert_eq(message, "Store probe: asynchronous storage leaf")
      _ => fail("unexpected asynchronous storage rejection")
    } noraise {
      _ => fail("actual asynchronous FIFO storage became a Store candidate")
    }
  }
  let foreign = source
    .nodes()
    .filter(node => node.kind() is Register(spec) && spec.domain() != domain)
  assert_false(foreign.is_empty())
  for node in foreign {
    try store_preservation_probe_candidate(source, node, domain, reset) catch {
      InvalidFormalBundleIdentity(message) =>
        assert_eq(message, "Store probe: foreign register dependency/domain")
      _ => fail("unexpected foreign clock rejection")
    } noraise {
      _ => fail("original foreign-clock state became a Store candidate")
    }
  }
}
