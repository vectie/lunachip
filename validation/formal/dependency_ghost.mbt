///|
// Six independent intended generations, not a mirror of DUT dependency-ready.
// Raw head values are the agreed observation boundary; FIFO atomicity is not
// inferred. Tickets are independently counted at actual head reservation.
fn dependency_ghost_source() -> String {
  let source =
    #|  logic [1:0] lc_g_status [0:5];
    #|  logic [31:0] lc_g_ticket [0:5];
    #|  logic lc_g_had_success [0:5];
    #|  logic lc_g_failed_after_success [0:5];
    #|  logic [31:0] lc_g_next = 32'd0;
    #|  logic [31:0] lc_g_head = 32'd0;
    #|  logic [1:0] lc_g_snapshot_status [0:1];
    #|  logic [31:0] lc_g_snapshot_ticket [0:1];
    #|  wire [1:0] lc_o_status [0:5];
    #|  wire [31:0] lc_o_ticket [0:5];
    #|  assign lc_o_status[0] = lc_o_writer_status_0;
    #|  assign lc_o_status[1] = lc_o_writer_status_1;
    #|  assign lc_o_status[2] = lc_o_writer_status_2;
    #|  assign lc_o_status[3] = lc_o_writer_status_3;
    #|  assign lc_o_status[4] = lc_o_writer_status_4;
    #|  assign lc_o_status[5] = lc_o_writer_status_5;
    #|  assign lc_o_ticket[0] = lc_o_writer_ticket_0;
    #|  assign lc_o_ticket[1] = lc_o_writer_ticket_1;
    #|  assign lc_o_ticket[2] = lc_o_writer_ticket_2;
    #|  assign lc_o_ticket[3] = lc_o_writer_ticket_3;
    #|  assign lc_o_ticket[4] = lc_o_writer_ticket_4;
    #|  assign lc_o_ticket[5] = lc_o_writer_ticket_5;
    #|  wire [1:0] lc_g_resolved0 = lc_g_snapshot_status[0] == 2'd1
    #|    ? (lc_g_snapshot_ticket[0] == lc_g_ticket[lc_raw_source0]
    #|      ? lc_g_status[lc_raw_source0] : 2'd3) : lc_g_snapshot_status[0];
    #|  wire [1:0] lc_g_resolved1 = lc_g_snapshot_status[1] == 2'd1
    #|    ? (lc_g_snapshot_ticket[1] == lc_g_ticket[lc_raw_source1]
    #|      ? lc_g_status[lc_raw_source1] : 2'd3) : lc_g_snapshot_status[1];
    #|  wire lc_g_sources_good = lc_g_resolved0 == 2'd2 && lc_g_resolved1 == 2'd2;
    #|  wire lc_g_source0_bad = lc_g_resolved0 == 2'd0 || lc_g_resolved0 == 2'd3;
    #|  wire lc_g_source1_bad = lc_g_resolved1 == 2'd0 || lc_g_resolved1 == 2'd3;
    #|  wire lc_g_dependency_bad = lc_raw_is_mat ? (lc_g_source0_bad || lc_g_source1_bad)
    #|    : lc_raw_is_store && lc_g_source0_bad;
    #|  wire [3:0] lc_g_expected_local_fault = lc_halted ? 4'd15
    #|    : !lc_raw_syntax_ok ? lc_raw_syntax_fault : !lc_raw_unused_ok ? 4'd2
    #|    : !lc_raw_dimensions_ok ? 4'd3 : lc_g_dependency_bad
    #|      ? (lc_raw_is_mat ? 4'd4 : 4'd5) : 4'd0;
    #|  wire lc_g_expected_reject = lc_dispatch_active && lc_g_expected_local_fault != 4'd0;
    #|  wire [5:0] lc_g_collect;
    #|  wire [5:0] lc_g_local_fail;
    #|  wire [5:0] lc_g_intent;
    #|  genvar lc_slot;
    #|  generate for (lc_slot = 0; lc_slot < 6; lc_slot = lc_slot + 1) begin: lc_generation
    #|    wire terminal = lc_slot < 4 ? lc_o_load_terminal : lc_o_compute_terminal;
    #|    wire [31:0] terminal_ticket = lc_slot < 4 ? lc_o_load_terminal_ticket : lc_o_compute_terminal_ticket;
    #|    wire [3:0] terminal_fault = lc_slot < 4 ? lc_o_load_terminal_fault : lc_o_compute_terminal_fault;
    #|    assign lc_g_collect[lc_slot] = lc_g_status[lc_slot] == 2'd1
    #|      && terminal && terminal_ticket == lc_g_ticket[lc_slot];
    #|    assign lc_g_local_fail[lc_slot] = lc_g_status[lc_slot] == 2'd1
    #|      && lc_g_expected_reject && lc_raw_syntax_ok && lc_raw_is_writer
    #|      && lc_raw_writer_slot == lc_slot && lc_g_ticket[lc_slot] == lc_g_head;
    #|    assign lc_g_intent[lc_slot] = lc_new_intent && lc_raw_writer_slot == lc_slot;
    #|    always_ff @(posedge lc_clock) begin
    #|      if (lc_reset) begin
    #|        lc_g_status[lc_slot] <= 2'd0;
    #|        lc_g_ticket[lc_slot] <= 32'd0;
    #|        lc_g_had_success[lc_slot] <= 1'b0;
    #|        lc_g_failed_after_success[lc_slot] <= 1'b0;
    #|      end else begin
    #|        // Collect only matching Pending tickets. Syntax rejection itself
    #|        // publishes no intent, but must not freeze an older valid terminal.
    #|        if (lc_g_collect[lc_slot]) begin
    #|          lc_g_status[lc_slot] <= terminal_fault == 4'd0 ? 2'd2 : 2'd3;
    #|          if (terminal_fault == 4'd0) lc_g_had_success[lc_slot] <= 1'b1;
    #|          else lc_g_failed_after_success[lc_slot] <= lc_g_had_success[lc_slot];
    #|        end
    #|        if (lc_g_local_fail[lc_slot]) begin
    #|          lc_g_status[lc_slot] <= 2'd3;
    #|          lc_g_failed_after_success[lc_slot] <= lc_g_had_success[lc_slot];
    #|        end
    #|        // Raw-syntax-valid new intent wins simultaneous older collection.
    #|        if (lc_g_intent[lc_slot]) begin
    #|          lc_g_status[lc_slot] <= 2'd1;
    #|          lc_g_ticket[lc_slot] <= lc_g_next;
    #|          lc_g_failed_after_success[lc_slot] <= 1'b0;
    #|        end
    #|      end
    #|    end
    #|  end endgenerate
    #|
    #|  logic lc_priority_check = 1'b0;
    #|  logic [2:0] lc_priority_slot = 3'd0;
    #|  logic [31:0] lc_priority_ticket = 32'd0;
    #|  logic [31:0] lc_priority_old_ticket = 32'd0;
    #|  logic lc_bad_syntax_prior = 1'b0;
    #|  logic [2:0] lc_bad_syntax_slot = 3'd0;
    #|  logic [31:0] lc_bad_syntax_ticket = 32'd0;
    #|  always_ff @(posedge lc_clock) begin
    #|    if (lc_reset) begin
    #|      lc_g_next <= 32'd0;
    #|      lc_g_head <= 32'd0;
    #|      lc_g_snapshot_status[0] <= 2'd0;
    #|      lc_g_snapshot_status[1] <= 2'd0;
    #|      lc_g_snapshot_ticket[0] <= 32'd0;
    #|      lc_g_snapshot_ticket[1] <= 32'd0;
    #|      lc_priority_check <= 1'b0;
    #|      lc_priority_slot <= 3'd0;
    #|      lc_priority_ticket <= 32'd0;
    #|      lc_priority_old_ticket <= 32'd0;
    #|      lc_bad_syntax_prior <= 1'b0;
    #|      lc_bad_syntax_slot <= 3'd0;
    #|      lc_bad_syntax_ticket <= 32'd0;
    #|    end else begin
    #|      lc_priority_check <= lc_new_intent && lc_g_collect[lc_raw_writer_slot];
    #|      if (lc_reservation) begin
    #|        lc_g_head <= lc_g_next;
    #|        lc_g_next <= lc_g_next + 32'd1;
    #|        // Every RHS is old ghost state: snapshot before publication/collect.
    #|        lc_g_snapshot_status[0] <= lc_g_status[lc_raw_source0];
    #|        lc_g_snapshot_status[1] <= lc_g_status[lc_raw_source1];
    #|        lc_g_snapshot_ticket[0] <= lc_g_ticket[lc_raw_source0];
    #|        lc_g_snapshot_ticket[1] <= lc_g_ticket[lc_raw_source1];
    #|        if (!lc_raw_syntax_ok && lc_raw_is_writer
    #|          && lc_g_status[lc_raw_writer_slot] == 2'd2) begin
    #|          lc_bad_syntax_prior <= 1'b1;
    #|          lc_bad_syntax_slot <= lc_raw_writer_slot;
    #|          lc_bad_syntax_ticket <= lc_g_ticket[lc_raw_writer_slot];
    #|        end
    #|      end
    #|      if (lc_new_intent && lc_g_collect[lc_raw_writer_slot]) begin
    #|        lc_priority_slot <= lc_raw_writer_slot;
    #|        lc_priority_ticket <= lc_g_next;
    #|        lc_priority_old_ticket <= lc_g_ticket[lc_raw_writer_slot];
    #|      end
    #|    end
    #|  end
    #|
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
  source
}
