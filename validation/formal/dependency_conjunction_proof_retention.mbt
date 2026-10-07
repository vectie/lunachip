///|
// Checked nonrising conclusion only. All 79 original registers, four original
// read-result states and 12 original cells are observed directly (2226 bits).
fn dependency_conjunction_proof_retention(
  sequential : DependencyConjunctionSequential,
  emitted : @rtl.EmittedDesign,
) -> String raise {
  let pair : Array[String] = []
  let mut register_bits = 0
  let mut storage_bits = 0
  for root in sequential.probe.roots {
    pair.push(port_identifier(emitted, OutputPort, "current_" + root.name))
    register_bits += root.signal_type.width().bits()
  }
  let names = dependency_conjunction_proof_memory_identifiers(
    sequential, emitted,
  )
  for lane in sequential.probe.packet.lanes {
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      lane.result.id(),
    )
    pair.push(emitted_node_identifier(emitted, mapped.ordinal()))
    storage_bits += lane.result.signal_type().width().bits()
    for cell in 0..<lane.memory.depth().elements() {
      pair.push("\{names[lane.lane]}[\{cell}]")
      storage_bits += lane.memory.element_type().width().bits()
    }
  }
  if sequential.probe.roots.length() != 79 ||
    register_bits != 1202 ||
    sequential.probe.packet.lanes.length() != 4 ||
    storage_bits != 1024 {
    raise InvalidFormalBundleIdentity(
      "dependency proof inputs: complete original 2226-bit storage hold",
    )
  }
  let out = StringBuilder()
  out.write_string(
    "  wire [2225:0] lc_dependency_actual_pair = {\{pair.join(", ")}};\n",
  )
  let hold =
    #|  logic lc_dependency_seen_global = 1'b0;
    #|  logic lc_dependency_previous_clock = 1'b0;
    #|  logic [2225:0] lc_dependency_previous_pair;
    #|  always @($global_clock) begin
    #|    lc_dependency_seen_global <= 1'b1;
    #|    lc_dependency_previous_clock <= lc_clock;
    #|    lc_dependency_previous_pair <= lc_dependency_actual_pair;
    #|    lc_dependency_nonrising_hold: assert ((!lc_dependency_seen_global
    #|      || (!lc_dependency_previous_clock && lc_clock)
    #|      || (lc_dependency_actual_pair === lc_dependency_previous_pair)) === 1'b1);
    #|  end
    #|
  out.write_string(hold)
  out.to_string()
}
