///|
fn sv_range(width : Int32) -> String {
  if width == 1 {
    ""
  } else {
    "[" + (width - 1).to_string() + ":0] "
  }
}

///|
fn formal_view(
  hw : @ir.Module,
  e : @systemverilog.EmittedDesign,
  observations : ReadOnlyArray[@ddr.Observation],
  source : String,
) -> (String, String) raise {
  let declarations : Array[String] = []
  let assigns : Array[String] = []
  let bindings : Array[String] = []
  for o in observations {
    let width = hw.nodes()[o.node.ordinal()].signal_type().width().bits()
    let m = e
      .manifest()
      .mappings()
      .iter()
      .find_first(m => m.kind() == Node && m.local_ordinal() == o.node.ordinal())
      .unwrap()
    declarations.push("  output wire " + sv_range(width) + "obs_" + o.name)
    assigns.push("  assign obs_" + o.name + " = " + m.identifier() + ";")
    bindings.push(
      o.name +
      " node=" +
      o.node.ordinal().to_string() +
      " width=" +
      width.to_string() +
      " emitted=" +
      m.identifier(),
    )
  }
  let header = ",\n" + declarations.join(",\n") + "\n);"
  let footer = assigns.join("\n") + "\nendmodule"
  assert_eq(source.split("\n);").count(), 2)
  assert_eq(source.split("endmodule").count(), 2)
  let view = source
    .replace(old="\n);", new=header)
    .replace(old="endmodule", new=footer)
  assert_eq(
    view.replace(old=header, new="\n);").replace(old=footer, new="endmodule"),
    source,
  )
  (
    view,
    "production_rtl_sha256=" +
    @verilator.sha256_hex(source) +
    "\nobservation_only_no_logic_change=true\n" +
    bindings.join("\n") +
    "\n",
  )
}

///|
fn bridge_properties() -> String {
  (
    #|reg f_seen_fast=0, f_seen_slow=0;
    #|reg [15:0] f_accepted=0, f_returned=0;
    #|reg [4:0] f_beat=0;
    #|reg f_burst=0;
    #|reg [31:0] f_word0=0, f_word1=0, f_word2=0, f_word3=0;
    #|always @(posedge clock) begin
    #|  f_seen_slow<=1;
    #|  if(reset) begin f_accepted<=0; f_returned<=0; f_beat<=0; end
    #|  else begin
    #|    if(request_valid && request_ready) begin
    #|      f_accepted<=f_accepted+1;
    #|      f_burst<=request_burst && request_line && !request_write;
    #|      f_word0<=request_data; f_word1<=request_data1; f_word2<=request_data2; f_word3<=request_data3;
    #|    end
    #|    if(response_valid && response_ready) begin
    #|      if(response_last) begin f_returned<=f_returned+1; f_beat<=0; end
    #|      else f_beat<=f_beat+1;
    #|    end
    #|    p_response_owner: assert(!response_valid || f_accepted>f_returned);
    #|    p_single_source_owner: assert(f_accepted-f_returned<=1);
    #|    p_cache_hit_gate: assert(!obs_cache_hit || (memory_healthy && !request_write && !request_line && request_address[1:0]==0 && obs_cache_valid));
    #|    p_line_last: assert(!response_valid || response_last==(!obs_source_line || f_beat==(f_burst ? 31:3)));
    #|    p_line_owner: assert(!response_valid || !obs_source_line || obs_source_state==1);
    #|    if(f_seen_slow && $past(obs_source_accept && !reset)) begin
    #|      p_source_line_capture: assert(obs_source_line==$past(request_line && !request_write));
    #|      p_source_burst_capture: assert(obs_source_burst==$past(request_burst && request_line && !request_write));
    #|    end
    #|    p_cache_install: assert(!obs_install || (!obs_source_burst && obs_source_state==1 && obs_receive_lane==3 && memory_healthy));
    #|    if(f_seen_slow && $past(obs_source_accept && obs_cache_hit && !reset)) begin
    #|      p_local_hit_response: assert(response_valid && response_fault==0);
    #|    end
    #|    if(f_seen_slow && $past(!memory_healthy && !reset)) begin
    #|      p_cache_health_invalidation: assert(!obs_cache_valid);
    #|    end
    #|    if(f_seen_slow && $past(response_valid && !response_ready && !reset)) begin
    #|      p_response_hold: assert(response_valid && response_data==$past(response_data) && response_fault==$past(response_fault) && response_last==$past(response_last));
    #|    end
    #|  end
    #|end
    #|always @(posedge ui_clock) begin
    #|  f_seen_fast<=1;
    #|  if(f_seen_fast && !ui_reset) begin
    #|    p_calibration_gate: assert(calibrated || (!app_en && !app_wdf_wren));
    #|    p_poison_gate: assert(!bridge_poisoned || (!app_en && !app_wdf_wren));
    #|    if($past(!ui_reset && obs_calibrated_once && !calibrated)) begin
    #|      p_calibration_loss_sticky: assert(bridge_poisoned);
    #|    end
    #|    if($past(!ui_reset && bridge_poisoned)) begin
    #|      p_poison_sticky: assert(bridge_poisoned);
    #|    end
    #|    p_native_alignment: assert(app_addr[2:0]==0 && app_addr[27]==0);
    #|    p_burst_shape: assert(!app_en || !obs_request[62] || (obs_request[61] && !obs_request[60] && obs_request[38:32]==0));
    #|    p_burst_address: assert(!app_en || app_addr==({1'b0,obs_request[59:36],3'b0}+{22'b0,obs_line_index,3'b0}));
    #|    p_native_command: assert(!app_en || app_cmd==0 || app_cmd==1);
    #|    p_write_mask: assert(!app_wdf_wren || (obs_request[61] ? app_wdf_mask==0 : ((app_wdf_mask==16'hfff0 || app_wdf_mask==16'hff0f || app_wdf_mask==16'hf0ff || app_wdf_mask==16'h0fff) && app_wdf_word0==app_wdf_word1 && app_wdf_word0==app_wdf_word2 && app_wdf_word0==app_wdf_word3)));
    #|    p_line_write_data: assert(!app_wdf_wren || !obs_request[61] || (app_wdf_word0==f_word0 && app_wdf_word1==f_word1 && app_wdf_word2==f_word2 && app_wdf_word3==f_word3));
    #|    p_native_request_shape: assert(!app_en || (obs_request[33:32]==0 && (!obs_request[61] || obs_request[35:32]==0)));
    #|    p_collect_no_issue: assert(obs_state!=4 || (!app_en && !app_wdf_wren));
    #|    p_bounded_issue: assert(obs_issued_lines<=8);
    #|    p_bounded_returns: assert(obs_returned_lines<=obs_issued_lines);
    #|    p_bounded_words: assert(obs_sent_words<=32);
    #|    p_buffer_prefix: assert(obs_pipeline_failed || obs_sent_words<={obs_returned_lines,2'b0});
    #|    p_pipeline_read_only: assert(obs_state!=5 || (!app_wdf_wren && (!app_en || app_cmd==1)));
    #|    if($past(!ui_reset && obs_pipeline_valid && !obs_pipeline_ready)) begin
    #|      p_emit_hold: assert(obs_pipeline_valid && obs_pipeline_data==$past(obs_pipeline_data) && obs_pipeline_fault==$past(obs_pipeline_fault));
    #|    end
    #|    p_write_end: assert(app_wdf_wren==app_wdf_end);
    #|    if(calibrated && !bridge_poisoned && $past(calibrated && !ui_reset && app_en && !app_rdy)) begin
    #|      p_command_hold: assert(app_en && app_addr==$past(app_addr) && app_cmd==$past(app_cmd));
    #|    end
    #|    if(calibrated && !bridge_poisoned && $past(calibrated && !ui_reset && app_wdf_wren && !app_wdf_rdy)) begin
    #|      p_data_hold: assert(app_wdf_wren && app_wdf_mask==$past(app_wdf_mask) && app_wdf_word0==$past(app_wdf_word0) && app_wdf_word1==$past(app_wdf_word1) && app_wdf_word2==$past(app_wdf_word2) && app_wdf_word3==$past(app_wdf_word3));
    #|    end
    #|  end
    #|end
  )
}

///|
pub fn formal_bundle(
  source : String,
  negative~ : Bool = false,
  wide~ : Bool = false,
  batch~ : Bool = false,
  clock_ratio~ : Int32 = 4,
  streaming~ : Bool = false,
  read_ahead~ : Bool = false,
  eight_row~ : Bool = false,
  sixteen_row~ : Bool = false,
  aligned_extent~ : Bool = false,
  delivery~ : Bool = false,
) -> ReadOnlyArray[@projection.Artifact] raise {
  let kind = "bridge"
  let bridge = true
  let (hw, observations) = if read_ahead {
    @ddr.read_ahead_bridge_evidence(
      eight_row~,
      sixteen_row~,
      aligned_extent~,
      delivery~,
    )
  } else if streaming {
    @ddr.streaming_bridge_evidence()
  } else if batch {
    @ddr.batched_bridge_evidence()
  } else if wide {
    @ddr.wide_bridge_evidence()
  } else {
    @ddr.bridge_evidence()
  }
  let design = @ir.Design::single("prx100-ddr-projection-" + kind + "/v1", hw)
  let e = @systemverilog.emit_design(design)
  let ports = @verilator.collect_ports(hw, e.manifest())
  let (view, manifest) = formal_view(hw, e, observations, source)
  let inputs : Array[String] = []
  let wires : Array[String] = []
  let connections : Array[String] = []
  for p in ports {
    let internally_clocked = bridge &&
      ["clock", "ui_clock", "reset", "ui_reset"].contains(p.source_name())
    if p.is_input() && !internally_clocked {
      inputs.push("input wire " + sv_range(p.width()) + p.source_name())
    }
    if p.is_output() {
      wires.push("wire " + sv_range(p.width()) + p.source_name() + ";")
    }
    let bypass = negative &&
      p.source_name() == (if bridge { "calibrated" } else { "memory_healthy" })
    connections.push(
      "." +
      p.emitted_name() +
      "(" +
      (if bypass { "1'b1" } else { p.source_name() }) +
      ")",
    )
  }
  for o in observations {
    let name = "obs_" + o.name
    let width = hw.nodes()[o.node.ordinal()].signal_type().width().bits()
    wires.push("wire " + sv_range(width) + name + ";")
    connections.push("." + name + "(" + name + ")")
  }
  assert_true([3, 4].contains(clock_ratio))
  let clocks = if bridge && clock_ratio == 3 {
    (
      #|reg [2:0] f_phase=0;
      #|reg [3:0] f_boot=0;
      #|always @($global_clock) begin
      #|  f_phase<=f_phase==5 ? 0 : f_phase+1;
      #|  if(f_boot<8) f_boot<=f_boot+1;
      #|end
      #|wire ui_clock=f_phase[0];
      #|wire clock=f_phase>=3;
      #|wire reset=f_boot<8;
      #|wire ui_reset=f_boot<8;
    )
  } else if bridge {
    (
      #|reg [2:0] f_phase=0;
      #|reg [3:0] f_boot=0;
      #|always @($global_clock) begin
      #|  f_phase<=f_phase+1;
      #|  if(f_boot<8) f_boot<=f_boot+1;
      #|end
      #|wire ui_clock=f_phase[0];
      #|wire clock=f_phase[2];
      #|wire ui_reset=f_boot<8;
      #|wire reset=ui_reset;
    )
  } else {
    ""
  }
  let wrapper = "module prx100_projection_formal(" +
    inputs.join(",\n") +
    ");\n" +
    wires.join("\n") +
    "\n" +
    clocks +
    "\n" +
    e.modules()[0].identifier() +
    " dut(" +
    connections.join(",\n") +
    ");\n" +
    (if wide {
      wide_bridge_properties(bridge_properties(), batch~, read_ahead~)
    } else {
      bridge_properties()
    }) +
    (if streaming { "\n" + streaming_join_properties(delivery~) } else { "" }) +
    "\nendmodule\n"
  let wrapper = if read_ahead {
    read_ahead_properties(wrapper)
  } else {
    wrapper
  }
  let wrapper = if eight_row { eight_row_properties(wrapper) } else { wrapper }
  let wrapper = if sixteen_row {
    sixteen_row_properties(wrapper)
  } else {
    wrapper
  }
  let bound = 128
  let wrapper = if delivery { delivery_properties(wrapper) } else { wrapper }
  let job = "[options]\nmode bmc\ndepth " +
    bound.to_string() +
    "\ntimeout 2400\n" +
    (if bridge { "multiclock on\n" } else { "" }) +
    "expect " +
    (if negative { "fail" } else { "pass" }) +
    "\n[engines]\nsmtbmc bitwuzla\n[script]\nread_verilog -formal -sv dut.sv formal.sv\nprep -top prx100_projection_formal\n[files]\ndut.sv\nformal.sv\n"
  ReadOnlyArray::from_array([
    { path: "dut.sv", content: view, },
    { path: "production.sv", content: source, },
    { path: "production.lcir", content: @codec.serialize(design), },
    { path: "observations.txt", content: manifest, },
    { path: "formal.sv", content: wrapper, },
    { path: "job.sby", content: job, },
    {
      path: "claim.txt",
      content: kind +
      " bounded safety depth=" +
      bound.to_string() +
      "; " +
      (if bridge {
        "global steps, fixed" +
        clock_ratio.to_string() +
        ":1 fast/slow clocks with coincident rising edges and8-step coordinated boot reset"
      } else {
        "controller clock edges, only initial reset assumed; core/AXI/DDR inputs free"
      }) +
      ". Prefix safety only: no unbounded/full-job/analog claim; complete jobs are separately tested in native/RTL/board evidence. Negative bypasses DUT memory-health/calibration input while retaining external named assertion.\n",
    },
  ])
}
