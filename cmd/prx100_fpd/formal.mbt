///|
fn formal_bundle(root : String, negative : Bool) -> Unit raise {
  guard !@fs.path_exists(root) else { fail("fresh output directory required") }
  let h = @target.controller()
  let e = @sv.emit_design(
    @ir.Design::single("prx100-floating-point-ddr-controller/v1", h),
  )
  let ports : Array[String] = []
  let connections : Array[String] = []
  for n in h.nodes() {
    if n.kind() is Input(name) {
      ports.push("input wire " + range(n.signal_type().width().bits()) + name)
      connections.push("." + mapped(e, name, InputPort) + "(" + name + ")")
    }
  }
  let text = StringBuilder()
  text.write_string("module fpddr_formal(" + ports.join(",") + ");\n")
  for p in h.outputs() {
    text.write_string(
      "wire " + range(p.signal_type().width().bits()) + p.name() + ";\n",
    )
    connections.push(
      "." + mapped(e, p.name(), OutputPort) + "(" + p.name() + ")",
    )
  }
  text.write_string(
    e.modules()[0].identifier() + " dut(" + connections.join(",") + ");\n",
  )
  text.write_string(
    "wire checked_load=" + (if negative { "~load" } else { "load" }) + ";\n",
  )
  text.write_string(
    (
      #|reg past_valid=0;
      #|always @(posedge clock) begin
      #|  past_valid<=1;
      #|  if(!past_valid) assume(reset);
      #|  if(past_valid && !reset) begin
      #|    p_exclusive: assert(!(observe_busy && (observe_done || observe_fault)));
      #|    if(observe_fault) begin
      #|      p_fault_no_load: assert(!checked_load);
      #|      p_fault_no_start: assert(!start);
      #|      p_fault_no_request: assert(!ddr_request_valid);
      #|      p_fault_reset_core: assert(core_reset);
      #|    end
      #|    if(!memory_healthy) begin
      #|      p_unhealthy_no_load: assert(!load);
      #|      p_unhealthy_no_request: assert(!ddr_request_valid);
      #|    end
      #|    if(start) begin p_launch_owned: assert(observe_busy && memory_healthy && !observe_fault); end
      #|    if(load) begin p_load_owned: assert(observe_busy && memory_healthy && !observe_fault); end
      #|    if(ddr_request_valid) begin p_request_owned: assert(observe_owner!=0 && !observe_issued); end
      #|    if(!$past(reset) && $past(observe_fault)) begin
      #|      p_fault_sticky: assert(observe_fault);
      #|      p_cache_fault: assert(!observe_cache);
      #|    end
      #|    if($past(reset)) begin p_reset_idle: assert(!observe_busy && !observe_fault && !observe_done && !observe_cache); end
      #|    if(observe_done) begin p_done_complete: assert(observe_completed!=0); end
      #|  end
      #|end
      #|endmodule
      #|
    ),
  )
  @fs.create_dir(root)
  save(root, "dut.sv", normalize(optimized(e.source())))
  save(root, "formal.sv", text.to_string())
  save(
    root,
    "job.sby",
    "[options]\nmode bmc\ndepth 32\ntimeout 600\nexpect " +
    (if negative { "fail" } else { "pass" }) +
    "\n[engines]\nsmtbmc bitwuzla\n[script]\nread_verilog -formal -sv dut.sv formal.sv\nprep -top fpddr_formal\n[files]\ndut.sv\nformal.sv\n",
  )
  save(
    root, "claim.txt", "BMC32 actual DDR controller, 14 ownership/reset/health/fault assertions; initial reset only, otherwise unconstrained inputs and cache memories. Does not prove full DDR transactions, batch completion or FP arithmetic. Negative inverts only the checked core-load output.\n",
  )
}
