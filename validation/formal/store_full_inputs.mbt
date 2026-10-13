///|
fn store_full_groups() -> ReadOnlyArray[String] {
  [
    "store-p5-composition", "store-p6-composition", "store-memory-bounds", "store-full-conjunction",
  ]
}

///|
// Reuse the previously checked relations as ASSERTs, not theorem premises.
// Original production/control/transfer/retention live unchanged in the bridge.
fn store_full_checked_support() -> String {
  store_lease_update_source() +
  "  always @(posedge lc_clock) begin\n" +
  store_lease_phase_support() +
  "  end\n" +
  store_capture_safety_source() +
  store_capture_cursor_source() +
  store_capture_publication_source() +
  store_capture_generation_prefix_source() +
  store_lease_exclusion_source() +
  store_p4_reservation_source() +
  store_p4_cursor_source() +
  store_p4_basis_source()
}

///|
// Remove only complete original property statements. Full keeps all nineteen
// original safety assertions and removes only the unrelated overlap cover.
fn store_full_remove_statement(
  source : String,
  label : String,
  operation : String,
) -> String raise {
  let marker = label + ": " + operation + " ("
  guard source.split("\n").filter(line => line.contains(marker)).collect()
    is [line] &&
    line.trim().has_prefix(marker) &&
    line.has_suffix(";") &&
    source.split(line.to_owned() + "\n").count() == 2 else {
    raise InvalidFormalBundleIdentity(
      "Store full: unique complete property statement",
    )
  }
  source.replace(old=line.to_owned() + "\n", new="")
}

///|
fn store_full_original_selected(
  inputs : StorePreservationProofInputs,
  group : String,
) -> String raise {
  guard store_full_groups().contains(group) else {
    raise InvalidFormalBundleIdentity("Store full: unknown selected group")
  }
  let full = group == "store-full-conjunction"
  let bounds = full || group == "store-memory-bounds"
  let mut selected = inputs.positive
  for property in inputs.properties.properties() {
    match property.kind() {
      Cover =>
        selected = store_full_remove_statement(
          selected,
          property.stable_name(),
          "cover",
        )
      Assertion => {
        let role = property.source_name()
        let keep = full ||
          (
            group != "store-memory-bounds" &&
            (
              [
                "reservation_exclusion", "produced_storage", "pending_and_dma_payload",
              ].contains(role) ||
              (
                group == "store-p5-composition" &&
                role == "cursor_progress_and_terminal"
              ) ||
              (group == "store-p6-composition" && role == "reset_establishment")
            )
          )
        if !keep {
          selected = store_full_remove_statement(
            selected,
            property.stable_name(),
            "assert",
          )
        }
      }
      Assumption => ()
    }
  }
  if !bounds {
    selected = store_lease_select_bounds(selected, inputs.memory_bounds)
  }
  if group == "store-p5-composition" {
    for label in inputs.global_assertions {
      selected = store_full_remove_statement(selected, label, "assert")
    }
  }
  selected
}

///|
fn store_full_source(
  inputs : StorePreservationProofInputs,
  group : String,
) -> String raise {
  let original = store_full_original_selected(inputs, group)
  let support = (if group == "store-memory-bounds" {
      ""
    } else {
      store_full_checked_support()
    }) +
    (if group == "store-memory-bounds" || group == "store-full-conjunction" {
      store_bounds_support_source(inputs)
    } else {
      ""
    })
  guard original.split("endmodule\n").count() == 2 &&
    !support.contains("endmodule") else {
    raise InvalidFormalBundleIdentity("Store full: unique original body splice")
  }
  original.replace(old="endmodule\n", new=support + "endmodule\n")
}

///|
#warnings("-unused_value")
fn store_full_artifacts() -> ReadOnlyArray[FormalBundleArtifact] raise {
  let inputs = store_preservation_proof_inputs(
    @flux_tile.queued_concurrent_store_preservation_fixture(),
  )
  let artifacts : Array[FormalBundleArtifact] = []
  let inventory = StringBuilder()
  inventory.write_string(
    "SCOPE exact-original-Store-p5-p6-and-all-nineteen-safety-conclusions\n" +
    "ORIGINAL-BOOLEAN sha256 \{sha256_hex(inputs.boolean_source)}\n" +
    "ORIGINAL-BRIDGE sha256 \{sha256_hex(inputs.positive)}\n" +
    "PROJECTION-REPORT sha256 \{sha256_hex(store_storage_projection_report(inputs.projection))}\n" +
    "BOUNDARY unchanged-original-162-register-six-memory-projection-four-arbitrary-arithmetic-producers\n" +
    "ASSUMPTION unchanged-one-first-sampled-joint-reset-later-reset-symbolic-no-fairness\n" +
    "OBSERVER unchanged-original-production-control-transfer-retention-no-zero-storage\n" +
    "FULL all-six-original-predicates-global-nonrising-hold-and-twelve-enabled-memory-bounds\n" +
    "SUPPORT selected-relations-all-simultaneously-ASSERT-no-internal-theorem-premise\n" +
    "LIMITATION no-numeric-MatMul-full8x8-fairness-overlap-sensitivity-fetched-or-Phase6-pass\n",
  )
  for group in store_full_groups() {
    let source = store_full_source(inputs, group)
    let config = store_lease_config(group, inputs.top_identifier)
    artifacts.push({ path: group + ".sv", content: source, })
    artifacts.push({ path: group + ".sby", content: config, })
    inventory.write_string(
      "LEMMA \{group} assertions \{source.split(": assert (").count() - 1} source-sha256 \{sha256_hex(source)} config-sha256 \{sha256_hex(config)}\n",
    )
  }
  artifacts.push({ path: "full-inputs.txt", content: inventory.to_string(), })
  ReadOnlyArray::from_array(artifacts)
}
