///|
// Shared independent predicates. These read only ghost PRE values and raw
// decoder/boundary values, never DUT syntax, dependency-ready or rejection.
// The generate block is closed by the sequential or combinational caller.
fn dependency_generation_predicates_source() -> String {
  (
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
    #|
  )
}

///|
fn dependency_generation_writer_reset_source(
  post : String,
  op : String,
  history : Bool,
) -> String {
  let assignments =
    $|        \{post}status[lc_slot] \{op} 2'd0;
    $|        \{post}ticket[lc_slot] \{op} 32'd0;
    $|
  let history_source = if history {
    (
      #|        lc_g_had_success[lc_slot] <= 1'b0;
      #|        lc_g_failed_after_success[lc_slot] <= 1'b0;
      #|
    )
  } else {
    ""
  }
  assignments + history_source
}

///|
fn dependency_generation_writer_update_source(
  pre : String,
  post : String,
  op : String,
  history : Bool,
) -> String {
  let collect =
    $|        // Collect only matching Pending tickets. Syntax rejection itself
    $|        // publishes no intent, but must not freeze an older valid terminal.
    $|        if (lc_g_collect[lc_slot]) begin
    $|          \{post}status[lc_slot] \{op} terminal_fault == 4'd0 ? 2'd2 : 2'd3;
    $|
  let collected_history = if history {
    (
      $|          if (terminal_fault == 4'd0) lc_g_had_success[lc_slot] <= 1'b1;
      $|          else lc_g_failed_after_success[lc_slot] <= \{pre}had_success[lc_slot];
      $|
    )
  } else {
    ""
  }
  let reject =
    $|        end
    $|        if (lc_g_local_fail[lc_slot]) begin
    $|          \{post}status[lc_slot] \{op} 2'd3;
    $|
  let rejected_history = if history {
    (
      $|          lc_g_failed_after_success[lc_slot] <= \{pre}had_success[lc_slot];
      $|
    )
  } else {
    ""
  }
  let intent =
    $|        end
    $|        // Raw-syntax-valid new intent wins simultaneous older collection.
    $|        if (lc_g_intent[lc_slot]) begin
    $|          \{post}status[lc_slot] \{op} 2'd1;
    $|          \{post}ticket[lc_slot] \{op} \{pre}next;
    $|
  let intended_history = if history {
    (
      #|          lc_g_failed_after_success[lc_slot] <= 1'b0;
      #|
    )
  } else {
    ""
  }
  collect +
  collected_history +
  reject +
  rejected_history +
  intent +
  intended_history +
  "        end\n"
}

///|
fn dependency_generation_snapshot_reset_source(
  post : String,
  op : String,
  history : Bool,
) -> String {
  let assignments =
    $|      \{post}next \{op} 32'd0;
    $|      \{post}head \{op} 32'd0;
    $|      \{post}snapshot_status[0] \{op} 2'd0;
    $|      \{post}snapshot_status[1] \{op} 2'd0;
    $|      \{post}snapshot_ticket[0] \{op} 32'd0;
    $|      \{post}snapshot_ticket[1] \{op} 32'd0;
    $|
  let history_source = if history {
    (
      #|      lc_priority_check <= 1'b0;
      #|      lc_priority_slot <= 3'd0;
      #|      lc_priority_ticket <= 32'd0;
      #|      lc_priority_old_ticket <= 32'd0;
      #|      lc_bad_syntax_prior <= 1'b0;
      #|      lc_bad_syntax_slot <= 3'd0;
      #|      lc_bad_syntax_ticket <= 32'd0;
      #|
    )
  } else {
    ""
  }
  assignments + history_source
}

///|
fn dependency_generation_snapshot_update_source(
  pre : String,
  post : String,
  op : String,
  history : Bool,
) -> String {
  let priority = if history {
    "      lc_priority_check <= lc_new_intent && lc_g_collect[lc_raw_writer_slot];\n"
  } else {
    ""
  }
  let assignments =
    $|      if (lc_reservation) begin
    $|        \{post}head \{op} \{pre}next;
    $|        \{post}next \{op} \{pre}next + 32'd1;
    $|        // Every RHS is old ghost state: snapshot before publication/collect.
    $|        \{post}snapshot_status[0] \{op} \{pre}status[lc_raw_source0];
    $|        \{post}snapshot_status[1] \{op} \{pre}status[lc_raw_source1];
    $|        \{post}snapshot_ticket[0] \{op} \{pre}ticket[lc_raw_source0];
    $|        \{post}snapshot_ticket[1] \{op} \{pre}ticket[lc_raw_source1];
    $|
  let bad_syntax = if history {
    (
      $|        if (!lc_raw_syntax_ok && lc_raw_is_writer
      $|          && \{pre}status[lc_raw_writer_slot] == 2'd2) begin
      $|          lc_bad_syntax_prior <= 1'b1;
      $|          lc_bad_syntax_slot <= lc_raw_writer_slot;
      $|          lc_bad_syntax_ticket <= \{pre}ticket[lc_raw_writer_slot];
      $|        end
      $|
    )
  } else {
    ""
  }
  let collected_priority = if history {
    (
      $|      if (lc_new_intent && lc_g_collect[lc_raw_writer_slot]) begin
      $|        lc_priority_slot <= lc_raw_writer_slot;
      $|        lc_priority_ticket <= \{pre}next;
      $|        lc_priority_old_ticket <= \{pre}ticket[lc_raw_writer_slot];
      $|      end
      $|
    )
  } else {
    ""
  }
  priority + assignments + bad_syntax + "      end\n" + collected_priority
}

///|
// Original sequential prefix, including nonfeeding cover history, with byte
// identity retained. This is not itself a free-prestate combinational model.
fn dependency_generation_reference_source() -> String {
  let declarations =
    #|  // Reference state is a fixed bank of registers, not inferred SRAM.
    #|  (* mem2reg *) logic [1:0] lc_g_status [0:5];
    #|  (* mem2reg *) logic [31:0] lc_g_ticket [0:5];
    #|  (* mem2reg *) logic lc_g_had_success [0:5];
    #|  (* mem2reg *) logic lc_g_failed_after_success [0:5];
    #|  logic [31:0] lc_g_next = 32'd0;
    #|  logic [31:0] lc_g_head = 32'd0;
    #|  (* mem2reg *) logic [1:0] lc_g_snapshot_status [0:1];
    #|  (* mem2reg *) logic [31:0] lc_g_snapshot_ticket [0:1];
    #|  (* mem2reg *) wire [1:0] lc_o_status [0:5];
    #|  (* mem2reg *) wire [31:0] lc_o_ticket [0:5];
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
    #|
  let history =
    #|  logic lc_priority_check = 1'b0;
    #|  logic [2:0] lc_priority_slot = 3'd0;
    #|  logic [31:0] lc_priority_ticket = 32'd0;
    #|  logic [31:0] lc_priority_old_ticket = 32'd0;
    #|  logic lc_bad_syntax_prior = 1'b0;
    #|  logic [2:0] lc_bad_syntax_slot = 3'd0;
    #|  logic [31:0] lc_bad_syntax_ticket = 32'd0;
    #|
  declarations +
  dependency_generation_predicates_source() +
  "    always_ff @(posedge lc_clock) begin\n      if (lc_reset) begin\n" +
  dependency_generation_writer_reset_source("lc_g_", "<=", true) +
  "      end else begin\n" +
  dependency_generation_writer_update_source("lc_g_", "lc_g_", "<=", true) +
  "      end\n    end\n  end endgenerate\n\n" +
  history +
  "  always_ff @(posedge lc_clock) begin\n    if (lc_reset) begin\n" +
  dependency_generation_snapshot_reset_source("lc_g_", "<=", true) +
  "    end else begin\n" +
  dependency_generation_snapshot_update_source("lc_g_", "lc_g_", "<=", true) +
  "    end\n  end\n\n"
}

///|
// Caller supplies every lc_g_* PRE wire freely, raw decoded/boundary wires,
// lc_reset and lc_halted bound to raw poison (not the public reset-gated alias).
// POST holds are initialized before writes; all predicates/RHS stay PRE. No
// owner/history state, initialization, clock, assumptions or proof is emitted.
fn dependency_generation_comb_reference_source() -> String {
  let declarations =
    #|  (* mem2reg *) logic [1:0] lc_g_post_status [0:5];
    #|  (* mem2reg *) logic [31:0] lc_g_post_ticket [0:5];
    #|  logic [31:0] lc_g_post_next;
    #|  logic [31:0] lc_g_post_head;
    #|  (* mem2reg *) logic [1:0] lc_g_post_snapshot_status [0:1];
    #|  (* mem2reg *) logic [31:0] lc_g_post_snapshot_ticket [0:1];
    #|
  let writer_hold =
    #|    always_comb begin
    #|      lc_g_post_status[lc_slot] = lc_g_status[lc_slot];
    #|      lc_g_post_ticket[lc_slot] = lc_g_ticket[lc_slot];
    #|      if (lc_reset) begin
    #|
  let snapshot_hold =
    #|  always_comb begin
    #|    lc_g_post_next = lc_g_next;
    #|    lc_g_post_head = lc_g_head;
    #|    lc_g_post_snapshot_status[0] = lc_g_snapshot_status[0];
    #|    lc_g_post_snapshot_status[1] = lc_g_snapshot_status[1];
    #|    lc_g_post_snapshot_ticket[0] = lc_g_snapshot_ticket[0];
    #|    lc_g_post_snapshot_ticket[1] = lc_g_snapshot_ticket[1];
    #|    if (lc_reset) begin
    #|
  declarations +
  dependency_generation_predicates_source() +
  writer_hold +
  dependency_generation_writer_reset_source("lc_g_post_", "=", false) +
  "      end else begin\n" +
  dependency_generation_writer_update_source("lc_g_", "lc_g_post_", "=", false) +
  "      end\n    end\n  end endgenerate\n\n" +
  snapshot_hold +
  dependency_generation_snapshot_reset_source("lc_g_post_", "=", false) +
  "    end else begin\n" +
  dependency_generation_snapshot_update_source(
    "lc_g_", "lc_g_post_", "=", false,
  ) +
  "    end\n  end\n\n"
}
