///|
// Selected conclusions over the exact original Store projection. Bounds are
// unrelated assertions, not assumptions: removing their complete statements
// permits control-cone reduction without changing any transition or free cut.
fn store_lease_select_bounds(
  source : String,
  labels : ReadOnlyArray[String],
) -> String raise {
  let mut selected = source
  if labels.length() != 12 {
    raise InvalidFormalBundleIdentity("Store lease: exact twelve memory bounds")
  }
  for label in labels {
    let lines = selected
      .split("\n")
      .filter(line => line.contains(label + ": assert"))
      .collect()
    guard lines is [line] else {
      raise InvalidFormalBundleIdentity("Store lease: unique original bound")
    }
    selected = selected.replace(old=line + "\n", new="")
  }
  selected
}

///|
fn store_lease_clock_source() -> String {
  (
    #|  logic lc_seen_edge = 1'b0;
    #|  logic lc_previous_reset = 1'b0;
    #|  always @(posedge lc_clock) begin
    #|    lc_seen_edge <= 1'b1;
    #|    lc_previous_reset <= lc_reset;
    #|    lc_store_lease_startup: assume ((lc_seen_edge || lc_reset) === 1'b1);
    #|  end
    #|
  )
}

///|
// Exact source-width equations, not the stronger reachable-cursor relation.
// In particular original capture uses modular UInt4 increments; widening that
// expression would require a separately checked legal-shape/cursor invariant.
fn store_lease_update_source() -> String {
  (
    #|  wire lc_lease_final_exact = lc_e_Capture
    #|    && (lc_o_slotted_CaptureRow + 4'd1 == lc_o_core_Rows)
    #|    && (lc_o_slotted_CaptureColumn + 4'd1 == lc_o_core_Columns);
    #|  wire lc_lease_release_exact = lc_e_FinalCapture || (!lc_reset
    #|    && lc_o_compute_State == 2'd2 && lc_o_slotted_State == 2'd3 && !lc_e_OwnershipActive);
    #|  always @(posedge lc_clock) begin
    #|    lc_lease_final_definition: assert ((lc_e_FinalCapture == lc_lease_final_exact) === 1'b1);
    #|    lc_lease_release_definition: assert ((lc_e_ComputeRelease == lc_lease_release_exact) === 1'b1);
    #|    lc_lease_registered_update: assert ((!lc_seen_edge || lc_o_compute_Leased ==
    #|      (lc_previous_reset ? 1'b0 : (lc_pre_lc_e_ComputeLegalAccept ? 1'b1
    #|      : (lc_pre_lc_e_ComputeRelease ? 1'b0 : lc_pre_lc_o_compute_Leased)))) === 1'b1);
    #|    lc_lease_issue_owned: assert ((!lc_seen_edge || lc_o_compute_State != 2'd1 || lc_o_compute_Leased) === 1'b1);
    #|  end
    #|
  )
}

///|
// Old PRE ownership governs admission even on terminal/release edges. Held
// Done owns its completion record but is deliberately absent from reservation.
fn store_lease_exclusion_source() -> String {
  (
    #|  wire lc_lease_store_reserved = lc_o_store_State == 3'd1
    #|    || lc_o_store_State == 3'd2 || lc_o_store_State == 3'd3;
    #|  always @(posedge lc_clock) begin
    #|    lc_lease_store_active_exact: assert ((lc_e_StoreActive == (!lc_reset && lc_lease_store_reserved)) === 1'b1);
    #|    lc_lease_store_blocks_compute: assert ((!lc_lease_store_reserved || !lc_e_ComputeAccept
    #|      || lc_incoming_compute_c != lc_o_store_Slot) === 1'b1);
    #|    lc_lease_compute_blocks_store: assert ((!lc_o_compute_Leased || !lc_e_StoreAccept
    #|      || lc_incoming_store_slot != lc_o_compute_C) === 1'b1);
    #|    lc_lease_same_edge_admission: assert ((!lc_e_ComputeLegalAccept || !lc_e_StoreAccept
    #|      || lc_incoming_store_slot != lc_incoming_compute_c) === 1'b1);
    #|  end
    #|
  )
}

///|
// Pending is sampled OLD state. response_ready can clear it at the commit, but
// cannot permit a same-slot inner command on that same acknowledgement edge.
// Outer admission is intentionally not forbidden while the response drains.
fn store_lease_pending_source() -> String {
  (
    #|  wire lc_lease_core_response_ready = !lc_reset
    #|    && (lc_o_store_State == 3'd3 || lc_o_store_State == 3'd4);
    #|  logic lc_lease_pre_response_ready;
    #|  always @(posedge lc_clock) lc_lease_pre_response_ready <= lc_lease_core_response_ready;
    #|  always @(posedge lc_clock) begin
    #|    lc_lease_pending_blocks_inner: assert ((!lc_o_slotted_Pending || !lc_e_SlottedAccept
    #|      || lc_o_compute_C != lc_o_slotted_ResponseSlot) === 1'b1);
    #|    lc_lease_pending_blocks_read: assert ((!lc_o_slotted_Pending || !lc_e_ReadAccept) === 1'b1);
    #|    lc_lease_pending_update: assert ((!lc_seen_edge || lc_o_slotted_Pending ==
    #|      (lc_previous_reset ? 1'b0 : (lc_pre_lc_e_ReadAccept ? 1'b1
    #|      : (lc_pre_lc_o_slotted_Pending && !lc_lease_pre_response_ready)))) === 1'b1);
    #|    lc_lease_pending_selector_hold: assert ((!lc_seen_edge || lc_previous_reset
    #|      || !lc_pre_lc_o_slotted_Pending || lc_o_slotted_ResponseSlot == lc_pre_lc_o_slotted_ResponseSlot) === 1'b1);
    #|  end
    #|
  )
}

///|
fn store_lease_observer(group : String) -> String raise {
  let conclusion = match group {
    "lease-update" => store_lease_update_source()
    "lease-exclusion" => store_lease_exclusion_source()
    "pending-protection" => store_lease_pending_source()
    _ => raise InvalidFormalBundleIdentity("Store lease: unknown lemma")
  }
  store_lease_clock_source() + conclusion
}

///|
fn store_lease_source(
  inputs : StorePreservationProofInputs,
  group : String,
) -> String raise {
  let observer = store_preservation_proof_bindings(
      inputs.projection,
      inputs.emitted,
    ) +
    store_lease_observer(group)
  store_lease_select_bounds(
    store_preservation_adapter(inputs.projection, inputs.emitted, observer),
    inputs.memory_bounds,
  )
}

///|
fn store_lease_config(group : String, top : String) -> String {
  "[options]\nmode prove\ndepth 20\ntimeout 600\nmulticlock on\nexpect pass\n[engines]\nsmtbmc bitwuzla\n[script]\nlogger -werror .*\nread_verilog -formal -sv -noautowire \{group}.sv\nprep -top \{top}\nwrite_rtlil /out/\{group}-prepared.rtlil\n[files]\n\{group}.sv /work/\{group}.sv\n"
}

///|
// Private support collector only. No public task/receipt or accepted theorem
// is manufactured by generating these independently executable inputs.
#warnings("-unused_value")
fn store_lease_artifacts() -> ReadOnlyArray[FormalBundleArtifact] raise {
  let inputs = store_preservation_proof_inputs(
    @flux_tile.queued_concurrent_store_preservation_fixture(),
  )
  let artifacts : Array[FormalBundleArtifact] = []
  let inventory = StringBuilder()
  inventory.write_string(
    "SCOPE original-Store-clocked-lease-component-conclusions-not-payload-preservation-or-phase-gate\n" +
    "TOP \{inputs.top_identifier}\n" +
    "ORIGINAL-BOOLEAN sha256 \{sha256_hex(inputs.boolean_source)}\n" +
    "ORIGINAL-BRIDGE sha256 \{sha256_hex(inputs.positive)}\n" +
    "PROJECTION-REPORT sha256 \{sha256_hex(store_storage_projection_report(inputs.projection))}\n" +
    "BOUNDARY unchanged-original-162-register-six-memory-projection-four-arbitrary-arithmetic-producers\n" +
    "SELECTION twelve-original-memory-bound-assertions-removed-only-no-transition-cut-or-internal-premise-change\n" +
    "ASSUMPTION one-first-sampled-joint-reset-later-reset-symbolic-no-fairness\n" +
    "LIMITATION no-capture-to-lease-shape-proof-memory-bounds-payload-preservation-or-eventual-completion\n",
  )
  for group in ["lease-update", "lease-exclusion", "pending-protection"] {
    let source = store_lease_source(inputs, group)
    let config = store_lease_config(group, inputs.top_identifier)
    artifacts.push({ path: group + ".sv", content: source, })
    artifacts.push({ path: group + ".sby", content: config, })
    inventory.write_string(
      "LEMMA \{group} assertions 4 source-sha256 \{sha256_hex(source)} config-sha256 \{sha256_hex(config)}\n",
    )
  }
  artifacts.push({ path: "lease-inputs.txt", content: inventory.to_string(), })
  ReadOnlyArray::from_array(artifacts)
}
