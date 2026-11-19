///|
fn wide_bridge_properties(
  source : String,
  batch~ : Bool = false,
  read_ahead~ : Bool = false,
) -> String {
  let source = if batch {
    source.replace_all(old="reg [4:0] f_beat=0;", new="reg [6:0] f_beat=0;")
  } else {
    source
  }
  let source = if batch {
    source.replace(
      old="({1'b0,obs_request[59:36],3'b0}+{22'b0,obs_line_index,3'b0})",
      new=if read_ahead {
        "({1'b0,obs_request[59:36],3'b0}+{20'b0,obs_line_index,3'b0}+((obs_request[63:60]==4'b1110 && obs_request[31]) ? ({26'b0,obs_issued_lines[4:3]}*{1'b0,obs_request[27:1]}):28'b0))"
      } else {
        "({1'b0,obs_request[59:36],3'b0}+{20'b0,obs_line_index,3'b0}+((obs_request[63:60]==4'b1110 && obs_request[31]) ? ({26'b0,obs_batch_row}*{1'b0,obs_request[27:1]}):28'b0))"
      },
    ) +
    (if read_ahead {
      ""
    } else {
      "\nalways @(posedge ui_clock) if(!ui_reset) begin\n" +
      "p_batch_advance: assert(!obs_advance_row || (obs_state==5 && obs_request[63:60]==4'b1110 && obs_request[31] && obs_batch_row<3 && obs_sent_words==32 && obs_pipeline_valid && obs_pipeline_ready));\n" +
      "if($past(!ui_reset && obs_advance_row)) begin p_batch_recycle: assert(obs_batch_row==$past(obs_batch_row)+1 && obs_issued_lines==0 && obs_returned_lines==0 && obs_sent_words==0); end\nend\n"
    })
  } else {
    source
  }
  source
  .replace(
    old="reg f_burst=0;",
    new=if batch {
      "reg f_burst=0, f_wide=0, f_batch=0;"
    } else {
      "reg f_burst=0, f_wide=0;"
    },
  )
  .replace(
    old="f_burst<=request_burst && request_line && !request_write;",
    new="f_burst<=request_burst && request_line && !request_write; f_wide<=request_wide && request_burst && request_line && !request_write;" +
      (if batch {
        " f_batch<=request_wide && request_data[31] && request_burst && request_line && !request_write;"
      } else {
        ""
      }),
  )
  .replace(old="f_beat<=f_beat+1;", new="f_beat<=f_beat+(f_wide ? 4:1);")
  .replace(
    old="f_beat==(f_burst ? 31:3)",
    new=if batch {
      "f_beat==(f_batch ? 124:(f_wide ? 28:(f_burst ? 31:3)))"
    } else {
      "f_beat==(f_wide ? 28:(f_burst ? 31:3))"
    },
  )
  .replace(
    old="p_response_hold: assert(response_valid &&",
    new="p_wide_hold: assert({response_data1,response_data2,response_data3}==$past({response_data1,response_data2,response_data3})); p_response_hold: assert(response_valid &&",
  )
}

///|
fn streaming_join_properties(delivery~ : Bool = false) -> String {
  let lines : Array[String] = []
  let words = if delivery { 8 } else { 4 }
  for lane in 0..<(2 * words) {
    for
      (clock, reset, roles) in [
        ("ui_clock", "ui_reset", ["source_transfer", "write_binary"]),
        ("clock", "reset", ["destination_transfer", "read_binary"]),
      ] {
      for role in roles {
        let name = "join_" + lane.to_string() + "_" + role
        lines.push(
          "always @(posedge " +
          clock +
          ") if(!" +
          reset +
          ") begin p_" +
          name +
          ": assert(obs_" +
          name +
          "==obs_join_" +
          (lane / words * words).to_string() +
          "_" +
          role +
          "); end",
        )
      }
    }
    let prefix = "obs_join_" + lane.to_string() + "_"
    lines.push(
      "always @(posedge ui_clock) if(!ui_reset) begin p_join_reserved_push_" +
      lane.to_string() +
      ": assert(!" +
      prefix +
      "source_valid || " +
      prefix +
      "source_ready); end",
    )
    lines.push(
      "always @(posedge clock) if(!reset) begin p_join_reserved_pop_" +
      lane.to_string() +
      ": assert(!" +
      prefix +
      "destination_ready || " +
      prefix +
      "destination_valid); end",
    )
  }
  lines.join("\n") + "\n"
}
