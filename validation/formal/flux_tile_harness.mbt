///|
fn flux_tile_harness(
  fixture : FluxTileFormalFixture,
  dut : FluxTileFormalDut,
  property_source : String,
) -> String {
  let out = StringBuilder()
  let header =
    #|`default_nettype none
    #|// Public transport only. Production DUT and canonical graph are unchanged.
    #|// One global step toggles the clock: two global steps per DUT clock.
    #|module lc_formal_flux_tile_top;
    #|  logic lc_clock = 1'b0;
    #|  always @($global_clock) lc_clock <= ~lc_clock;
    #|
  out.write_string(header)
  for port in dut.ports {
    if port.role != "clock" {
      let symbolic = if port.input { "(* anyseq *) " } else { "" }
      let range = if port.width == 1 { "" } else { "[\{port.width - 1}:0] " }
      out.write_string("  \{symbolic}logic \{range}lc_\{port.role};\n")
    }
  }
  out.write_string("  \{dut.identifier} lc_dut (\n")
  for index, port in dut.ports {
    out.write_string("    .\{port.identifier}(lc_\{port.role})")
    out.write_string(if index + 1 == dut.ports.length() { "\n" } else { ",\n" })
  }
  out.write_string("  );\n")
  let monitor =
    #|  logic lc_seen_edge = 1'b0;
    #|  logic lc_owned = 1'b0;
    #|  logic lc_previous_request_hold = 1'b0;
    #|  logic lc_previous_completion_hold = 1'b0;
    #|  logic lc_previous_config_hold = 1'b0;
    #|  logic lc_previous_publication_hold = 1'b0;
    #|  logic lc_previous_response_hold = 1'b0;
    #|  logic [103:0] lc_previous_request_payload = 104'd0;
    #|  logic [99:0] lc_previous_completion_payload = 100'd0;
    #|  logic [63:0] lc_previous_config_payload = 64'd0;
    #|  logic [31:0] lc_previous_publication_payload = 32'd0;
    #|  logic [65:0] lc_previous_response_payload = 66'd0;
    #|  wire [103:0] lc_request_payload = {lc_memory_request_write,
    #|    lc_memory_request_address, lc_memory_request_bytes,
    #|    lc_memory_request_mask, lc_memory_request_data, lc_memory_request_tag};
    #|  wire [99:0] lc_completion_payload = {lc_completion_id,
    #|    lc_completion_fault, lc_completion_bytes_completed, lc_completion_fault_address};
    #|  wire [63:0] lc_config_payload = {lc_config_base, lc_config_origin};
    #|  wire [65:0] lc_response_payload = {lc_memory_response_tag,
    #|    lc_memory_response_fault, lc_memory_response_data};
    #|  wire lc_request_accept = !lc_reset && lc_memory_request_valid && lc_memory_request_ready;
    #|  wire lc_response_accept = !lc_reset && lc_memory_response_valid && lc_memory_response_ready;
    #|  always_ff @(posedge lc_clock) begin
    #|    lc_seen_edge <= 1'b1;
    #|    if (lc_reset) begin
    #|      lc_owned <= 1'b0;
    #|      lc_previous_request_hold <= 1'b0;
    #|      lc_previous_completion_hold <= 1'b0;
    #|      lc_previous_config_hold <= 1'b0;
    #|      lc_previous_publication_hold <= 1'b0;
    #|      lc_previous_response_hold <= 1'b0;
    #|    end else begin
    #|      // Actual pre-edge external handshakes; no inferred controller state.
    #|      if (lc_request_accept) lc_owned <= 1'b1;
    #|      else if (lc_response_accept) lc_owned <= 1'b0;
    #|      lc_previous_request_hold <= lc_memory_request_valid && !lc_memory_request_ready;
    #|      lc_previous_completion_hold <= lc_completion_valid && !lc_completion_ready;
    #|      lc_previous_config_hold <= lc_config_valid && !lc_config_ready;
    #|      lc_previous_publication_hold <= lc_publish_valid && !lc_publish_ready;
    #|      lc_previous_response_hold <= lc_memory_response_valid && !lc_memory_response_ready;
    #|      // Capture the genuine first stalled value, never a mutant observation.
    #|      lc_previous_request_payload <= lc_request_payload;
    #|      lc_previous_completion_payload <= lc_completion_payload;
    #|      lc_previous_config_payload <= lc_config_payload;
    #|      lc_previous_publication_payload <= lc_publish_producer;
    #|      lc_previous_response_payload <= lc_response_payload;
    #|    end
    #|  end
    #|
  out.write_string(monitor)
  let address = if fixture is NegativeRequestBounds {
    "{1'b1, lc_memory_request_address}"
  } else {
    "{1'b0, lc_memory_request_address}"
  }
  let data = if fixture is NegativeRequestStability {
    "lc_memory_request_data ^ (lc_previous_request_hold ? 32'd1 : 32'd0)"
  } else {
    "lc_memory_request_data"
  }
  // These isolated mutations touch precisely the monitor input path. They
  // establish sensitivity only, not a production implementation counterexample.
  out.write_string("  wire [32:0] lc_checked_request_address = \{address};\n")
  out.write_string("  wire [31:0] lc_checked_request_data = \{data};\n")
  let predicates =
    #|  wire [103:0] lc_checked_request_payload = {lc_memory_request_write,
    #|    lc_memory_request_address, lc_memory_request_bytes,
    #|    lc_memory_request_mask, lc_checked_request_data, lc_memory_request_tag};
    #|  // Full-width unsigned end-exclusive arithmetic; cannot wrap at 32 bits.
    #|  wire [33:0] lc_checked_request_end = {1'b0, lc_checked_request_address}
    #|    + {31'd0, lc_memory_request_bytes};
    #|  wire lc_initial_joint_reset = lc_seen_edge || lc_reset;
    #|  wire lc_host_config_stable_until_accept = lc_reset || !lc_previous_config_hold
    #|    || (lc_config_valid && lc_config_payload == lc_previous_config_payload);
    #|  wire lc_host_publication_stable_until_accept = lc_reset || !lc_previous_publication_hold
    #|    || (lc_publish_valid && lc_publish_producer == lc_previous_publication_payload);
    #|  wire lc_host_response_stable_until_accept = lc_reset || !lc_previous_response_hold
    #|    || (lc_memory_response_valid && lc_response_payload == lc_previous_response_payload);
    #|  // Joint reset flushes the external peer as required by the published ABI.
    #|  // Tag/status/data otherwise remain symbolic, including malformed responses.
    #|  wire lc_host_response_flushed_during_reset = !lc_reset || !lc_memory_response_valid;
    #|  wire lc_transport_request_address_in_aperture = lc_reset || !lc_memory_request_valid
    #|    || (lc_checked_request_end <= 34'd1024);
    #|  wire lc_transport_request_payload_legal = lc_reset || !lc_memory_request_valid
    #|    || (lc_memory_request_write
    #|      ? (lc_memory_request_bytes == 3'd4 && lc_memory_request_mask == 4'd15
    #|         && lc_memory_request_address[1:0] == 2'd0)
    #|      : (lc_memory_request_bytes == 3'd1 && lc_memory_request_mask == 4'd1
    #|         && lc_memory_request_data == 32'd0));
    #|  // Check valid remains high and payload unchanged even on the release edge.
    #|  wire lc_transport_request_stable_until_accept = lc_reset || !lc_previous_request_hold
    #|    || (lc_memory_request_valid && lc_checked_request_payload == lc_previous_request_payload);
    #|  wire lc_command_completion_stable_until_accept = lc_reset || !lc_previous_completion_hold
    #|    || (lc_completion_valid && lc_completion_payload == lc_previous_completion_payload);
    #|  wire lc_transport_at_most_one_outstanding = lc_reset || !lc_request_accept || !lc_owned;
    #|  wire lc_transport_response_has_owner = lc_reset || !lc_memory_response_ready || lc_owned;
    #|  wire lc_transport_no_response_edge_request = lc_reset || !(lc_request_accept && lc_response_accept);
    #|  wire lc_joint_reset_suppresses_public_transfers = !lc_reset
    #|    || !(lc_config_ready || lc_publish_ready || lc_memory_request_valid
    #|         || lc_memory_response_ready || lc_completion_valid);
    #|  wire lc_reachable_held_request = !lc_reset && lc_memory_request_valid && !lc_memory_request_ready;
    #|  wire lc_reachable_owned_response = !lc_reset && lc_owned && lc_response_accept;
    #|  wire lc_reachable_first_command_terminal = !lc_reset && lc_completion_valid;
    #|
  out.write_string(predicates)
  out.write_string(property_source)
  out.write_string("endmodule\n`default_nettype wire\n")
  out.to_string()
}
