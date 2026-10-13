///|
// The original owner roots/events are already retained by the packet closure.
// Bind nonfeeding aliases only; never introduce a second controller or cut.
fn queue_packet_owner_checked_source(
  inputs : QueuePacketCompositionExport,
  owner : QueueOwnerProbe,
) -> String raise {
  queue_owner_require_inventory(owner)
  let sequential = inputs.sequential
  let probe = sequential.probe
  guard owner.production_digest == probe.production_digest &&
    owner.clock == probe.clock &&
    owner.reset == probe.reset &&
    owner.roots.length() == 30 &&
    owner.events.length() == 59 else {
    raise InvalidFormalBundleIdentity("packet owner: original source/domain")
  }
  for root in owner.roots {
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      root.node,
    )
    guard probe.roots.contains(root) &&
      !sequential.cuts.any(cut => cut.node == root.node) &&
      sequential.hardware.node(mapped) is Some(node) &&
      node.signal_type() == root.signal_type &&
      node.kind() ==
      dependency_sequential_register_kind(
        root.spec,
        sequential.original_to_local,
      ) else {
      raise InvalidFormalBundleIdentity("packet owner: retained original root")
    }
  }
  let out = StringBuilder()
  for event in owner.events {
    let target = if event.name == "descriptor_ready" ||
      event.name == "public_halted" {
      let public_name = if event.name == "public_halted" {
        "halted"
      } else {
        event.name
      }
      guard probe.source
        .outputs()
        .filter(output => {
          output.name() == public_name &&
          output.driver() == event.node &&
          output.signal_type() == event.signal_type
        })
        is [_] else {
        raise InvalidFormalBundleIdentity(
          "packet owner: public driver " + event.name,
        )
      }
      "lc_" + public_name
    } else {
      guard probe.observations.filter(binding => binding == event) is [_] else {
        raise InvalidFormalBundleIdentity(
          "packet owner: original event alias " + event.name,
        )
      }
      "lc_o_" + event.name
    }
    out.write_string(
      "  wire \{toggle_formal_width_range(event.signal_type.width().bits())}lc_dut_\{event.name} = \{target};\n",
    )
  }
  // Ring structure is already present in the original queue monitor. Reuse
  // it rather than duplicating its declarations under the same identifiers.
  for engine in 0..<3 {
    out.write_string(
      "  wire lc_busy_\{engine} = lc_o_engine_state_\{engine} != \{if engine == 1 { 2 } else { 3 }}'d0;\n",
    )
  }
  out.write_string(
    "  wire lc_owner_structure_ok = lc_raw_structure_ok\n" +
    "    && lc_o_engine_state_0 <= 3'd4 && lc_o_engine_state_1 <= 2'd3\n" +
    "    && lc_o_engine_state_2 <= 3'd4;\n",
  )
  out.write_string(queue_owner_ticket_source())
  out.write_string(queue_owner_bijection_source())
  out.write_string(queue_owner_event_source())
  out.write_string(
    (
      #|  always @(posedge lc_clock) begin
      #|    lc_packet_owner_established: assert ((!lc_seen_edge || lc_raw_owner_invariant) === 1'b1);
      #|    lc_packet_owner_events: assert ((lc_owner_events_ok) === 1'b1);
      #|  end
      #|
    ),
  )
  out.to_string()
}

///|
// Actual UInt2 pointers, ReadOld/HoldLast result-valid and actual port fires.
// The existing six-bit wrap helper widens before addition and never truncates
// invalid induction pointers into a valid three-slot address.
fn queue_packet_fifo_checked_source(
  inputs : QueuePacketCompositionExport,
) -> String raise {
  let sequential = inputs.sequential
  let out = StringBuilder()
  let shape : Array[String] = [
    "(lc_o_fifo_response_valid_0 == (lc_o_head_state == 2'd1))",
  ]
  guard sequential.probe.lanes.length() == 4 else {
    raise InvalidFormalBundleIdentity("packet FIFO: complete original lanes")
  }
  for lane in sequential.probe.lanes {
    let index = lane.lane
    for
      (role, enable) in [
        ("pop", lane.read.enable()),
        ("push", lane.write.enable()),
      ] {
      guard enable is Some(original) &&
        sequential.hardware
        .outputs()
        .filter(output => {
          output.name() == "fifo_\{role}_fire_\{index}" &&
          output.driver() ==
          dependency_generation_mapped(sequential.original_to_local, original) &&
          output.signal_type() == queue_role_type(HeadPop)
        })
        is [_] else {
        raise InvalidFormalBundleIdentity("packet FIFO: actual enabled port")
      }
      let identifier = port_identifier(
        inputs.emitted,
        OutputPort,
        "fifo_\{role}_fire_\{index}",
      )
      out.write_string(
        "  wire lc_packet_fifo_\{role}_\{index} = \{identifier};\n",
      )
      shape.push(
        "(lc_packet_fifo_\{role}_\{index} == \{if role == "push" { "lc_queue_admit" } else { "lc_o_head_pop" }})",
      )
    }
    shape.push(
      "(lc_s_fifo_read_pointer_\{index} < 2'd3 && lc_s_fifo_write_pointer_\{index} < 2'd3)",
    )
    for role in ["read", "write"] {
      shape.push(
        "(lc_s_fifo_\{role}_pointer_\{index} == lc_s_fifo_\{role}_pointer_0)",
      )
    }
    for role in ["occupancy", "response_valid"] {
      shape.push("(lc_o_fifo_\{role}_\{index} == lc_o_fifo_\{role}_0)")
    }
    shape.push("(lc_o_fifo_occupancy_\{index} <= 2'd3)")
    shape.push(
      "({4'd0, lc_s_fifo_write_pointer_\{index}} == lc_pp_wrap3({4'd0, lc_s_fifo_read_pointer_\{index}} + {4'd0, lc_o_fifo_occupancy_\{index}}))",
    )
  }
  out.write_string(
    "  wire lc_packet_fifo_shape = \{shape.join(" && ")};\n" +
    "  always @(posedge lc_clock) begin\n" +
    "    lc_packet_fifo_established: assert ((!lc_seen_edge || lc_packet_fifo_shape) === 1'b1);\n" +
    "  end\n",
  )
  out.to_string()
}
