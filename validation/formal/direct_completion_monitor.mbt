///|
// A public ordinal watch. The saved packet determines only diagnostics/covers
// and the isolated negative gate; neither caller IDs nor tickets select it.
fn direct_completion_monitor_source(
  negative : Bool,
) -> String raise FormalGateError {
  direct_completion_monitor_with_parameters(negative, {
    load_literal: direct_completion_packet_literal(0),
    store_literal: direct_completion_packet_literal(3),
    age_width: 8,
    deadline: direct_completion_deadline(),
    age_max: 255,
  })
}

///|
priv struct DirectCompletionMonitorParameters {
  load_literal : String
  store_literal : String
  age_width : Int
  deadline : Int
  age_max : Int
}

///|
// Only packet literals and sized age/deadline constants vary between scopes.
// Public predicates, ordinal bookkeeping, premises and PRE sampling do not.
fn direct_completion_monitor_with_parameters(
  negative : Bool,
  parameters : DirectCompletionMonitorParameters,
) -> String {
  let width = parameters.age_width
  let high_bit = width - 1
  let deadline = parameters.deadline
  let age_max = parameters.age_max
  let out = StringBuilder()
  out.write_string(
    "  localparam [255:0] LC_DC_LOAD_A = " + parameters.load_literal + ";\n",
  )
  out.write_string(
    "  localparam [255:0] LC_DC_STORE = " + parameters.store_literal + ";\n",
  )
  let declarations =
    $|  (* anyseq *) logic lc_dc_select;
    $|  logic [5:0] lc_dc_post_reset_edges = 6'd0;
    $|  logic [3:0] lc_dc_outstanding = 4'd0;
    $|  logic lc_dc_count_failed = 1'b0;
    $|  logic lc_dc_taken = 1'b0;
    $|  logic lc_dc_active = 1'b0;
    $|  logic lc_dc_retired = 1'b0;
    $|  logic [3:0] lc_dc_older = 4'd0;
    $|  logic [\{high_bit}:0] lc_dc_age = \{width}'d0;
    $|  logic [255:0] lc_dc_saved_packet = 256'd0;
    $|  wire lc_dc_count_step_ok = lc_dc_outstanding <= 4'd7
    $|    && (!lc_dc_retire || lc_dc_outstanding != 4'd0)
    $|    && (!lc_dc_admit || lc_dc_retire || lc_dc_outstanding < 4'd7);
    $|  wire lc_dc_watch = !lc_reset && !lc_dc_taken && lc_dc_select
    $|    && lc_dc_post_reset_edges < 6'd32 && lc_dc_admit;
    $|  wire lc_dc_ordinal_retire = lc_dc_active && lc_dc_older == 4'd0 && lc_dc_retire;
    $|  wire lc_dc_ordinal_terminal = !lc_reset && lc_dc_active
    $|    && lc_dc_older == 4'd0 && lc_completion_valid;
    $|  wire lc_dc_ordinal_history = lc_reset || (!lc_dc_count_failed && lc_dc_count_step_ok
    $|    && (!lc_dc_active || lc_dc_older < lc_dc_outstanding)
    $|    && (!lc_dc_ordinal_terminal || lc_completion_id == lc_dc_saved_packet[63:32]));
    $|  always_ff @(posedge lc_clock) begin
    $|    if (lc_reset) begin
    $|      lc_dc_post_reset_edges <= 6'd0;
    $|      lc_dc_outstanding <= 4'd0;
    $|      lc_dc_count_failed <= 1'b0;
    $|      lc_dc_taken <= 1'b0;
    $|      lc_dc_active <= 1'b0;
    $|      lc_dc_retired <= 1'b0;
    $|      lc_dc_older <= 4'd0;
    $|      lc_dc_age <= \{width}'d0;
    $|      lc_dc_saved_packet <= 256'd0;
    $|    end else begin
    $|      if (lc_dc_post_reset_edges < 6'd33)
    $|        lc_dc_post_reset_edges <= lc_dc_post_reset_edges + 6'd1;
    $|      if (!lc_dc_count_step_ok) lc_dc_count_failed <= 1'b1;
    $|      // Impossible arithmetic holds and fails a conclusion, never wraps.
    $|      if (lc_dc_count_step_ok) begin
    $|        case ({lc_dc_admit, lc_dc_retire})
    $|          2'b10: lc_dc_outstanding <= lc_dc_outstanding + 4'd1;
    $|          2'b01: lc_dc_outstanding <= lc_dc_outstanding - 4'd1;
    $|          default: lc_dc_outstanding <= lc_dc_outstanding;
    $|        endcase
    $|      end
    $|      if (lc_dc_watch) begin
    $|        lc_dc_taken <= 1'b1;
    $|        lc_dc_active <= 1'b1;
    $|        lc_dc_saved_packet <= lc_dc_packet;
    $|        lc_dc_age <= \{width}'d1;
    $|        if (lc_dc_count_step_ok)
    $|          lc_dc_older <= lc_dc_outstanding - (lc_dc_retire ? 4'd1 : 4'd0);
    $|      end
    $|      if (lc_dc_active) begin
    $|        if (lc_dc_age < \{width}'d\{age_max}) lc_dc_age <= lc_dc_age + \{width}'d1;
    $|        if (lc_dc_retire) begin
    $|          if (lc_dc_older != 4'd0) lc_dc_older <= lc_dc_older - 4'd1;
    $|          else begin
    $|            lc_dc_active <= 1'b0;
    $|            lc_dc_retired <= 1'b1;
    $|          end
    $|        end
    $|      end
    $|    end
    $|  end
    $|
  out.write_string(declarations)
  let checked = if negative {
    "(lc_dc_saved_packet == LC_DC_LOAD_A ? \{width}'d1 : \{width}'d\{deadline})"
  } else {
    "\{width}'d\{deadline}"
  }
  out.write_string(
    "  wire [\{high_bit}:0] lc_dc_checked_deadline = \{checked};\n",
  )
  let predicates =
    $|  // Age1 is the first rising PRE after admission. Same-edge ACK wins at D.
    $|  wire lc_dc_watched_retirement_deadline = lc_reset || !lc_dc_active
    $|    || lc_dc_ordinal_retire || lc_dc_age < lc_dc_checked_deadline;
    $|  wire lc_dc_watched_terminal_cover = lc_dc_ordinal_terminal && lc_dc_ordinal_history
    $|    && lc_dc_age <= \{width}'d\{deadline};
    $|  wire lc_dc_watched_retirement_cover = !lc_reset && lc_dc_ordinal_retire
    $|    && lc_dc_ordinal_history && lc_dc_age <= \{width}'d\{deadline};
    $|
  out.write_string(predicates)
  out.to_string()
}
