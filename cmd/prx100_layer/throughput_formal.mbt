///|
// A one-step combinational miter: both input words are entirely free.
// No sequential device or workload-liveness conclusion follows from it.
fn throughput_adder_formal(
  root : String,
  negative : Bool,
  product~ : Bool = false,
  feedback~ : Bool = false,
) -> Unit raise {
  guard !@fs.path_exists(root) else { fail("fresh adder equivalence root") }
  @fs.create_dir(root)
  let old = @sv.emit_design(
    @ir.Design::single(
      if product {
        "qwen-fp32-multiplier/v1"
      } else {
        "qwen-fp32-adder/v1"
      },
      if product {
        @fp.fp32_multiplier()
      } else {
        @fp.fp32_adder()
      },
    ),
  )
  let fast = @sv.emit_design(
    @ir.Design::single(
      if feedback {
        "qwen-fp32-feedback-adder/v1"
      } else if product {
        "qwen-fp32-fast-multiplier/v1"
      } else {
        "qwen-fp32-fast-adder/v1"
      },
      if feedback {
        @fp.feedback_adder()
      } else if product {
        @fp.fp32_multiplier(fast=true)
      } else {
        @fp.throughput_adder()
      },
    ),
  )
  save(root, "old.sv", old.source())
  save(root, "fast.sv", fast.source())
  let text = StringBuilder()
  text.write_string(
    "module layer_formal(input wire [31:0] a,b);\nwire [31:0] old_result,fast_result;\n",
  )
  for
    (e, name, result) in [
      (old, "original", "old_result"),
      (fast, "candidate", "fast_result"),
    ] {
    text.write_string(
      e.modules()[0].identifier() +
      " " +
      name +
      "(." +
      mapped(e, "a", InputPort) +
      "(a),." +
      mapped(e, "b", InputPort) +
      "(b),." +
      mapped(e, "result", OutputPort) +
      "(" +
      result +
      "));\n",
    )
  }
  text.write_string(
    "always @* begin p_bit_exact: assert(old_result == (fast_result" +
    (if negative { " ^ 32'h1" } else { "" }) +
    "));end\nendmodule\n",
  )
  save(root, "formal.sv", text.to_string())
  save(
    root,
    "job.sby",
    "[options]\nmode bmc\ndepth 1\ntimeout 900\nexpect " +
    (if negative { "fail" } else { "pass" }) +
    "\n[engines]\nsmtbmc bitwuzla\n[script]\nread_verilog -formal -sv old.sv fast.sv formal.sv\nprep -top layer_formal\n[files]\nold.sv\nfast.sv\nformal.sv\n",
  )
  save(
    root,
    "claim.txt",
    "One-step combinational equivalence of actual original and throughput FP32 " +
    (if product { "multipliers" } else { "adders" }) +
    " for all arbitrary 64 input bits. No input assumptions. Ordered RNE,subnormals,signed zeros,infinities and canonical NaNs retained. Negative flips one result bit. Not a sequential core safety or liveness proof.\n",
  )
}

///|
// Reset-initialized five-edge prefix,including two arbitrary streamed pairs.
fn throughput_adder_pipeline_formal(
  root : String,
  negative : Bool,
  bounded~ : Bool = false,
) -> Unit raise {
  guard !@fs.path_exists(root) else { fail("fresh pipelined adder root") }
  @fs.create_dir(root)
  let old = @sv.emit_design(
    @ir.Design::single("qwen-fp32-adder/v1", @fp.fp32_adder()),
  )
  let fast = @sv.emit_design(
    @ir.Design::single("qwen-fp32-add-pipe2/v1", @fp.pipelined_adder(bounded~)),
  )
  save(root, "old.sv", old.source())
  save(root, "fast.sv", fast.source())
  let text = StringBuilder()
  text.write_string(
    "module layer_formal(input wire clock,reset,input wire [31:0] a,b);\nwire [31:0] old_result,fast_result;\n",
  )
  for
    (e, name, result, clocked) in [
      (old, "original", "old_result", false),
      (fast, "candidate", "fast_result", true),
    ] {
    let ports = [
      "." + mapped(e, "a", InputPort) + "(a)",
      "." + mapped(e, "b", InputPort) + "(b)",
      "." + mapped(e, "result", OutputPort) + "(" + result + ")",
    ]
    if clocked {
      ports.push("." + mapped(e, "clock", InputPort) + "(clock)")
      ports.push("." + mapped(e, "reset", InputPort) + "(reset)")
    }
    text.write_string(
      e.modules()[0].identifier() + " " + name + "(" + ports.join(",") + ");\n",
    )
  }
  text.write_string(
    "reg past_valid=0;reg [31:0] expected1,expected2;\nalways @(posedge clock) begin\npast_valid<=1;if(!past_valid) assume(reset);\nif(reset) begin expected1<=0;expected2<=0;end else begin expected1<=old_result;expected2<=expected1;end\nif(past_valid) begin p_two_edge_rne: assert(expected2 == (fast_result" +
    (if negative { " ^ 32'h1" } else { "" }) +
    "));end\nend\nendmodule\n",
  )
  save(root, "formal.sv", text.to_string())
  save(
    root,
    "job.sby",
    "[options]\nmode bmc\ndepth 5\ntimeout 1200\nexpect " +
    (if negative { "fail" } else { "pass" }) +
    "\n[engines]\nsmtbmc bitwuzla\n[script]\nread_verilog -formal -sv old.sv fast.sv formal.sv\nprep -top layer_formal\n[files]\nold.sv\nfast.sv\nformal.sv\n",
  )
  save(
    root, "claim.txt", "Actual two-edge FP32 adder compared with the original combinational adder delayed two registers. BMC5,first-edge-reset-only assumption,all raw operands and all later resets arbitrary. Covers two streamed arbitrary input pairs and reset flushing within this prefix. Negative flips one result bit. No unbounded temporal or complete-core numerical proof.\n",
  )
}
