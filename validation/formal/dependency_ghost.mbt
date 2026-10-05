///|
// Six independent intended generations, not a mirror of DUT dependency-ready.
// Raw head values are the agreed observation boundary; FIFO atomicity is not
// inferred. Tickets are independently counted at actual head reservation.
fn dependency_ghost_source() -> String {
  let out = StringBuilder()
  out.write_string(dependency_generation_reference_source())
  out.write_string(
    (
      #|  // Ghost engine ownership comes from actual outer accept events, never
      #|  // caller IDs, inferred ready, or a DUT dependency-ready predicate.
      #|  logic lc_g_load_owned = 1'b0;
      #|
    ),
  )
  out.write_string(dependency_compute_owner_declaration_source())
  out.write_string(
    (
      #|  logic lc_g_store_owned = 1'b0;
      #|  logic [31:0] lc_g_load_ticket = 32'd0;
      #|
    ),
  )
  out.write_string(dependency_compute_ticket_declaration_source())
  out.write_string(
    (
      #|  logic [31:0] lc_g_store_ticket = 32'd0;
      #|
    ),
  )
  out.write_string(dependency_compute_authorization_declaration_source())
  out.write_string(
    (
      #|  always_ff @(posedge lc_clock) begin
      #|    if (lc_reset) begin
      #|      lc_g_load_owned <= 1'b0;
      #|
    ),
  )
  out.write_string(dependency_compute_owner_reset_source())
  out.write_string(
    (
      #|      lc_g_store_owned <= 1'b0;
      #|      lc_g_load_ticket <= 32'd0;
      #|
    ),
  )
  out.write_string(dependency_compute_ticket_reset_source())
  out.write_string(
    (
      #|      lc_g_store_ticket <= 32'd0;
      #|
    ),
  )
  out.write_string(dependency_compute_authorization_reset_source())
  out.write_string(
    (
      #|    end else begin
      #|      if (lc_o_load_terminal) lc_g_load_owned <= 1'b0;
      #|
    ),
  )
  out.write_string(dependency_compute_terminal_clear_source())
  out.write_string(
    (
      #|      if (lc_o_store_terminal) lc_g_store_owned <= 1'b0;
      #|      if (lc_o_load_accept) begin
      #|        lc_g_load_owned <= 1'b1;
      #|        lc_g_load_ticket <= lc_g_head;
      #|      end
      #|      if (lc_o_store_accept) begin
      #|        lc_g_store_owned <= 1'b1;
      #|        lc_g_store_ticket <= lc_g_head;
      #|      end
      #|
    ),
  )
  out.write_string(dependency_compute_authorization_clear_source())
  out.write_string(dependency_compute_accept_update_source())
  out.write_string(
    (
      #|    end
      #|  end
      #|
    ),
  )
  out.to_string()
}
