///|
test "Store p6 retains exact reset ghosts physical storage and nonrising hold without added support" {
  let inputs = store_preservation_proof_inputs(
    @flux_tile.queued_concurrent_store_preservation_fixture(),
  )
  assert_eq(
    sha256_hex(inputs.positive),
    "9925e74a3d60045fd21f5fd86733827e2267baeadbbe31f6cf8ab5f5ac494121",
  )
  let inventory = store_clock_reset_inventory(inputs.projection, inputs.emitted)
  let production = store_preservation_production_source()
  let transfer = store_preservation_transfer_source(false)
  let retention = store_preservation_retention_source(
    inputs.projection,
    inputs.emitted,
  )
  // The existing original retention observer is sufficient: no strengthening
  // predicate, reset bypass, or reset-to-zero memory model is introduced.
  assert_eq(inventory.reset_checks.length(), 162)
  assert_eq(inventory.register_bits, 2427)
  assert_eq(inventory.memory_bits, 1344)
  for check in inventory.reset_checks {
    assert_true(retention.contains(check))
  }
  for term in inventory.memory {
    assert_true(retention.contains(term))
  }
  assert_true(retention.contains("wire [1343:0] lc_actual_memory_pair"))
  assert_true(retention.contains("wire [3770:0] lc_actual_state_pair"))
  assert_true(
    retention.contains("lc_reset_fires_suppressed && (!lc_previous_reset || ("),
  )
  assert_true(
    retention.contains("lc_actual_memory_pair === lc_pre_memory_pair"),
  )
  assert_true(
    retention.contains(
      "(!lc_seen_global || (!lc_previous_clock && lc_clock) || (lc_actual_state_pair === lc_previous_state_pair))",
    ),
  )
  for slot in 0..<2 {
    for field in ["written", "valid", "rows", "columns", "read_tracked"] {
      let name = "lc_g_\{field}_\{slot}"
      assert_true(retention.contains(name))
      let reset_value = match field {
        "written" | "rows" | "columns" => "4'd0"
        _ => "1'b0"
      }
      assert_true(production.contains("\{name} <= \{reset_value};"))
    }
    assert_false(production.contains("lc_g_read_word_\{slot} <= 32'd0"))
    for cell in 0..<4 {
      assert_false(production.contains("lc_g_word_\{slot}_\{cell} <= 32'd0"))
    }
  }
  for
    field in [
      "read_active", "read_due", "read_basis", "dma_store", "store_seen", "read_seen",
      "pregrant_seen", "opposite_intermediate", "opposite_final", "grant_seen", "write_seen",
      "ack_seen", "opposite_generation_live", "completed_overlap",
    ] {
    let name = "lc_g_\{field}"
    assert_true(retention.contains("!" + name))
    assert_true(transfer.contains("\{name} <= 1'b0;"))
  }
  for
    field in [
      "read_word", "dma_word", "dma_address", "dma_local_tag", "read_id", "read_address",
      "read_slot", "read_fault",
    ] {
    for value in ["1'b0", "1'd0", "2'd0", "6'd0", "32'd0"] {
      assert_false(transfer.contains("lc_g_\{field} <= \{value}"))
    }
  }
  for
    event in [
      "StoreAccept", "ReadAccept", "StoreRequestValid", "StoreRequestAccept", "StoreResponseGood",
      "StoreResponseRemote", "StoreResponseProtocol", "StoreInternalFault", "StoreCancelled",
      "StoreTerminal", "ComputeAccept", "ComputeLegalAccept", "SlottedAccept", "SlottedLegalAccept",
      "Capture", "FinalCapture", "CoreAccept", "CoreAdvance", "ResponseValid",
    ] {
    assert_true(retention.contains("lc_e_" + event))
  }
  let selected =
    #|  always @(posedge lc_clock) begin
    #|    lc_store_p6_test_startup: assume (lc_startup_reset === 1'b1);
    #|    lc_store_p6_test_original_p6: assert (lc_reset_establishment === 1'b1);
    #|  end
    #|
  let observer = store_preservation_proof_bindings(
      inputs.projection,
      inputs.emitted,
    ) +
    production +
    store_preservation_control_source() +
    transfer +
    retention +
    selected
  let source = store_lease_select_bounds(
    store_preservation_adapter(inputs.projection, inputs.emitted, observer),
    inputs.memory_bounds,
  )
  let body = store_lease_select_bounds(
    store_preservation_adapter(inputs.projection, inputs.emitted, ""),
    inputs.memory_bounds,
  )
  assert_eq(source.replace(old=observer, new=""), body)
  assert_eq(source.split(retention).count(), 2)
  assert_eq(source.split(": assert (").count() - 1, 2)
  assert_eq(source.split(": assume (").count() - 1, 1)
  assert_false(source.contains(": cover ("))
  assert_eq(source.split("logic lc_seen_edge = 1'b0;").count(), 2)
  assert_false(retention.contains("<= 32'd0"))
  assert_false(retention.contains(": assume ("))
  let p4_observer = store_preservation_proof_bindings(
      inputs.projection,
      inputs.emitted,
    ) +
    store_p4_observer("store-p4-composition")
  let p6_assertion =
    #|  always @(posedge lc_clock) begin
    #|    lc_store_p6_test_joint_p6: assert (lc_reset_establishment === 1'b1);
    #|  end
    #|
  let joint_observer = p4_observer + retention + p6_assertion
  let joint = store_lease_select_bounds(
    store_preservation_adapter(
      inputs.projection,
      inputs.emitted,
      joint_observer,
    ),
    inputs.memory_bounds,
  )
  assert_eq(joint.replace(old=joint_observer, new=""), body)
  assert_eq(joint.split(retention).count(), 2)
  assert_eq(joint.split(production).count(), 2)
  assert_eq(joint.split(transfer).count(), 2)
  assert_eq(joint.split(": assert (").count() - 1, 87)
  assert_eq(joint.split(": assume (").count() - 1, 1)
  assert_false(joint.contains(": cover ("))
  assert_eq(joint.split("logic lc_seen_edge = 1'b0;").count(), 2)
}
