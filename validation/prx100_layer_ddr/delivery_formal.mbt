///|
// Specialize complete sixteen-row properties to eight-word packetization.
// Preserve every original assertion, add pair availability, and expand the
// actual-node join checks to all sixteen CDC FIFO instances.
fn delivery_properties(source : String) -> String raise {
  let mut result = source
  for
    (old, new) in [
      ("f_beat<=f_beat+(f_wide ? 4:1);", "f_beat<=f_beat+(f_wide ? 8:1);"),
      ("f_batch ? 508:(f_wide ? 28:", "f_batch ? 504:(f_wide ? 24:"),
      (
        "{response_data1,response_data2,response_data3}", "{response_data1,response_data2,response_data3,response_data4,response_data5,response_data6,response_data7}",
      ),
    ] {
    assert_true(result.contains(old), msg=old)
    result = result.replace_all(old~, new~)
  }
  let marker = "\nendmodule\n"
  assert_eq(result.split(marker).count(), 2)
  result.replace(
    old=marker,
    new="\nalways @(posedge ui_clock) if(!ui_reset && obs_request[63:60]==4'b1110) begin p_delivery_pair_available: assert(!obs_pipeline_load || obs_pipeline_failed || (obs_sent_words+32'd8 <= {obs_returned_lines,2'b0})); p_delivery_word_alignment: assert(obs_sent_words[2:0]==0); end\nendmodule\n",
  )
}
