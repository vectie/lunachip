///|
// These are the four checked global conclusions in the accepted 2026-10-08
// component proof. They add no premise, state, cut or later-reset bypass.
fn fetched_transport_supporting_source() -> String {
  (
    #|    lc_fetched_offer_reader_tag: assert ((!lc_seen_edge || !(lc_raw_offer && lc_o_arbiter_owner == 2'd0) || lc_o_arbiter_local_tag == lc_o_reader_tag) === 1'b1);
    #|    lc_fetched_configured_base: assert ((!lc_seen_edge || !lc_configured_history || (lc_o_reader_state >= 3'd2 && lc_base_aligned && lc_base_in_aperture)) === 1'b1);
    #|    lc_fetched_active_population: assert ((!lc_seen_edge || !(lc_o_reader_state >= 3'd3 && lc_o_reader_state <= 3'd5) || lc_ring_population >= 32'd1) === 1'b1);
    #|    lc_fetched_unwritten_tail_zero: assert ((!lc_seen_edge || lc_byte_count >= 6'd32 || ((lc_byte_shadow >> (lc_byte_count * 32'd8)) == 256'd0)) === 1'b1);
    #|
  )
}

///|
fn fetched_transport_supported_source(
  sequential : FetchedTransportSequential,
  emitted : @rtl.EmittedDesign,
) -> String raise {
  let original = fetched_transport_proof_source(sequential, emitted)
  let anchor = "    lc_fetched_established: assert ((!lc_seen_edge || lc_raw_established) === 1'b1);\n"
  if original.split(anchor).count() != 2 {
    raise InvalidFormalBundleIdentity(
      "fetched support: unique global assertion anchor",
    )
  }
  original.replace(
    old=anchor,
    new=fetched_transport_supporting_source() + anchor,
  )
}

///|
// Reproduce the accepted source/config, not a new result or public task family.
// Legacy six-artifact generation remains unchanged.
#warnings("-unused_value")
fn fetched_transport_supported_artifacts() -> ReadOnlyArray[
  FormalBundleArtifact,
] raise {
  let sequential = fetched_transport_sequential()
  let view = fetched_transport_proof_view(sequential)
  let emitted = @rtl.emit_design(
    @ir.Design::single("FetchedTransportProofView", view),
  )
  let production = top_emitted_module(emitted).source()
  let (boolean_source, _) = dependency_boolean_helpers(view, production)
  let config =
    #|[options]
    #|mode prove
    #|depth 20
    #|timeout 600
    #|multiclock on
    #|expect pass
    #|[engines]
    #|smtbmc bitwuzla
    #|[script]
    #|logger -werror .*
    #|read_verilog -formal -sv -noautowire sequential-boolean.sv selected.sv
    #|prep -top lc_fetched_transport_bridge -flatten
    #|[files]
    #|sequential-boolean.sv /work/sequential-boolean.sv
    #|selected.sv /work/selected.sv
    #|
  [
    { path: "sequential-boolean.sv", content: boolean_source, },
    {
      path: "selected.sv",
      content: fetched_transport_supported_source(sequential, emitted),
    },
    { path: "prove.sby", content: config, },
  ]
}
