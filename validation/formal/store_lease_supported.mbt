///|
// A checked source-state relation closes the induction-only Issue/capture
// combination. It is never an internal assumption, free input, or reset bypass.
// Outer Idle/Issue/Done pair with inner Idle; entry into Run and inner admission
// commit together, as do outer completion and the inner Done acknowledgement.
fn store_lease_phase_support() -> String {
  (
    #|    lc_lease_outer_inner_phase: assert ((!lc_seen_edge || lc_o_compute_State == 2'd2 || lc_o_slotted_State == 2'd0) === 1'b1);
    #|
  )
}

///|
fn store_lease_supported_source(
  inputs : StorePreservationProofInputs,
) -> String raise {
  let original = store_lease_source(inputs, "lease-update")
  let anchor = "    lc_lease_issue_owned: assert ((!lc_seen_edge || lc_o_compute_State != 2'd1 || lc_o_compute_Leased) === 1'b1);\n"
  let added = store_lease_phase_support()
  if original.split(anchor).count() != 2 || original.contains(added) {
    raise InvalidFormalBundleIdentity(
      "Store lease support: unique original Issue assertion",
    )
  }
  let supported = original.replace(old=anchor, new=added + anchor)
  if supported.replace(old=added, new="") != original {
    raise InvalidFormalBundleIdentity(
      "Store lease support: reversible assertion-only insertion",
    )
  }
  supported
}

///|
// New independently executable inputs. The previous four-conclusion attempt
// and its unsuccessful evidence remain unchanged; generating five conclusions
// is not itself a new proof result.
#warnings("-unused_value")
fn store_lease_supported_artifacts() -> ReadOnlyArray[FormalBundleArtifact] raise {
  let inputs = store_preservation_proof_inputs(
    @flux_tile.queued_concurrent_store_preservation_fixture(),
  )
  [
    {
      path: "lease-update-supported.sv",
      content: store_lease_supported_source(inputs),
    },
    {
      path: "lease-update-supported.sby",
      content: store_lease_config(
        "lease-update-supported",
        inputs.top_identifier,
      ),
    },
  ]
}
