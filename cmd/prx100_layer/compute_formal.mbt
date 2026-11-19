///|
fn compute_multiplier_formal(root : String, negative : Bool) -> Unit raise {
  guard !@fs.path_exists(root) else {
    fail("fresh BF16 multiplier formal root")
  }
  @fs.create_dir(root)
  let old = @sv.emit_design(
    @ir.Design::single(
      "qwen-fp32-multiply/v1",
      @fp.pipelined_multiplier(fast=true),
    ),
  )
  let candidate = @sv.emit_design(
    @ir.Design::single(
      "qwen-bf16-weight-multiply/v1",
      @fp.bf16_weight_multiplier(),
    ),
  )
  save(root, "old.sv", old.source())
  save(root, "candidate.sv", candidate.source())
  let text = StringBuilder()
  text.write_string(
    "module layer_formal(input wire clock,reset,input wire[31:0] a,input wire[15:0] b);\nwire[31:0] old_result,new_result;\n",
  )
  for
    (e, name, result, weight) in [
      (old, "old_i", "old_result", "{b,16'b0}"),
      (candidate, "candidate_i", "new_result", "b"),
    ] {
    text.write_string(
      e.modules()[0].identifier() +
      " " +
      name +
      "(." +
      mapped(e, "clock", InputPort) +
      "(clock),." +
      mapped(e, "reset", InputPort) +
      "(reset),." +
      mapped(e, "a", InputPort) +
      "(a),." +
      mapped(e, "b", InputPort) +
      "(" +
      weight +
      "),." +
      mapped(e, "result", OutputPort) +
      "(" +
      result +
      "));\n",
    )
  }
  text.write_string(
    "reg past_valid=0;always @(posedge clock) begin past_valid<=1;if(!past_valid) assume(reset);if(past_valid) begin p_bf16_exact: assert(old_result==(new_result" +
    (if negative { "^32'h1" } else { "" }) +
    "));end end\nendmodule\n",
  )
  save(root, "formal.sv", text.to_string())
  save(
    root,
    "job.sby",
    "[options]\nmode bmc\ndepth 6\ntimeout 1200\nexpect " +
    (if negative { "fail" } else { "pass" }) +
    "\n[engines]\nsmtbmc bitwuzla\n[script]\nread_verilog -formal -sv old.sv candidate.sv formal.sv\nprep -top layer_formal\n[files]\nold.sv\ncandidate.sv\nformal.sv\n",
  )
  save(
    root, "claim.txt", "Actual three-edge 24x8 BF16-weight multiplier compared to unchanged full-width FP32 pipeline with BF16 promoted by16zero bits. BMC6;first-edge reset required,all48operand bits and every later reset arbitrary. Exact RNE,gradual underflow,signed zeros,infinities and canonical NaNs retained. Negative flips one bit. No unbounded or complete-core numerical proof.\n",
  )
}
