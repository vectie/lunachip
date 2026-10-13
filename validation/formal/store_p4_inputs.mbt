///|
fn store_p4_groups() -> ReadOnlyArray[String] {
  [
    "store-p4-reservation", "store-p4-cursor", "store-p4-generation-basis", "store-p4-composition",
  ]
}

///|
// Original observers and DUT are unchanged. Support is jointly asserted,
// never imported as an internal assumption from an earlier passing task.
fn store_p4_observer(group : String) -> String raise {
  guard store_p4_groups().contains(group) else {
    raise InvalidFormalBundleIdentity("Store p4: unknown selected group")
  }
  let startup =
    #|  always @(posedge lc_clock) begin
    #|    lc_store_p4_startup: assume (lc_startup_reset === 1'b1);
    #|  end
    #|
  let support = store_preservation_production_source() +
    store_preservation_control_source() +
    store_preservation_transfer_source(false) +
    startup +
    store_lease_update_source() +
    "  always @(posedge lc_clock) begin\n" +
    store_lease_phase_support() +
    "  end\n" +
    store_capture_safety_source() +
    store_capture_cursor_source() +
    store_capture_publication_source() +
    store_capture_generation_prefix_source() +
    store_lease_exclusion_source() +
    store_p4_reservation_source()
  let cursor = if group == "store-p4-reservation" {
    ""
  } else {
    store_p4_cursor_source()
  }
  let basis = if group == "store-p4-generation-basis" ||
    group == "store-p4-composition" {
    store_p4_basis_source()
  } else {
    ""
  }
  let conclusions = match group {
    "store-p4-reservation" =>
      "    lc_store_p4_original_p1: assert (lc_reservation_exclusion === 1'b1);\n"
    "store-p4-generation-basis" =>
      "    lc_store_p4_original_p3: assert (lc_produced_storage === 1'b1);\n"
    "store-p4-composition" =>
      "    lc_store_p4_original_p1: assert (lc_reservation_exclusion === 1'b1);\n" +
      "    lc_store_p4_original_p3: assert (lc_produced_storage === 1'b1);\n" +
      "    lc_store_p4_original_p4: assert (lc_pending_and_dma_payload === 1'b1);\n"
    _ => ""
  }
  support +
  cursor +
  basis +
  "  always @(posedge lc_clock) begin\n" +
  conclusions +
  "  end\n"
}

///|
fn store_p4_source(
  inputs : StorePreservationProofInputs,
  group : String,
) -> String raise {
  let observer = store_preservation_proof_bindings(
      inputs.projection,
      inputs.emitted,
    ) +
    store_p4_observer(group)
  store_lease_select_bounds(
    store_preservation_adapter(inputs.projection, inputs.emitted, observer),
    inputs.memory_bounds,
  )
}

///|
#warnings("-unused_value")
fn store_p4_artifacts() -> ReadOnlyArray[FormalBundleArtifact] raise {
  let inputs = store_preservation_proof_inputs(
    @flux_tile.queued_concurrent_store_preservation_fixture(),
  )
  let artifacts : Array[FormalBundleArtifact] = []
  let inventory = StringBuilder()
  inventory.write_string(
    "SCOPE exact-original-Store-p4-with-checked-generation-reservation-full-width-cursor\n" +
    "ORIGINAL-BOOLEAN sha256 \{sha256_hex(inputs.boolean_source)}\n" +
    "ORIGINAL-BRIDGE sha256 \{sha256_hex(inputs.positive)}\n" +
    "PROJECTION-REPORT sha256 \{sha256_hex(store_storage_projection_report(inputs.projection))}\n" +
    "BOUNDARY unchanged-original-162-register-six-memory-projection-four-arbitrary-arithmetic-producers\n" +
    "SELECTION twelve-original-memory-bound-assertions-removed-only\n" +
    "ASSUMPTION one-first-sampled-joint-reset-later-reset-symbolic-no-fairness\n" +
    "OBSERVER original-production-and-transfer-no-payload-output-as-origin\n" +
    "SUPPORT all-selected-strengthening-simultaneously-ASSERT-not-premises\n" +
    "LIMITATION no-whole-Store-conjunction-memory-bounds-numeric-MatMul-full8x8-fairness-or-Phase6-pass\n",
  )
  for group in store_p4_groups() {
    let source = store_p4_source(inputs, group)
    let config = store_lease_config(group, inputs.top_identifier)
    artifacts.push({ path: group + ".sv", content: source, })
    artifacts.push({ path: group + ".sby", content: config, })
    inventory.write_string(
      "LEMMA \{group} assertions \{source.split(": assert (").count() - 1} source-sha256 \{sha256_hex(source)} config-sha256 \{sha256_hex(config)}\n",
    )
  }
  artifacts.push({ path: "p4-inputs.txt", content: inventory.to_string(), })
  ReadOnlyArray::from_array(artifacts)
}
