///|
// Original production observers own the startup history and generation masks;
// physical last-capture history is not a replacement eligibility premise.
fn store_generation_observer() -> String {
  let startup =
    #|  always @(posedge lc_clock) begin
    #|    lc_store_generation_startup: assume (lc_startup_reset === 1'b1);
    #|  end
    #|
  let selected =
    #|  always @(posedge lc_clock) begin
    #|    lc_store_generation_original_p3: assert (lc_produced_storage === 1'b1);
    #|  end
    #|
  store_preservation_production_source() +
  startup +
  store_lease_update_source() +
  "  always @(posedge lc_clock) begin\n" +
  store_lease_phase_support() +
  "  end\n" +
  store_capture_safety_source() +
  store_capture_cursor_source() +
  store_capture_publication_source() +
  store_capture_generation_prefix_source() +
  selected
}

///|
fn store_generation_source(
  inputs : StorePreservationProofInputs,
) -> String raise {
  let observer = store_preservation_proof_bindings(
      inputs.projection,
      inputs.emitted,
    ) +
    store_generation_observer()
  store_lease_select_bounds(
    store_preservation_adapter(inputs.projection, inputs.emitted, observer),
    inputs.memory_bounds,
  )
}

///|
// Private inputs only. The original p3 expression and production observer are
// unchanged; new strengthening relations are simultaneously checked.
#warnings("-unused_value")
fn store_generation_artifacts() -> ReadOnlyArray[FormalBundleArtifact] raise {
  let inputs = store_preservation_proof_inputs(
    @flux_tile.queued_concurrent_store_preservation_fixture(),
  )
  let source = store_generation_source(inputs)
  let group = "payload-generation-storage"
  let config = store_lease_config(group, inputs.top_identifier)
  [
    { path: group + ".sv", content: source, },
    { path: group + ".sby", content: config, },
    {
      path: "generation-inputs.txt",
      content: "SCOPE original-Store-produced-storage-p3-with-checked-generation-prefix\n" +
      "ORIGINAL-BOOLEAN sha256 \{sha256_hex(inputs.boolean_source)}\n" +
      "ORIGINAL-BRIDGE sha256 \{sha256_hex(inputs.positive)}\n" +
      "PROJECTION-REPORT sha256 \{sha256_hex(store_storage_projection_report(inputs.projection))}\n" +
      "BOUNDARY unchanged-original-162-register-six-memory-projection-four-arbitrary-arithmetic-producers\n" +
      "SELECTION twelve-original-memory-bound-assertions-removed-only\n" +
      "ASSUMPTION one-first-sampled-joint-reset-later-reset-symbolic-no-fairness\n" +
      "OBSERVER original-production-raw-words-per-generation-written-mask-cleared-at-legal-admission\n" +
      "SUPPORT paired-lease-capture-shape-cursor-publication-prefix-all-simultaneously-ASSERT\n" +
      "CONCLUSION exact-original-lc_produced_storage-not-physical-history-substitute\n" +
      "LIMITATION no-whole-Store-p4-DMA-composition-memory-bounds-eventual-completion-or-Phase6-pass\n" +
      "LEMMA \{group} assertions \{source.split(": assert (").count() - 1} source-sha256 \{sha256_hex(source)} config-sha256 \{sha256_hex(config)}\n",
    },
  ]
}
