///|
fn banked_formal(root : String, negative : Bool) -> Unit raise {
  guard !@fs.path_exists(root) else { fail("fresh formal root required") }
  let hw = @fp.banked_dot_product()
  let e = @sv.emit_design(@ir.Design::single("bf16-fp32-banked-dot/v1", hw))
  let ports : Array[String] = []
  for n in hw.nodes() {
    if n.kind() is Input(name) {
      ports.push("input wire " + range(n.signal_type().width().bits()) + name)
    }
  }
  let text = StringBuilder()
  text.write_string("module fp_banked_formal(" + ports.join(",") + ");\n")
  for p in hw.outputs() {
    text.write_string(
      "wire " + range(p.signal_type().width().bits()) + p.name() + ";\n",
    )
  }
  text.write_string(
    instance(hw, e, "dut", x => {
      if negative && x == "start" {
        "1'b0"
      } else {
        x
      }
    }),
  )
  text.write_string(
    (
      #|reg past_valid=0;
      #|reg [10:0] captured_count;
      #|wire accepted=start && !busy && !load && length>=1 && length<=1024;
      #|always @(posedge clock) begin
      #|  past_valid<=1;
      #|  if (!past_valid) assume(reset);
      #|  if (reset) captured_count<=0;
      #|  else if (accepted) captured_count<=length;
      #|  if (past_valid && !$past(reset)) begin
      #|    p_no_busy_done: assert(!(busy && done));
      #|    p_no_busy_error: assert(!(busy && error));
      #|    if ($past(accepted)) begin
      #|      p_start_busy: assert(busy && !done && !error);
      #|      p_start_counter: assert(cycles==0);
      #|    end else if ($past(busy)) begin
      #|      p_counter: assert(cycles==$past(cycles)+1);
      #|      if ($past(cycles)==5*captured_count+3) begin
      #|        p_complete: assert(!busy && done);
      #|      end else begin
      #|        p_owned: assert(busy);
      #|      end
      #|    end
      #|  end
      #|end
      #|
    ),
  )
  for lane in 0..<8 {
    let result = "result_" + lane.to_string()
    text.write_string(
      "always @(posedge clock) if(past_valid && !$past(reset)) begin\n",
    )
    text.write_string(
      "if($past(accepted)) p_clear_" +
      lane.to_string() +
      ": assert(" +
      result +
      "==0);\n",
    )
    text.write_string(
      "else if($past(busy) && ($past(cycles)<8 || (($past(cycles)-8)%5)!=0)) p_hold_" +
      lane.to_string() +
      ": assert(" +
      result +
      "==$past(" +
      result +
      "));\nend\n",
    )
  }
  text.write_string("endmodule\n")
  @fs.create_dir(root)
  @fs.write_string_to_file(root + "/dut.sv", normalize(optimized(e.source())))
  @fs.write_string_to_file(root + "/formal.sv", text.to_string())
  @fs.write_string_to_file(
    root + "/job.sby",
    "[options]\nmode bmc\ndepth 32\ntimeout 600\nexpect " +
    (if negative { "fail" } else { "pass" }) +
    "\n[engines]\nsmtbmc bitwuzla\n[script]\nread_verilog -formal -sv dut.sv formal.sv\nprep -top fp_banked_formal\n[files]\ndut.sv\nformal.sv\n",
  )
  @fs.write_string_to_file(
    root + "/claim.txt",
    "BMC32 of actual eight-lane emitted core: initial reset only, otherwise free inputs and memories. 23 control/counter/ownership/result-clear/result-hold assertions. Includes pipeline drain and short-job completion; not K1024 completion or IEEE arithmetic proof. Negative ties only DUT start low, preserving accepted shadow.\n",
  )
}
