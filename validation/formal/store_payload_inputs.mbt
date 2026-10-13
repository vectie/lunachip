///|
fn store_payload_groups() -> ReadOnlyArray[String] {
  [
    "payload-captured-slot0", "payload-captured-slot1", "payload-read-slot0", "payload-read-slot1",
    "payload-pending-composition", "payload-dma-transfer", "payload-store-composition",
  ]
}

///|
fn store_payload_observer(group : String) -> String raise {
  let selected = match group {
    "payload-captured-slot0" =>
      store_payload_producer_source() + store_payload_slot_source(0, false)
    "payload-captured-slot1" =>
      store_payload_producer_source() + store_payload_slot_source(1, false)
    "payload-read-slot0" =>
      store_payload_producer_source() + store_payload_slot_source(0, true)
    "payload-read-slot1" =>
      store_payload_producer_source() + store_payload_slot_source(1, true)
    "payload-pending-composition" =>
      store_payload_producer_source() +
      store_payload_slot_source(0, true) +
      store_payload_slot_source(1, true) +
      store_lease_pending_source() +
      store_payload_pending_source()
    "payload-dma-transfer" => store_payload_dma_source()
    "payload-store-composition" =>
      store_payload_producer_source() +
      store_payload_slot_source(0, true) +
      store_payload_slot_source(1, true) +
      store_lease_pending_source() +
      store_payload_pending_source() +
      store_payload_dma_source() +
      store_payload_composition_source()
    _ =>
      raise InvalidFormalBundleIdentity("Store payload: unknown selected group")
  }
  store_lease_clock_source() + selected
}

///|
fn store_payload_source(
  inputs : StorePreservationProofInputs,
  group : String,
) -> String raise {
  let observer = store_preservation_proof_bindings(
      inputs.projection,
      inputs.emitted,
    ) +
    store_payload_observer(group)
  store_lease_select_bounds(
    store_preservation_adapter(inputs.projection, inputs.emitted, observer),
    inputs.memory_bounds,
  )
}

///|
#warnings("-unused_value")
fn store_payload_artifacts() -> ReadOnlyArray[FormalBundleArtifact] raise {
  let inputs = store_preservation_proof_inputs(
    @flux_tile.queued_concurrent_store_preservation_fixture(),
  )
  let artifacts : Array[FormalBundleArtifact] = []
  let inventory = StringBuilder()
  inventory.write_string(
    "SCOPE original-source-capture-history-synchronous-read-pending-and-DMA-component-conclusions\n" +
    "TOP \{inputs.top_identifier}\n" +
    "ORIGINAL-BOOLEAN sha256 \{sha256_hex(inputs.boolean_source)}\n" +
    "ORIGINAL-BRIDGE sha256 \{sha256_hex(inputs.positive)}\n" +
    "PROJECTION-REPORT sha256 \{sha256_hex(store_storage_projection_report(inputs.projection))}\n" +
    "BOUNDARY unchanged-original-162-register-six-memory-projection-four-arbitrary-arithmetic-producers\n" +
    "SELECTION twelve-original-memory-bound-assertions-removed-only\n" +
    "ASSUMPTION one-first-sampled-joint-reset-later-reset-symbolic-no-fairness\n" +
    "OBSERVER nonfeeding-raw-producer-scalar-capture-history-no-SRAM-zero-no-arbitrary-read-payload\n" +
    "LIMITATION captured-read-basis-is-checked-condition-not-complete-generation-publication-coverage\n" +
    "LIMITATION DMA-transfer-samples-real-response-at-grant-not-independent-capture-origin-proof\n" +
    "COMPOSITION Store-origin-expectation-samples-independent-raw-producer-capture-read-history-through-genuine-grant-public-write\n" +
    "LIMITATION no-whole-Store-gate-memory-bounds-eventual-completion-or-Phase6-pass\n",
  )
  for group in store_payload_groups() {
    let source = store_payload_source(inputs, group)
    let config = store_lease_config(group, inputs.top_identifier)
    artifacts.push({ path: group + ".sv", content: source, })
    artifacts.push({ path: group + ".sby", content: config, })
    inventory.write_string(
      "LEMMA \{group} assertions \{source.split(": assert (").count() - 1} source-sha256 \{sha256_hex(source)} config-sha256 \{sha256_hex(config)}\n",
    )
  }
  artifacts.push({ path: "payload-inputs.txt", content: inventory.to_string(), })
  ReadOnlyArray::from_array(artifacts)
}
