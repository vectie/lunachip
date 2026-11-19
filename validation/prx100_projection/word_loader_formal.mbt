///|
pub fn word_loader_formal_bundle(
  negative~ : Bool = false,
) -> ReadOnlyArray[@projection.Artifact] raise {
  let h = @flux_tile.word_loader_verification_fixture()
  let design = @ir.Design::single("flux-tile-word-loader-verification/v1", h)
  let e = @systemverilog.emit_design(design)
  let ports = @verilator.collect_ports(h, e.manifest())
  let inputs = ports
    .iter()
    .filter(p => p.is_input())
    .to_array()
    .map(p => "input wire " + sv_range(p.width()) + p.source_name())
  let outputs = @verilator.output_ports(ports).map(p => {
    "wire " + sv_range(p.width()) + p.source_name() + ";"
  })
  let connections = ports.map(p => {
    "." +
    p.emitted_name() +
    "(" +
    (if negative && p.source_name() == "response_data" {
      "32'b0"
    } else {
      p.source_name()
    }) +
    ")"
  })
  let properties =
    #|reg seen=0;
    #|initial assume(reset);
    #|always @(posedge clock) begin
    #|  seen<=1;
    #|  if(seen && !reset) begin
    #|    p_read_shape: assert(!request_valid || (!request_write && request_data==0 && ((request_bytes==1 && request_mask==1) || (request_bytes==4 && request_mask==15 && request_address[1:0]==0 && {1'b0,column}+14'd4<={1'b0,columns}))));
    #|    p_buffer_no_request: assert(!(state==3 && remaining!=0) || !request_valid);
    #|    p_buffer_row_extent: assert((state!=2 && state!=3) || remaining==0 || {1'b0,column}+{12'b0,remaining}<{1'b0,columns});
    #|    p_data_lane: assert(data==word[7:0]);
    #|    if(!$past(reset)) begin
    #|      if($past(state==2 && response_valid && response_tag==expected_tag && response_fault==0 && !poison)) begin
    #|        p_word_capture: assert(word==$past(response_data));
    #|        p_capture_commit: assert(state==3);
    #|      end
    #|      if($past(state==3 && ((a_valid && a_ready)||(b_valid && b_ready)) && remaining!=0 && !poison)) begin
    #|        p_shift: assert(word==($past(word)>>8));
    #|        p_remaining: assert(remaining==$past(remaining)-1);
    #|        p_row_boundary: assert(row==$past(row));
    #|        p_byte_cursor: assert(column==$past(column)+1);
    #|        p_buffer_commit: assert(state==3);
    #|      end
    #|      if($past(state==3 && !((a_valid && a_ready)||(b_valid && b_ready)) && !poison) && !poison) begin
    #|        p_bank_hold: assert(state==3 && word==$past(word) && remaining==$past(remaining) && progress==$past(progress) && row==$past(row) && column==$past(column));
    #|      end
    #|      if($past(request_valid && !request_ready && !poison) && !poison) begin
    #|        p_request_hold: assert(request_valid && request_address==$past(request_address) && request_bytes==$past(request_bytes) && request_mask==$past(request_mask) && request_tag==$past(request_tag));
    #|      end
    #|      if($past(state==2 && response_valid && (response_fault!=0 || response_tag!=expected_tag))) begin
    #|        p_failed_response_no_commit: assert(state==4 && !a_valid && !b_valid);
    #|      end
    #|    end
    #|  end
    #|end
  let wrapper = "module prx100_projection_formal(" +
    inputs.join(",\n") +
    ");\n" +
    outputs.join("\n") +
    "\n" +
    e.modules()[0].identifier() +
    " dut(" +
    connections.join(",\n") +
    ");\n" +
    properties +
    "\nendmodule\n"
  let job = "[options]\nmode prove\ndepth 16\ntimeout 300\nexpect " +
    (if negative { "fail" } else { "pass" }) +
    "\n[engines]\nsmtbmc bitwuzla\n[script]\nread_verilog -formal -sv dut.sv formal.sv\nprep -top prx100_projection_formal\n[files]\ndut.sv\nformal.sv\n"
  ReadOnlyArray::from_array([
    { path: "production.lcir", content: @codec.serialize(design), },
    { path: "production.sv", content: e.modules()[0].source(), },
    { path: "dut.sv", content: e.modules()[0].source(), },
    { path: "formal.sv", content: wrapper, },
    { path: "job.sby", content: job, },
    {
      path: "claim.txt",
      content: "Exact production word-loader functions, 8x8/K16/4096 bounds; isolated admission with memory/poison/bank-ready cuts free. Initial reset only. Selected local word capture/unpack, cursor, shape, hold and fault properties; mode prove k16. No queue/arbiter/full-device theorem. Negative replaces DUT response_data with zero, retaining monitor input.\n",
    },
  ])
}

///|
pub fn word_loader_cover_bundle() -> ReadOnlyArray[@projection.Artifact] raise {
  let base = word_loader_formal_bundle()
  let covers =
    #|reg f_word_seen=0;
    #|always @(posedge clock)
    #|  if(reset || (state==0 && load_command_valid && !poison)) f_word_seen<=0;
    #|  else if(request_valid && request_ready && request_bytes==4) f_word_seen<=1;
    #|always @(posedge clock) if(seen && !reset) begin
    #|  c_complete_word: cover(f_word_seen && state==4 && fault==0 && progress==4);
    #|  c_buffer_stall: cover(state==3 && remaining==2 && !a_ready && !b_ready);
    #|  c_unaligned_byte: cover(request_valid && request_bytes==1 && request_address[1:0]!=0);
    #|  c_aligned_tail: cover(request_valid && request_bytes==1 && request_address[1:0]==0 && {1'b0,column}+14'd4>{1'b0,columns});
    #|  c_partial_word_fault: cover(f_word_seen && state==4 && fault==9 && progress==4);
    #|  c_protocol_fault: cover(state==4 && fault==10);
    #|  c_reset_buffer: cover($past(reset && state==3 && remaining!=0) && state==0 && remaining==0 && word==0);
    #|end
  ReadOnlyArray::from_array(
    base
    .map(a => {
      if a.path == "formal.sv" {
        assert_eq(a.content.split("endmodule").count(), 2)
        @projection.Artifact::{
          path: a.path,
          content: a.content.replace(
            old="endmodule",
            new=covers + "\nendmodule",
          ),
        }
      } else if a.path == "job.sby" {
        {
          path: a.path,
          content: a.content
          .replace(old="mode prove", new="mode cover")
          .replace(old="depth 16", new="depth 32"),
        }
      } else if a.path == "claim.txt" {
        {
          path: a.path,
          content: a.content +
          "Seven bounded32 cover witnesses; reachability only, no safety claim from covers.\n",
        }
      } else {
        a
      }
    })
    .iter()
    .to_array(),
  )
}
