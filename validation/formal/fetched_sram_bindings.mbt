///|
fn fetched_sram_fixture(
  source : @ir.Module,
) -> @flux_tile.StorePreservationFixture raise {
  let fixture = @flux_tile.ring_concurrent_store_preservation_fixture()
  guard fixture.hardware() == source && fixture.observations().length() == 83 else {
    raise InvalidFormalBundleIdentity(
      "fetched SRAM: exact original graph and inventory",
    )
  }
  for index, binding in fixture.observations() {
    guard binding.signal_type() ==
      store_preservation_probe_role_type(binding.role()) &&
      dependency_generation_node(source, binding.node()).signal_type() ==
      binding.signal_type() &&
      !fixture.observations()[:index].any(prior => {
        prior.role() == binding.role()
      }) else {
      raise InvalidFormalBundleIdentity(
        "fetched SRAM: unique typed original role",
      )
    }
  }
  fixture
}

///|
// Independent producer is the original accumulator register, not write data,
// readback, or an arbitrary arithmetic cut. Both actual write muxes must agree.
fn fetched_sram_producer(
  fixture : @flux_tile.StorePreservationFixture,
) -> @ir.NodeId raise {
  let source = fixture.hardware()
  let find = role => {
    guard fixture.observations().filter(binding => binding.role() == role)
      is [binding] else {
      raise InvalidFormalBundleIdentity(
        "fetched SRAM: original coordinate role",
      )
    }
    binding.node()
  }
  let row = find(SlottedRegister(CaptureRow))
  let column = find(SlottedRegister(CaptureColumn))
  let producers : Array[@ir.NodeId] = []
  for binding in fixture.c_memories() {
    let memory = binding.memory()
    guard memory.depth().elements() == 1 &&
      memory.element_type() == @wire.sint(32) &&
      memory.read_write_policy() is ReadOld &&
      memory.multi_write_policy() is Reject &&
      memory.bounds_policy() is Fault &&
      memory.write_ports() is [write] &&
      write.mask() is All &&
      memory.read_ports() is [read] &&
      read.latency() is OneCycle &&
      read.enable_behavior() is HoldLast else {
      raise InvalidFormalBundleIdentity(
        "fetched SRAM: original storage policies",
      )
    }
    let (select, producer, zero) = dependency_generation_decoder_mux(
      source,
      write.data(),
    )
    let (row_eq, col_eq) = dependency_generation_decoder_and(source, select)
    guard dependency_generation_decoder_equal_constant(source, row_eq, 4, 0UL) ==
      row &&
      dependency_generation_decoder_equal_constant(source, col_eq, 4, 0UL) ==
      column &&
      fetched_transport_constant(source, zero, 32, 0UL) &&
      dependency_generation_node(source, producer).signal_type() ==
      @wire.sint(32) &&
      dependency_generation_node(source, producer).kind() is Register(_) else {
      raise InvalidFormalBundleIdentity(
        "fetched SRAM: independent actual accumulator",
      )
    }
    producers.push(producer)
  }
  guard producers is [a, b] && a == b else {
    raise InvalidFormalBundleIdentity("fetched SRAM: shared raw producer")
  }
  a
}

///|
fn fetched_sram_observer(
  source : @ir.Module,
  emitted : @rtl.EmittedDesign,
) -> String raise {
  let fixture = fetched_sram_fixture(source)
  let out = StringBuilder()
  for binding in fixture.observations() {
    out.write_string(
      "  wire \{toggle_formal_width_range(binding.signal_type().width().bits())}\{store_preservation_role_alias(binding.role()).replace_all(old="lc_", new="lc_fs_")} = \{fetched_packet_node_name(emitted, binding.node())};\n",
    )
  }
  for (name, port, width) in [("clock", "clock", 1), ("reset", "reset", 1)] {
    out.write_string(
      "  wire \{toggle_formal_width_range(width)}lc_fs_\{name} = \{port_identifier(emitted, InputPort, port)};\n",
    )
  }
  for
    (name, port, width) in [
      ("arb_grant", "arbiter_grant", 1),
      ("arb_choice", "arbiter_choice", 2),
      ("arb_state", "current_arbiter_state", 2),
      ("arb_owner", "current_arbiter_owner", 2),
      ("arb_data", "current_arbiter_data", 32),
      ("arb_address", "current_arbiter_address", 32),
      ("public_valid", "memory_request_valid", 1),
      ("public_write", "memory_request_write", 1),
      ("public_data", "memory_request_data", 32),
      ("public_address", "memory_request_address", 32),
      ("address_full", "composition_dma_storer_address_full", 64),
      ("dependency_ticket", "composition_dependency_dependency_ticket_0", 32),
      ("dependency_status", "composition_dependency_dependency_status_0", 2),
      ("head_state", "composition_dependency_head_state", 2),
      ("head_ticket", "composition_dependency_head_ticket", 32),
      ("head_lane_0", "composition_dependency_head_lane_0", 64),
      ("head_lane_1", "composition_dependency_head_lane_1", 64),
      ("head_lane_3", "composition_dependency_head_lane_3", 64),
    ] {
    out.write_string(
      "  wire \{toggle_formal_width_range(width)}lc_fs_\{name} = \{port_identifier(emitted, OutputPort, port)};\n",
    )
  }
  out.write_string(
    "  wire [31:0] lc_fs_producer = \{fetched_packet_node_name(emitted, fetched_sram_producer(fixture))};\n",
  )
  for binding in fixture.c_memories() {
    let slot = binding.slot()
    let memory = binding.memory()
    guard memory.read_ports() is [read] &&
      read.enable() is Some(read_enable) &&
      memory.write_ports() is [write] &&
      write.enable() is Some(write_enable) &&
      emitted
      .manifest()
      .mappings()
      .filter(mapping => {
        mapping.kind() is Memory &&
        mapping.module_ordinal() == emitted.manifest().top_module_ordinal() &&
        mapping.local_ordinal() == memory.id().ordinal() &&
        mapping.source_name() == memory.name()
      })
      is [mapping] else {
      raise InvalidFormalBundleIdentity(
        "fetched SRAM: exact enabled original ports",
      )
    }
    out.write_string(
      "  wire [31:0] lc_fs_cell_\{slot} = \{mapping.identifier()}[0];\n",
    )
    for
      (name, id) in [
        ("write_enable", write_enable),
        ("write_address", write.address()),
        ("write_data", write.data()),
        ("read_enable", read_enable),
        ("read_address", read.address()),
      ] {
      let width = dependency_generation_node(source, id)
        .signal_type()
        .width()
        .bits()
      out.write_string(
        "  wire \{toggle_formal_width_range(width)}lc_fs_c_\{name}_\{slot} = \{fetched_packet_node_name(emitted, id)};\n",
      )
    }
    for (name, width) in [("status", 2), ("ticket", 32)] {
      out.write_string(
        "  wire \{toggle_formal_width_range(width)}lc_fs_latest_\{name}_\{slot} = \{port_identifier(emitted, OutputPort, "composition_dependency_writer_" + name + "_" + (slot+4).to_string())};\n",
      )
    }
  }
  out.write_string(
    (fetched_sram_generation_support() + fetched_sram_read_support()).replace_all(
      old="lc_",
      new="lc_fs_",
    ),
  )
  out.to_string()
}
