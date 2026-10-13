///|
fn store_capture_observer(group : String) -> String raise {
  let support = store_lease_update_source() +
    "  always @(posedge lc_clock) begin\n" +
    store_lease_phase_support() +
    "  end\n" +
    store_capture_safety_source()
  let conclusion = match group {
    "capture-cursor" => store_capture_cursor_source()
    "capture-publication" => store_capture_publication_source()
    "capture-safety" => support
    "capture-composition" =>
      support +
      store_capture_cursor_source() +
      store_capture_publication_source() +
      store_preservation_control_source() +
      "  always @(posedge lc_clock) begin\n" +
      "    lc_capture_original_p2: assert (lc_capture_publication_and_lease === 1'b1);\n" +
      "  end\n"
    _ => raise InvalidFormalBundleIdentity("Store capture: unknown lemma")
  }
  store_lease_clock_source() + conclusion
}

///|
fn store_capture_source(
  inputs : StorePreservationProofInputs,
  group : String,
) -> String raise {
  let observer = store_preservation_proof_bindings(
      inputs.projection,
      inputs.emitted,
    ) +
    store_capture_observer(group)
  store_lease_select_bounds(
    store_preservation_adapter(inputs.projection, inputs.emitted, observer),
    inputs.memory_bounds,
  )
}

///|
// Generation only. Every support is simultaneously checked in its task.
#warnings("-unused_value")
fn store_capture_artifacts() -> ReadOnlyArray[FormalBundleArtifact] raise {
  let inputs = store_preservation_proof_inputs(
    @flux_tile.queued_concurrent_store_preservation_fixture(),
  )
  let artifacts : Array[FormalBundleArtifact] = []
  let inventory = StringBuilder()
  inventory.write_string(
    "SCOPE original-Store-capture-publication-component-not-full-payload-or-phase-gate\n" +
    "TOP \{inputs.top_identifier}\n" +
    "ORIGINAL-BOOLEAN sha256 \{sha256_hex(inputs.boolean_source)}\n" +
    "ORIGINAL-BRIDGE sha256 \{sha256_hex(inputs.positive)}\n" +
    "PROJECTION-REPORT sha256 \{sha256_hex(store_storage_projection_report(inputs.projection))}\n" +
    "BOUNDARY original-162-register-six-memory-projection-four-arbitrary-arithmetic-producers\n" +
    "SELECTION twelve-original-memory-bound-assertions-removed-only-no-transition-cut-change\n" +
    "ASSUMPTION one-first-sampled-joint-reset-later-reset-symbolic-no-fairness\n" +
    "SUPPORT all-relations-assertions-no-internal-assumption\n",
  )
  for
    group in [
      "capture-cursor", "capture-publication", "capture-safety", "capture-composition",
    ] {
    let source = store_capture_source(inputs, group)
    let config = store_lease_config(group, inputs.top_identifier)
    artifacts.push({ path: group + ".sv", content: source, })
    artifacts.push({ path: group + ".sby", content: config, })
    inventory.write_string(
      "LEMMA \{group} assertions \{store_capture_observer(group).split(": assert (").count() - 1} source-sha256 \{sha256_hex(source)} config-sha256 \{sha256_hex(config)}\n",
    )
  }
  artifacts.push({ path: "capture-inputs.txt", content: inventory.to_string(), })
  ReadOnlyArray::from_array(artifacts)
}
