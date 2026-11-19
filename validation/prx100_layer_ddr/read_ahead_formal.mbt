///|
fn read_ahead_properties(source : String) -> String {
  source
  .replace(
    old="p_bounded_issue: assert(obs_issued_lines<=8);",
    new="p_bounded_issue: assert(obs_issued_lines<=((obs_request[63:60]==4'b1110 && obs_request[31]) ? 32:8));",
  )
  .replace(
    old="p_bounded_words: assert(obs_sent_words<=32);",
    new="p_bounded_words: assert(obs_sent_words<=((obs_request[63:60]==4'b1110 && obs_request[31]) ? 128:32));",
  )
  .replace(
    old="\nendmodule\n",
    new=(
      #|always @(posedge ui_clock) if(f_seen_fast && !ui_reset) begin
      #|  if(app_en && obs_state==5 && obs_request[63:60]==4'b1110 && obs_request[31]) begin
      #|    p_ahead_offset: assert({1'b0,obs_read_ahead_offset}==({26'b0,obs_issued_lines[4:3]}*{1'b0,obs_request[27:1]}));
      #|  end
      #|  if($past(!ui_reset && obs_state==5 && app_en && app_rdy && obs_request[63:60]==4'b1110 && obs_request[31] && obs_issued_lines[2:0]==7)) begin
      #|    p_ahead_row_advance: assert(obs_read_ahead_offset==$past(obs_read_ahead_offset)+$past(obs_request[27:1]));
      #|  end
      #|end
      #|endmodule
      #|
    ),
  )
}
