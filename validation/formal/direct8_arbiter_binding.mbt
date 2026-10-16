///|
let direct8_arbiter_id : String = "phase6-flux-tile-direct8-q3-arbiter-queue-progress-r2-h2"

///|
fn direct8_arbiter_fixture() -> @flux_tile.QueueConservationFixture raise {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture(
    rows=8,
    columns=8,
    max_reduction=16,
    host_bytes=4096UL,
  )
  assert_eq(fixture.observations().length(), 115)
  let digest = sha256_hex(
    @ir_codec.serialize(
      @ir.Design::single(
        "QueuedConcurrentDirect8CompletionPilot",
        fixture.hardware(),
      ),
    ),
  )
  assert_eq(
    digest, "12e94f78c7136ada755eed2f35c92af52d77aa75fa2f1398bab19872057ff3ae",
  )
  fixture
}

///|
fn direct8_arbiter_probe(
  fixture : @flux_tile.QueueConservationFixture,
) -> TwoClientArbiterProbe raise {
  let digest = sha256_hex(
    @ir_codec.serialize(
      @ir.Design::single(
        "QueuedConcurrentDirect8CompletionPilot",
        fixture.hardware(),
      ),
    ),
  )
  assert_eq(
    digest, "12e94f78c7136ada755eed2f35c92af52d77aa75fa2f1398bab19872057ff3ae",
  )
  let probe = two_client_arbiter_probe_original(fixture.hardware(), digest)
  assert_eq(
    (probe.roots.length(), probe.boundaries.length(), probe.events.length()),
    (11, 22, 17),
  )
  probe
}

///|
fn direct8_arbiter_aliases(
  fixture : @flux_tile.QueueConservationFixture,
  probe : TwoClientArbiterProbe,
) -> ReadOnlyArray[QueueControlAlias] raise {
  let aliases : Array[QueueControlAlias] = []
  for root in probe.roots {
    aliases.push({
      name: "r_" + root.name,
      node: root.node,
      signal_type: root.signal_type,
    })
  }
  for event in probe.events {
    aliases.push({
      name: "e_" + event.name,
      node: event.node,
      signal_type: event.signal_type,
    })
  }
  for boundary in probe.boundaries {
    for role in boundary.roles {
      aliases.push({
        name: "i_" + role,
        node: boundary.original.id(),
        signal_type: boundary.original.signal_type(),
      })
    }
  }
  for observation in fixture.observations() {
    aliases.push({
      name: "q_" + queue_role_name(observation.role()),
      node: observation.node(),
      signal_type: observation.signal_type(),
    })
  }
  for index, binding in aliases {
    assert_false(aliases[:index].any(previous => previous.name == binding.name))
    assert_eq(
      fixture.hardware().node(binding.node).unwrap().signal_type(),
      binding.signal_type,
    )
  }
  ReadOnlyArray::from_array(aliases)
}

///|
fn direct8_arbiter_bindings(
  aliases : ReadOnlyArray[QueueControlAlias],
  emitted : @rtl.EmittedDesign,
) -> (String, String) raise {
  let source = StringBuilder()
  let report = StringBuilder()
  let manifest = emitted.manifest()
  report.write_string(
    "LUNACHIP-DIRECT8-ARBITER-BINDINGS 1\nMODE original-node-aliases-no-cuts-no-ports\n",
  )
  for
    (role, identifier) in [
      ("clock", port_identifier(emitted, InputPort, "clock")),
      ("reset", port_identifier(emitted, InputPort, "reset")),
    ] {
    source.write_string("  wire lc_g_\{role} = \{identifier};\n")
  }
  for binding in aliases {
    guard manifest
      .mappings()
      .filter(mapping => {
        mapping.kind() is Node &&
        mapping.module_ordinal() == manifest.top_module_ordinal() &&
        mapping.local_ordinal() == binding.node.ordinal()
      })
      is [mapping] else {
      fail("unique original-node emitter binding required")
    }
    let bits = binding.signal_type.width().bits()
    source.write_string(
      "  wire \{toggle_formal_width_range(bits)}lc_g_\{binding.name} = \{mapping.identifier()};\n",
    )
    report.write_string(
      "NODE \{binding.name} \{binding.node.ordinal()} bits\{bits} \{mapping.identifier()}\n",
    )
  }
  report.write_string("END\n")
  (source.to_string(), report.to_string())
}
