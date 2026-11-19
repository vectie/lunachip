///|
fn formal_bundle(
  root : String,
  negative : Bool,
  core~ : Bool = false,
  parallel~ : Bool = false,
  overlap~ : Bool = false,
  wide~ : Bool = false,
  batch~ : Bool = false,
  throughput~ : Bool = false,
  compute~ : Bool = false,
  eight_row~ : Bool = false,
  short_unary~ : Bool = false,
  sixteen_row~ : Bool = false,
  packed_weights~ : Bool = false,
  feedback~ : Bool = false,
  delivery~ : Bool = false,
  interleaved~ : Bool = false,
) -> Unit raise {
  guard !@fs.path_exists(root) else { fail("fresh formal root") }
  @fs.create_dir(root)
  let hw = if core {
    if interleaved {
      @fp.interleaved_layer_machine()
    } else if feedback {
      @fp.feedback_layer_machine(delivery~)
    } else if packed_weights {
      @fp.contiguous_layer_machine()
    } else if sixteen_row {
      @fp.sixteen_row_layer_machine()
    } else if short_unary {
      @fp.short_unary_layer_machine()
    } else if eight_row {
      @fp.eight_row_layer_machine()
    } else if compute {
      @fp.compute_layer_machine()
    } else if throughput {
      @fp.throughput_layer_machine()
    } else if batch {
      @fp.batched_layer_machine()
    } else if wide {
      @fp.wide_layer_machine()
    } else if overlap {
      @fp.overlapped_layer_machine()
    } else if parallel {
      @fp.parallel_layer_machine()
    } else {
      @fp.layer_machine()
    }
  } else if delivery {
    @target.delivery_controller()
  } else if sixteen_row {
    @target.sixteen_row_controller()
  } else if eight_row {
    @target.eight_row_controller()
  } else if batch {
    @target.batched_controller()
  } else if wide {
    @target.wide_controller()
  } else {
    @target.controller()
  }
  let semantic = if core {
    "qwen-layer-machine/v1"
  } else {
    "prx100-qwen-layer-control/v1"
  }
  let emitted = @sv.emit_design(@ir.Design::single(semantic, hw))
  let ports : Array[String] = []
  let con : Array[String] = []
  for n in hw.nodes() {
    if n.kind() is Input(name) {
      ports.push("input wire " + range(n.signal_type().width().bits()) + name)
      con.push("." + mapped(emitted, name, InputPort) + "(" + name + ")")
    }
  }
  let text = StringBuilder()
  text.write_string("module layer_formal(" + ports.join(",") + ");\n")
  for p in hw.outputs() {
    text.write_string(
      "wire " + range(p.signal_type().width().bits()) + p.name() + ";\n",
    )
    con.push("." + mapped(emitted, p.name(), OutputPort) + "(" + p.name() + ")")
  }
  text.write_string(
    emitted.modules()[0].identifier() +
    " dut(" +
    con.join(",") +
    ");\nreg past_valid=0;\n",
  )
  text.write_string(
    "wire checked_write=" +
    (if negative { "~" } else { "" }) +
    (if core { "ddr_request_write" } else { "program_write" }) +
    ";\n",
  )
  text.write_string(
    if core {
      (
        #|always @(posedge clock) begin
        #| past_valid<=1;
        #| if(!past_valid) assume(reset);
        #| if(past_valid && !reset) begin
        #|   p_exclusive: assert(!(busy && (done || fault)));
        #|   if(fault) begin p_fault_no_request: assert(!ddr_request_valid); end
        #|   if(done) begin p_done_no_request: assert(!ddr_request_valid); end
        #|   if(ddr_request_valid) begin p_request_alignment: assert(ddr_request_address[1:0]==0); end
        #|   if(ddr_request_valid && ddr_request_burst) begin
        #|     p_burst_alignment: assert(ddr_request_address[6:0]==0);
        #|     p_read_only_burst: assert(!checked_write && ddr_request_line);
        #|   end
        #|   if(!$past(reset) && $past(fault)) begin p_fault_sticky: assert(fault); end
        #|   if($past(reset)) begin p_reset_idle: assert(!busy && !done && !fault && error==0); end
        #| end
        #|end
      )
    } else {
      (
        #|always @(posedge clock) begin
        #| past_valid<=1;
        #| if(!past_valid) assume(reset);
        #| if(past_valid && !reset) begin
        #|   if(c_busy || c_fault || observe_protocol) begin
        #|     p_busy_no_program_write: assert(!checked_write);
        #|     p_busy_no_scratch_write: assert(!scratch_write);
        #|     p_busy_no_start: assert(!start);
        #|   end
        #|   if(ddr_request_valid) begin
        #|     p_request_owned: assert(observe_owner!=0 && !observe_issued && memory_healthy && !observe_protocol);
        #|   end
        #|   if(start) begin p_start_configured: assert(program_count>=1 && program_count<=2048 && memory_healthy && !c_busy && !c_fault); end
        #|   if(!$past(reset) && $past(s_axi_rvalid && !s_axi_rready)) begin
        #|     p_held_r: assert(s_axi_rvalid && {s_axi_rdata,s_axi_rresp}==$past({s_axi_rdata,s_axi_rresp}));
        #|   end
        #|   if(!$past(reset) && $past(s_axi_bvalid && !s_axi_bready)) begin
        #|     p_held_b: assert(s_axi_bvalid && s_axi_bresp==$past(s_axi_bresp));
        #|   end
        #|   if(!$past(reset) && $past(ddr_request_valid && !ddr_request_ready) && ddr_request_valid) begin
        #|     p_held_ddr: assert({ddr_request_address,ddr_request_write,ddr_request_line,ddr_request_burst,ddr_request_data}==$past({ddr_request_address,ddr_request_write,ddr_request_line,ddr_request_burst,ddr_request_data}));
        #|   end
        #|   if($past(reset)) begin p_reset_transport: assert(observe_owner==0 && !observe_issued); end
        #| end
        #|end
      )
    },
  )
  text.write_string("\nendmodule\n")
  save(
    root,
    "dut.sv",
    if core {
      memory_style(normalize(optimized(emitted.source())))
    } else {
      normalize(optimized(emitted.source()))
    },
  )
  save(root, "formal.sv", text.to_string())
  let depth = if core { 48 } else { 32 }
  save(
    root,
    "job.sby",
    "[options]\nmode bmc\ndepth " +
    depth.to_string() +
    "\ntimeout " +
    (if core { "1500" } else { "600" }) +
    "\nexpect " +
    (if negative { "fail" } else { "pass" }) +
    "\n[engines]\nsmtbmc bitwuzla\n[script]\nread_verilog -formal -sv dut.sv formal.sv\nprep -top layer_formal\n[files]\ndut.sv\nformal.sv\n",
  )
  save(
    root,
    "claim.txt",
    (if core {
      "BMC48 actual complete-layer instruction-machine RTL: eight reset,exclusive terminal,sticky fault,request-alignment and read-only-burst assertions. Initial reset only;all subsequent inputs and unwritten RAM symbolic. Bound reaches initial descriptor issue,not a complete layer. No arithmetic correctness or unbounded-memory safety theorem."
    } else {
      "BMC32 actual layer target control: nine ownership,busy write/start rejection,configured launch,held AXI/DDR response and reset assertions;initial reset only,core observations and external inputs otherwise unconstrained. No full-layer liveness or arithmetic theorem. Negative inverts the checked program-write output."
    }) +
    "\n",
  )
}
