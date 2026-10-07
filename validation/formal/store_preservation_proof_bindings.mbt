///|
// Resolve row-major producer coordinates through BOTH original C-write muxes,
// not node ordinals, array order, observed readback or a synthetic write source.
fn store_preservation_producers(
  projection : StoreStorageProjection,
) -> Array[@ir.NodeId] raise {
  let source = projection.plan.probe.source
  let row = store_preservation_role_node(
    projection,
    SlottedRegister(CaptureRow),
  )
  let column = store_preservation_role_node(
    projection,
    SlottedRegister(CaptureColumn),
  )
  let producers : Array[@ir.NodeId?] = Array::make(4, None)
  for binding in projection.plan.probe.memories {
    guard binding.memory().write_ports() is [write] else {
      raise InvalidFormalBundleIdentity(
        "Store proof: single original capture writer",
      )
    }
    let mut cursor = write.data()
    for offset in 0..<4 {
      let cell = 3 - offset
      let (select, produced, prior) = dependency_generation_decoder_mux(
        source, cursor,
      )
      let (row_equal, column_equal) = dependency_generation_decoder_and(
        source, select,
      )
      if dependency_generation_decoder_equal_constant(
          source,
          row_equal,
          4,
          (cell / 2).to_uint64(),
        ) !=
        row ||
        dependency_generation_decoder_equal_constant(
          source,
          column_equal,
          4,
          (cell % 2).to_uint64(),
        ) !=
        column ||
        !projection.plan.arithmetic.any(cut => cut.id() == produced) {
        raise InvalidFormalBundleIdentity(
          "Store proof: original capture arithmetic mux cell",
        )
      }
      match producers[cell] {
        None => producers[cell] = Some(produced)
        Some(original) =>
          if original != produced {
            raise InvalidFormalBundleIdentity(
              "Store proof: shared original arithmetic production",
            )
          }
      }
      cursor = prior
    }
    dependency_generation_decoder_constant(source, cursor, @wire.sint(32), 0UL)
  }
  producers.map(value => {
    guard value is Some(node) else {
      raise InvalidFormalBundleIdentity(
        "Store proof: missing producer coordinate",
      )
    }
    node
  })
}

///|
fn store_preservation_proof_bindings(
  projection : StoreStorageProjection,
  emitted : @rtl.EmittedDesign,
) -> String raise {
  let out = StringBuilder()
  for index, observation in projection.plan.observations {
    let alias_name = store_preservation_role_alias(observation.role())
    let port = port_identifier(
      emitted,
      OutputPort,
      "store_observation_\{index}",
    )
    out.write_string(
      "  wire \{toggle_formal_width_range(observation.signal_type().width().bits())}\{alias_name};\n  assign \{alias_name} = \{port};\n",
    )
    out.write_string(
      "  logic \{toggle_formal_width_range(observation.signal_type().width().bits())}lc_pre_\{alias_name};\n  always @(posedge lc_clock) lc_pre_\{alias_name} <= \{alias_name};\n",
    )
  }
  for root in projection.plan.arbiter_roots {
    let port = store_preservation_node_identifier(
      projection,
      emitted,
      root.node,
    )
    out.write_string(
      "  wire \{toggle_formal_width_range(root.signal_type.width().bits())}lc_arb_\{root.name};\n  assign lc_arb_\{root.name} = \{port};\n",
    )
  }
  let producers = store_preservation_producers(projection)
  for cell, node in producers {
    let identifier = store_preservation_node_identifier(
      projection, emitted, node,
    )
    out.write_string(
      "  wire [31:0] lc_production_\{cell};\n  assign lc_production_\{cell} = \{identifier};\n",
    )
  }
  for
    name in [
      "reset", "memory_request_ready", "memory_response_valid", "memory_response_tag",
      "memory_response_fault",
    ] {
    let identifier = port_identifier(emitted, InputPort, name)
    let signal_type = if name == "memory_response_tag" {
      32
    } else if name == "memory_response_fault" {
      2
    } else {
      1
    }
    out.write_string(
      "  wire \{toggle_formal_width_range(signal_type)}lc_\{name};\n  assign lc_\{name} = \{identifier};\n",
    )
  }
  for
    name in [
      "memory_request_valid", "memory_response_ready", "memory_request_write", "memory_request_data",
      "memory_request_address", "memory_request_bytes", "memory_request_mask",
    ] {
    guard projection.hardware.outputs().filter(output => output.name() == name)
      is [output] else {
      raise InvalidFormalBundleIdentity(
        "Store proof: original public bus binding",
      )
    }
    let identifier = port_identifier(emitted, OutputPort, name)
    out.write_string(
      "  wire \{toggle_formal_width_range(output.signal_type().width().bits())}lc_\{name};\n  assign lc_\{name} = \{identifier};\n",
    )
  }
  for
    (role, alias_name) in [
      (
        @flux_tile.StorePreservationRole::ComputeRegister(C),
        "lc_incoming_compute_c",
      ),
      (StoreRegister(Slot), "lc_incoming_store_slot"),
    ] {
    let node = dependency_generation_node(
      projection.plan.probe.source,
      store_preservation_role_node(projection, role),
    )
    guard node.kind() is Register(spec) else {
      raise InvalidFormalBundleIdentity("Store proof: accepted selector state")
    }
    let (_, value, _) = dependency_generation_decoder_mux(
      projection.plan.probe.source,
      spec.next(),
    )
    let identifier = store_preservation_node_identifier(
      projection, emitted, value,
    )
    out.write_string(
      "  wire \{alias_name};\n  assign \{alias_name} = \{identifier};\n",
    )
  }
  guard projection.plan.arbiter_roots.filter(root => root.name == "owner")
    is [owner] else {
    raise InvalidFormalBundleIdentity("Store proof: original arbiter owner")
  }
  let (grant, select, _) = dependency_generation_decoder_mux(
    projection.plan.probe.source,
    owner.spec.next(),
  )
  for (name, node) in [("lc_arb_grant", grant), ("lc_arb_choose_store", select)] {
    out.write_string(
      "  wire \{name};\n  assign \{name} = \{store_preservation_node_identifier(projection, emitted, node)};\n",
    )
  }
  let memories = store_preservation_memory_identifiers(projection, emitted)
  for binding in projection.plan.probe.memories {
    let slot = binding.slot()
    let memory = binding.memory()
    let mapped = queue_storage_sequential_mapped_memory(
      projection.original_to_local_memory,
      memory.id(),
    )
    guard memory.read_ports() is [read] &&
      memory.write_ports() is [write] &&
      read.enable() is Some(read_enable) &&
      write.enable() is Some(write_enable) else {
      raise InvalidFormalBundleIdentity("Store proof: actual original C ports")
    }
    for
      (name, node) in [
        ("read_address", read.address()),
        ("read_enable", read_enable),
        ("write_address", write.address()),
        ("write_enable", write_enable),
        ("write_data", write.data()),
      ] {
      let original = dependency_generation_node(
        projection.plan.probe.source,
        node,
      )
      out.write_string(
        "  wire \{toggle_formal_width_range(original.signal_type().width().bits())}lc_c_\{name}_\{slot};\n  assign lc_c_\{name}_\{slot} = \{store_preservation_node_identifier(projection, emitted, node)};\n",
      )
    }
    for cell in 0..<4 {
      out.write_string(
        "  wire [31:0] lc_actual_c_\{slot}_\{cell};\n  assign lc_actual_c_\{slot}_\{cell} = \{memories[mapped.ordinal()]}[\{cell}];\n",
      )
    }
  }
  out.to_string()
}
