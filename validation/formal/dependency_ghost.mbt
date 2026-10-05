///|
// Six independent intended generations, not a mirror of DUT dependency-ready.
// Raw head values are the agreed observation boundary; FIFO atomicity is not
// inferred. Tickets are independently counted at actual head reservation.
fn dependency_ghost_source() -> String {
  let source =
    #|  // Ghost engine ownership comes from actual outer accept events, never
    #|  // caller IDs, inferred ready, or a DUT dependency-ready predicate.
    #|  logic lc_g_load_owned = 1'b0;
    #|  logic lc_g_compute_owned = 1'b0;
    #|  logic lc_g_store_owned = 1'b0;
    #|  logic [31:0] lc_g_load_ticket = 32'd0;
    #|  logic [31:0] lc_g_compute_ticket = 32'd0;
    #|  logic [31:0] lc_g_store_ticket = 32'd0;
    #|  logic lc_g_authorized = 1'b0;
    #|  logic [31:0] lc_g_authorized_ticket = 32'd0;
    #|  logic lc_g_authorized_a = 1'b0;
    #|  logic lc_g_authorized_b = 1'b0;
    #|  logic lc_g_authorized_c = 1'b0;
    #|  logic [12:0] lc_g_authorized_rows = 13'd0;
    #|  logic [12:0] lc_g_authorized_columns = 13'd0;
    #|  logic [12:0] lc_g_authorized_reduction = 13'd0;
    #|  always_ff @(posedge lc_clock) begin
    #|    if (lc_reset) begin
    #|      lc_g_load_owned <= 1'b0;
    #|      lc_g_compute_owned <= 1'b0;
    #|      lc_g_store_owned <= 1'b0;
    #|      lc_g_load_ticket <= 32'd0;
    #|      lc_g_compute_ticket <= 32'd0;
    #|      lc_g_store_ticket <= 32'd0;
    #|      lc_g_authorized <= 1'b0;
    #|      lc_g_authorized_ticket <= 32'd0;
    #|      lc_g_authorized_a <= 1'b0;
    #|      lc_g_authorized_b <= 1'b0;
    #|      lc_g_authorized_c <= 1'b0;
    #|      lc_g_authorized_rows <= 13'd0;
    #|      lc_g_authorized_columns <= 13'd0;
    #|      lc_g_authorized_reduction <= 13'd0;
    #|    end else begin
    #|      if (lc_o_load_terminal) lc_g_load_owned <= 1'b0;
    #|      if (lc_o_compute_terminal) lc_g_compute_owned <= 1'b0;
    #|      if (lc_o_store_terminal) lc_g_store_owned <= 1'b0;
    #|      if (lc_o_load_accept) begin
    #|        lc_g_load_owned <= 1'b1;
    #|        lc_g_load_ticket <= lc_g_head;
    #|      end
    #|      if (lc_o_store_accept) begin
    #|        lc_g_store_owned <= 1'b1;
    #|        lc_g_store_ticket <= lc_g_head;
    #|      end
    #|      if (lc_inner_accept || lc_o_compute_terminal) lc_g_authorized <= 1'b0;
    #|      if (lc_o_compute_accept) begin
    #|        lc_g_compute_owned <= 1'b1;
    #|        lc_g_compute_ticket <= lc_g_head;
    #|        // Legitimate preflight failure may accept into a terminal, but must
    #|        // never authorize inner hardware issue. Save authorized raw shape.
    #|        lc_g_authorized <= lc_priority_eligible && lc_raw_is_mat
    #|          && lc_g_sources_good && lc_o_compute_preflight == 4'd0;
    #|        lc_g_authorized_ticket <= lc_g_head;
    #|        lc_g_authorized_a <= lc_raw_a;
    #|        lc_g_authorized_b <= lc_raw_b;
    #|        lc_g_authorized_c <= lc_raw_c;
    #|        lc_g_authorized_rows <= lc_raw_rows[12:0];
    #|        lc_g_authorized_columns <= lc_raw_columns[12:0];
    #|        lc_g_authorized_reduction <= lc_raw_reduction[12:0];
    #|      end
    #|    end
    #|  end
    #|
  dependency_generation_reference_source() + source
}
