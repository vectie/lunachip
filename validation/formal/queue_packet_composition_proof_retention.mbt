///|
// Complete original storage, not monitor mirrors: 876 register bits, four
// 64-bit synchronous read results and twelve 64-bit cells (1900 bits total).
fn queue_packet_composition_retention_source(
  sequential : QueuePacketCompositionSequential,
  emitted : @rtl.EmittedDesign,
) -> String raise FormalGateError {
  let pair : Array[String] = []
  let mut bits = 0
  for root in sequential.probe.roots {
    pair.push(port_identifier(emitted, OutputPort, "current_" + root.name))
    bits += root.signal_type.width().bits()
  }
  let names = queue_packet_composition_memory_identifiers(sequential, emitted)
  for lane in sequential.probe.lanes {
    pair.push(
      port_identifier(emitted, OutputPort, "fifo_response_data_\{lane.lane}"),
    )
    bits += lane.result.signal_type().width().bits()
    for cell in 0..<lane.memory.depth().elements() {
      pair.push("\{names[lane.lane]}[\{cell}]")
      bits += lane.memory.element_type().width().bits()
    }
  }
  if sequential.probe.roots.length() != 54 ||
    sequential.probe.lanes.length() != 4 ||
    bits != 1900 {
    raise InvalidFormalBundleIdentity(
      "packet composition proof inputs: complete original 1900-bit storage",
    )
  }
  let out = StringBuilder()
  out.write_string(
    "  wire [1899:0] lc_packet_actual_pair = {\{pair.join(", ")}};\n",
  )
  let hold =
    #|  logic lc_packet_seen_global = 1'b0;
    #|  logic lc_packet_previous_clock = 1'b0;
    #|  logic [1899:0] lc_packet_previous_pair;
    #|  always @($global_clock) begin
    #|    lc_packet_seen_global <= 1'b1;
    #|    lc_packet_previous_clock <= lc_clock;
    #|    lc_packet_previous_pair <= lc_packet_actual_pair;
    #|    lc_packet_nonrising_hold: assert ((!lc_packet_seen_global
    #|      || (!lc_packet_previous_clock && lc_clock)
    #|      || (lc_packet_actual_pair === lc_packet_previous_pair)) === 1'b1);
    #|  end
    #|
  out.write_string(hold)
  out.to_string()
}
