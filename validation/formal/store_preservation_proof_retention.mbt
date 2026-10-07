///|
// Observe ALL original projection storage: every retained register, all twenty
// actual cells and all six actual synchronous read-result states. No copied
// hardware memory, hierarchy, initializer or reset-to-zero storage fiction.
fn store_preservation_retention_source(
  projection : StoreStorageProjection,
  emitted : @rtl.EmittedDesign,
) -> String raise {
  let out = StringBuilder()
  let registers : Array[String] = []
  let reset_checks : Array[String] = []
  let memory_pair : Array[String] = []
  let mut register_bits = 0
  let mut memory_bits = 0
  for original in projection.plan.selected {
    if projection.plan.arithmetic.any(cut => cut.id() == original.id()) {
      continue
    }
    let identifier = store_preservation_node_identifier(
      projection,
      emitted,
      original.id(),
    )
    match original.kind() {
      Register(spec) => {
        guard spec.reset() is Some(control) &&
          control.signal() == projection.plan.probe.reset &&
          control.mode() is Synchronous &&
          control.polarity() is ActiveHigh else {
          raise InvalidFormalBundleIdentity(
            "Store proof: exact synchronous register reset binding",
          )
        }
        register_bits += original.signal_type().width().bits()
        registers.push(identifier)
        reset_checks.push(
          "(\{identifier} == \{original.signal_type().width().bits()}'h\{control.value().to_string(radix=16)})",
        )
      }
      MemoryRead(..) => {
        memory_bits += original.signal_type().width().bits()
        memory_pair.push(identifier)
      }
      _ => ()
    }
  }
  let names = store_preservation_memory_identifiers(projection, emitted)
  for index, memory in projection.plan.memories {
    for cell in 0..<memory.depth().elements() {
      memory_pair.push("\{names[index]}[\{cell}]")
      memory_bits += memory.element_type().width().bits()
    }
  }
  if registers.length() != 162 ||
    projection.plan.memories.length() != 6 ||
    memory_bits != 1344 {
    raise InvalidFormalBundleIdentity(
      "Store proof: complete original state/storage hold inventory",
    )
  }
  let width = register_bits + memory_bits
  out.write_string(
    "  wire [\{memory_bits - 1}:0] lc_actual_memory_pair = {\{memory_pair.join(", ")}};\n  wire [\{width - 1}:0] lc_actual_state_pair = {\{registers.join(", ")}, lc_actual_memory_pair};\n  logic [\{memory_bits - 1}:0] lc_pre_memory_pair;\n  always @(posedge lc_clock) lc_pre_memory_pair <= lc_actual_memory_pair;\n",
  )
  let cleared =
    #|  wire lc_ghost_reset_cleared = lc_g_written_0 == 0 && lc_g_written_1 == 0
    #|    && !lc_g_valid_0 && !lc_g_valid_1 && lc_g_rows_0 == 0 && lc_g_rows_1 == 0
    #|    && lc_g_columns_0 == 0 && lc_g_columns_1 == 0 && !lc_g_read_tracked_0 && !lc_g_read_tracked_1
    #|    && !lc_g_read_active && !lc_g_read_due && !lc_g_read_basis && !lc_g_dma_store
    #|    && !lc_g_store_seen && !lc_g_read_seen && !lc_g_pregrant_seen && !lc_g_opposite_intermediate
    #|    && !lc_g_opposite_final && !lc_g_grant_seen && !lc_g_write_seen && !lc_g_ack_seen
    #|    && !lc_g_opposite_generation_live && !lc_g_completed_overlap;
    #|  wire lc_reset_fires_suppressed = !lc_reset || !(lc_e_StoreAccept || lc_e_ReadAccept
    #|    || lc_e_StoreRequestValid || lc_e_StoreRequestAccept || lc_e_StoreResponseGood
    #|    || lc_e_StoreResponseRemote || lc_e_StoreResponseProtocol || lc_e_StoreInternalFault
    #|    || lc_e_StoreCancelled || lc_e_StoreTerminal || lc_e_ComputeAccept || lc_e_ComputeLegalAccept
    #|    || lc_e_SlottedAccept || lc_e_SlottedLegalAccept || lc_e_Capture || lc_e_FinalCapture
    #|    || lc_e_CoreAccept || lc_e_CoreAdvance || lc_e_ResponseValid);
    #|
  out.write_string(cleared)
  out.write_string(
    "  wire lc_reset_establishment = lc_reset_fires_suppressed && (!lc_previous_reset || (\{reset_checks.join(" && ")} && lc_ghost_reset_cleared && (lc_actual_memory_pair === lc_pre_memory_pair)));\n",
  )
  out.write_string(
    "  logic lc_seen_global = 1'b0;\n  logic lc_previous_clock = 1'b0;\n  logic [\{width - 1}:0] lc_previous_state_pair;\n  always @($global_clock) begin\n    lc_seen_global <= 1'b1;\n    lc_previous_clock <= lc_clock;\n    lc_previous_state_pair <= lc_actual_state_pair;\n    lc_store_nonrising_hold: assert ((!lc_seen_global || (!lc_previous_clock && lc_clock) || (lc_actual_state_pair === lc_previous_state_pair)) === 1'b1);\n  end\n",
  )
  out.to_string()
}
