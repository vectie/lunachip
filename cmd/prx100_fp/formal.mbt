///|
fn formal_bundle(root : String, negative : Bool) -> Unit raise {
  guard !@fs.path_exists(root) else { fail("fresh formal root required") }
  let hw = @fp.dot_product()
  let e = @sv.emit_design(@ir.Design::single("bf16-fp32-dot/v1", hw))
  let ports : Array[String] = []
  for n in hw.nodes() {
    if n.kind() is Input(name) {
      ports.push("input wire " + width(n.signal_type().width().bits()) + name)
    }
  }
  let text = StringBuilder()
  text.write_string("module fp_formal(" + ports.join(",") + ");\n")
  for p in hw.outputs() {
    text.write_string(
      "wire " + width(p.signal_type().width().bits()) + p.name() + ";\n",
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
      #|      p_start_clear: assert(cycles==0 && result==0);
      #|    end else if ($past(busy)) begin
      #|      p_counter: assert(cycles==$past(cycles)+1);
      #|      if ($past(cycles)==4*captured_count-1) begin
      #|        p_complete: assert(!busy && done);
      #|      end else begin
      #|        p_owned: assert(busy);
      #|      end
      #|      if ($past(cycles[1:0])!=2) begin
      #|        p_sum_hold: assert(result==$past(result));
      #|      end
      #|    end
      #|  end
      #|end
      #|endmodule
      #|
    ),
  )
  @fs.create_dir(root)
  @fs.write_string_to_file(root + "/dut.sv", vendor_source(e.source()))
  @fs.write_string_to_file(root + "/formal.sv", text.to_string())
  @fs.write_string_to_file(
    root + "/job.sby",
    "[options]\nmode bmc\ndepth 32\ntimeout 120\nexpect " +
    (if negative { "fail" } else { "pass" }) +
    "\n[engines]\nsmtbmc bitwuzla\n[script]\nread_verilog -formal -sv dut.sv formal.sv\nprep -top fp_formal\n[files]\ndut.sv\nformal.sv\n",
  )
  @fs.write_string_to_file(
    root + "/claim.txt",
    "BMC32, single rising clock. Only initial reset assumed; inputs/memory otherwise unconstrained. Eight control/counter/ownership assertions, no floating-point arithmetic equivalence theorem. Bound covers short jobs, not a full K1024 dot. Negative ties only DUT start low, preserves original accepted shadow.\n",
  )
}
