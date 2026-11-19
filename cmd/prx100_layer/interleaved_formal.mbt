///|
// The actual interleaved unit, without arithmetic cuts. This task checks
// bounded temporal control and ownership, not universal nonlinear accuracy.
fn interleaved_unit_formal(root : String, negative : Bool) -> Unit raise {
  guard !@fs.path_exists(root) else {
    fail("fresh interleaved unit formal root")
  }
  @fs.create_dir(root)
  let hw = @fp.interleaved_unary_operator()
  let design = @ir.Design::single("qwen-fp32-interleaved-unary/v1", hw)
  let emitted = @sv.emit_design(design)
  let ports : Array[String] = []
  let connections : Array[String] = []
  for n in hw.nodes() {
    if n.kind() is Input(name) {
      ports.push("input wire " + range(n.signal_type().width().bits()) + name)
      connections.push(
        "." + mapped(emitted, name, InputPort) + "(" + name + ")",
      )
    }
  }
  let text = StringBuilder()
  text.write_string("module layer_formal(" + ports.join(",") + ");\n")
  for p in hw.outputs() {
    text.write_string(
      "wire " + range(p.signal_type().width().bits()) + p.name() + ";\n",
    )
    connections.push(
      "." + mapped(emitted, p.name(), OutputPort) + "(" + p.name() + ")",
    )
  }
  text.write_string(
    emitted.modules()[0].identifier() + " dut(" + connections.join(",") + ");\n",
  )
  for i in 0..<4 {
    let suffix = i.to_string()
    let v = "value" + suffix
    text.write_string(
      "wire valid" +
      suffix +
      " = mode!=0 && (mode==3 ? " +
      v +
      "[30:0]<=31'h7f800000 : (!" +
      v +
      "[31] && " +
      v +
      "[30:0]>=31'h1f800000 && " +
      v +
      "[30:0]<=31'h5f800000));\n",
    )
    text.write_string(
      "wire active" +
      suffix +
      " = valid" +
      suffix +
      " && !(mode==3 && " +
      v +
      "[30:0]>31'h42000000);\n",
    )
    text.write_string(
      "reg invalid" +
      suffix +
      "=0;\nalways @(posedge clock) if(reset) invalid" +
      suffix +
      "<=0; else if(start && !busy) invalid" +
      suffix +
      "<=!valid" +
      suffix +
      ";\n",
    )
  }
  text.write_string(
    "wire checked_busy=" + (if negative { "~busy" } else { "busy" }) + ";\n",
  )
  text.write_string(
    (
      #|reg past_valid=0,tracking=0;
      #|reg [6:0] remaining=0;
      #|always @(posedge clock) begin
      #| past_valid<=1;
      #| if(!past_valid) assume(reset);
      #| if(reset) begin tracking<=0; remaining<=0; end
      #| else if(start && !busy) begin
      #|   tracking<=1;
      #|   remaining <= !(active0 || active1 || active2 || active3) ? 0 :
      #|                mode==1 ? 51 : mode==2 ? 71 : 95;
      #| end else if(remaining!=0) remaining<=remaining-1;
      #| if(past_valid && !reset) begin
      #|   p_exclusive: assert(!(busy && done));
      #|   if(tracking && remaining!=0) begin p_exact_busy_interval: assert(checked_busy && !done); end
      #|   if(tracking && remaining==0) begin p_exact_completion: assert(!busy && done); end
      #|   if($past(reset)) begin p_reset_idle: assert(!busy && !done); end
      #| end
      #|end
      #|
    ),
  )
  for i in 0..<4 {
    let n = i.to_string()
    text.write_string(
      "always @(posedge clock) if(past_valid && !reset) begin\n",
    )
    text.write_string(
      " if(tracking) begin p_error_owner_" +
      n +
      ": assert(error" +
      n +
      "==invalid" +
      n +
      "); end\n",
    )
    text.write_string(
      " if($past(!reset && !busy && !start)) begin p_idle_hold_" +
      n +
      ": assert({result" +
      n +
      ",error" +
      n +
      "}==$past({result" +
      n +
      ",error" +
      n +
      "})); end\n",
    )
    text.write_string(
      " if($past(reset)) begin p_reset_result_" +
      n +
      ": assert(result" +
      n +
      "==0 && !error" +
      n +
      "); end\nend\n",
    )
  }
  text.write_string("endmodule\n")
  save(root, "design.lcir", @codec.serialize(design))
  save(root, "dut.sv", normalize(optimized(emitted.source())))
  save(root, "formal.sv", text.to_string())
  save(
    root,
    "job.sby",
    "[options]\nmode bmc\ndepth 128\ntimeout 1800\nexpect " +
    (if negative { "fail" } else { "pass" }) +
    "\n[engines]\nsmtbmc bitwuzla\n[script]\nread_verilog -formal -sv dut.sv formal.sv\nprep -top layer_formal\n[files]\ndut.sv\nformal.sv\n",
  )
  save(
    root, "claim.txt", "BMC128 actual four-context nonlinear RTL,16 named properties: exclusive busy/done,exact 51/71/95-edge completion including busy-start rejection,reset-idle,and per-lane error ownership,idle-result hold,reset results. Initial reset only; subsequent reset/start/mode/all128 input bits unconstrained. No arithmetic cuts or assumed operand ranges. Negative inverts the busy observation. Arithmetic accuracy is separately checked by bit-exact scalar comparison and inherited exact primitive proofs; this is not universal nonlinear equivalence or an unbounded core proof.\n",
  )
}
