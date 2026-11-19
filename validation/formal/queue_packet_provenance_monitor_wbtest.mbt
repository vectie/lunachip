///|
test "packet provenance sensitivity changes only one response comparison" {
  let positive = queue_packet_provenance_source(false)
  let negative = queue_packet_provenance_source(true)
  let original = "wire [255:0] lc_pp_checked_response_packet = lc_pp_saved_packet;"
  let changed = "wire [255:0] lc_pp_checked_response_packet = (lc_pp_saved_packet ^ (lc_pp_genuine_response ? (256'd1 << 128) : 256'd0));"
  assert_true(positive.contains(original))
  assert_true(negative.contains(changed))
  assert_eq(negative.replace(old=changed, new=original), positive)
  assert_true(
    positive.contains(
      "lc_pp_all_response && lc_o_head_capture && lc_pp_raw_response",
    ),
  )
  assert_false(positive.contains("assume ("))
  assert_false(negative.contains("assume ("))
}

///|
test "packet provenance saves public lanes and both independent same-edge ranks" {
  let source = queue_packet_provenance_source(false)
  for
    fragment in [
      "(* anyseq *) logic lc_pp_select;", "!lc_pp_taken && lc_pp_select && lc_queue_admit",
      "lc_pp_saved_packet <= lc_descriptor_payload;", "lc_pp_fifo_older <= lc_pp_fifo_count - (lc_o_head_pop ? 4'd1 : 4'd0);",
      "lc_pp_retire_older <= lc_pp_outstanding - (lc_queue_retire ? 4'd1 : 4'd0);",
      "(!lc_queue_retire || lc_pp_outstanding != 4'd0)", "(!lc_o_head_pop || lc_pp_fifo_count != 4'd0)",
      "if (lc_pp_counts_ok) begin", "lc_pp_outstanding <= lc_pp_outstanding;", "lc_pp_fifo_count <= lc_pp_fifo_count;",
      "if (!lc_pp_current_ok) lc_pp_failed <= 1'b1;", "lc_reset || (!lc_pp_failed && lc_pp_current_ok)",
    ] {
    assert_true(source.contains(fragment))
  }
  assert_false(source.contains("lc_pp_fifo_count <= lc_o_fifo_occupancy"))
  assert_false(source.contains("lc_pp_saved_packet <= lc_pp_head_packet"))
  assert_eq(source.split("lc_pp_taken <= 1'b0;").count(), 2)
  assert_eq(source.split("lc_pp_taken <= 1'b1;").count(), 2)
}

///|
test "packet provenance checks the response head reservation and ordinal ACK" {
  let source = queue_packet_provenance_source(false)
  for lane in 0..<4 {
    assert_true(source.contains("lc_o_fifo_response_data_\{lane}"))
    assert_true(source.contains("lc_o_fifo_response_valid_\{lane}"))
    assert_true(source.contains("lc_o_head_lane_\{lane}"))
  }
  for
    fragment in [
      "lc_pp_stage != 3'd2", "lc_o_head_capture && lc_o_head_state == 2'd1", "lc_pp_response_packet == lc_pp_checked_response_packet",
      "lc_pp_head_packet == lc_pp_saved_packet", "lc_o_head_entry == lc_pp_saved_entry",
      "lc_o_head_ticket == lc_pp_saved_ticket", "lc_pp_saved_entry <= lc_o_retirement_write_pointer;",
      "lc_pp_saved_ticket <= lc_o_next_ticket;", "lc_pp_entry_id == lc_pp_saved_packet[63:32]",
      "lc_pp_entry_ticket == lc_pp_saved_ticket", "lc_pp_active && lc_pp_retire_older == 4'd0",
      "lc_pp_stage == 3'd4 && lc_pp_response_seen && lc_pp_capture_seen", "lc_pp_reservation_seen && lc_pp_entry_matches && lc_pp_entry_terminal",
      "lc_o_retirement_read_pointer == lc_pp_saved_entry && lc_pp_entry_ack", "if (lc_pp_head_owned && lc_o_head_finish) lc_pp_head_owned <= 1'b0;",
      "wire lc_packet_provenance_transfer_cover = !lc_reset && !lc_pp_failed", "&& lc_pp_current_ok && lc_pp_ordinal_retire && lc_pp_stage == 3'd4",
    ] {
    assert_true(source.contains(fragment))
  }
}
