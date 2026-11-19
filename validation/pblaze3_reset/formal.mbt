///|
/// Bounded sampled-edge safety. Between-edge asynchronous behavior is exercised
/// separately by the atomic timestamp replay, not inferred from async2sync.
pub fn formal_bundle(
  negative~ : Bool = false,
) -> ReadOnlyArray[@projection.Artifact] raise {
  let hw = @reset.hardware_module()
  let design = @ir.Design::single("pblaze3-reset/v1", hw)
  let emitted = @systemverilog.emit_design(design)
  let ports = @verilator.collect_ports(hw, emitted.manifest())
  let bindings = ports
    .map(p => "." + p.emitted_name() + "(" + p.source_name() + ")")
    .join(",")
  let body =
    #|reg f_seen=0;
    #|reg [8:0] reference_edges;
    #|always @(posedge clk or posedge reset) begin
    #|  if(reset) reference_edges <= 0;
    #|  else if(reference_edges < 128) reference_edges <= reference_edges + 1;
    #|end
    #|always @(posedge clk) begin
    #|  f_seen <= 1;
    #|  if(!f_seen) assume(reset);
    #|  if(f_seen) begin
    #|    assert(reference_edges <= 128);
    #|    assert(release_n == (reference_edges == 128));
    #|    if(reset) assert(!release_n);
    #|  end
    #|end
    #|
  let bad = if negative {
    "always @(posedge clk) if(f_seen && !reset && reference_edges == 127) assert(release_n);\n"
  } else {
    ""
  }
  let wrapper = "module pblaze3_reset_formal(input wire clk,input wire reset);\nwire release_n;\n" +
    emitted.modules()[0].identifier() +
    " dut(" +
    bindings +
    ");\n" +
    body +
    bad +
    "endmodule\n"
  ReadOnlyArray::from_array([
    { path: "dut.sv", content: emitted.source(), },
    { path: "design.lcir", content: @codec.serialize(design), },
    { path: "formal.sv", content: wrapper, },
    {
      path: "job.sby",
      content: "[options]\nmode bmc\ndepth 260\ntimeout 600\nexpect " +
      (if negative { "fail" } else { "pass" }) +
      "\n[engines]\nsmtbmc bitwuzla\n[script]\nlogger -werror .*\nread_verilog -formal -sv dut.sv formal.sv\nprep -top pblaze3_reset_formal\nasync2sync\ndffunmap\n[files]\ndut.sv\nformal.sv\n",
    },
    {
      path: "claim.txt",
      content: "260 sampled rising-edge bounded safety, initial reset assumption then arbitrary reset. Independent9bit reference edge counter; no release before128, release at128, saturation and restart. Negative demands release at127 and must produce a counterexample. async2sync models sampled-edge semantics; drives-only asynchronous assertion and clock halt are separately validated by RTL/LunaWave replay. No XPM/analog/metastability/timing claim.\n",
    },
  ])
}
