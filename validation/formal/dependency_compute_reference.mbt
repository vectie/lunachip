///|
// Exact fragments from the full dependency ghost, including its initialization,
// reset and same-edge clear-before-accept order. These functions add no model
// controller, fault rule, assertion or assumption.
fn dependency_compute_owner_declaration_source() -> String {
  (
    #|  logic lc_g_compute_owned = 1'b0;
    #|
  )
}

///|
fn dependency_compute_ticket_declaration_source() -> String {
  (
    #|  logic [31:0] lc_g_compute_ticket = 32'd0;
    #|
  )
}

///|
fn dependency_compute_authorization_declaration_source() -> String {
  (
    #|  logic lc_g_authorized = 1'b0;
    #|  logic [31:0] lc_g_authorized_ticket = 32'd0;
    #|  logic lc_g_authorized_a = 1'b0;
    #|  logic lc_g_authorized_b = 1'b0;
    #|  logic lc_g_authorized_c = 1'b0;
    #|  logic [12:0] lc_g_authorized_rows = 13'd0;
    #|  logic [12:0] lc_g_authorized_columns = 13'd0;
    #|  logic [12:0] lc_g_authorized_reduction = 13'd0;
    #|
  )
}

///|
fn dependency_compute_owner_reset_source() -> String {
  (
    #|      lc_g_compute_owned <= 1'b0;
    #|
  )
}

///|
fn dependency_compute_ticket_reset_source() -> String {
  (
    #|      lc_g_compute_ticket <= 32'd0;
    #|
  )
}

///|
fn dependency_compute_authorization_reset_source() -> String {
  (
    #|      lc_g_authorized <= 1'b0;
    #|      lc_g_authorized_ticket <= 32'd0;
    #|      lc_g_authorized_a <= 1'b0;
    #|      lc_g_authorized_b <= 1'b0;
    #|      lc_g_authorized_c <= 1'b0;
    #|      lc_g_authorized_rows <= 13'd0;
    #|      lc_g_authorized_columns <= 13'd0;
    #|      lc_g_authorized_reduction <= 13'd0;
    #|
  )
}

///|
fn dependency_compute_terminal_clear_source() -> String {
  (
    #|      if (lc_o_compute_terminal) lc_g_compute_owned <= 1'b0;
    #|
  )
}

///|
fn dependency_compute_authorization_clear_source() -> String {
  (
    #|      if (lc_inner_accept || lc_o_compute_terminal) lc_g_authorized <= 1'b0;
    #|
  )
}

///|
fn dependency_compute_accept_update_source() -> String {
  (
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
    #|
  )
}

///|
// Compute owner plus saved authorization is exactly 108 bits. The caller
// supplies unchanged lc_o_*/lc_raw_*/lc_g_* boundary/reference names; actual
// outer acceptance captures authorization, and no authorization is assumed.
fn dependency_compute_reference_source() -> String {
  let out = StringBuilder()
  out.write_string(
    (
      #|  // Ghost engine ownership comes from actual outer accept events, never
      #|  // caller IDs, inferred ready, or a DUT dependency-ready predicate.
      #|
    ),
  )
  out.write_string(dependency_compute_owner_declaration_source())
  out.write_string(dependency_compute_ticket_declaration_source())
  out.write_string(dependency_compute_authorization_declaration_source())
  out.write_string(
    "  always_ff @(posedge lc_clock) begin\n    if (lc_reset) begin\n",
  )
  out.write_string(dependency_compute_owner_reset_source())
  out.write_string(dependency_compute_ticket_reset_source())
  out.write_string(dependency_compute_authorization_reset_source())
  out.write_string("    end else begin\n")
  out.write_string(dependency_compute_terminal_clear_source())
  out.write_string(dependency_compute_authorization_clear_source())
  out.write_string(dependency_compute_accept_update_source())
  out.write_string("    end\n  end\n")
  out.to_string()
}

///|
// Reuse the original generation reference; omit only load/store ownership
// bookkeeping from the full ghost. This source does not establish a proof.
fn dependency_generation_compute_reference_source() -> String {
  dependency_generation_reference_source() +
  dependency_compute_reference_source()
}
