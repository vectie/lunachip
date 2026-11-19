///|
/// Bounded controller safety at the highest legal line; bus inputs unconstrained.
pub fn formal_bundle(
  negative~ : Bool = false,
) -> ReadOnlyArray[@projection.Artifact] raise {
  let hw = @memtest.controller(beats=1U, base_address=0x7ffffff0U)
  let design = @ir.Design::single("pblaze3-memtest-boundary/v1", hw)
  let emitted = @sv.emit_design(design)
  let ports = @v.collect_ports(hw, emitted.manifest())
  let inputs = ["input wire clock"]
  let wires : Array[String] = []
  let bindings : Array[String] = []
  for p in ports {
    let width = if p.width() == 1 {
      ""
    } else {
      "[" + (p.width() - 1).to_string() + ":0] "
    }
    if p.is_input() && p.source_name() != "clock" && p.source_name() != "reset" {
      inputs.push("input wire " + width + p.source_name())
    }
    if p.is_output() {
      wires.push("wire " + width + p.source_name() + ";")
    }
    bindings.push("." + p.emitted_name() + "(" + p.source_name() + ")")
  }
  let properties = (
      #|reg [1:0] f_boot=0;
      #|always @(posedge clock) if(f_boot<2) f_boot<=f_boot+1;
      #|wire reset=f_boot<2;
      #|reg f_seen=0;
      #|always @(posedge clock) begin
      #| f_seen<=1;
      #| if(!reset) begin
      #|  assert(phase<=6);
      #|  assert(completed_writes<=1 && checked_reads<=1);
      #|  assert(!request_valid || request_address==32'h7ffffff0);
      #|  assert(!request_valid || phase==1 || phase==3);
      #|  assert(!done || (round && completed_writes==1 && checked_reads==1 && status0==32'hb0000001 && status1==32'h80000000));
      #|  assert(!failed || (!request_valid && !done && first_error_code!=0));
      #|  assert(response_ready && request_line && !request_burst && !request_wide);
      #|  if(phase==3 || phase==4 || phase==5) assert(completed_writes==1);
      #|  if(f_seen && $past(!reset && failed)) begin
      #|   assert(failed);
      #|   assert(first_error_address==$past(first_error_address));
      #|   assert(first_expected==$past(first_expected));
      #|   assert(first_actual==$past(first_actual));
      #|  end
      #|  if(f_seen && $past(!reset && phase>=1 && phase<=4 && (!calibrated || !memory_healthy))) assert(failed);
    ) +
    (if negative {
      "\nassert(!request_valid || request_address<32'h10000000);\n"
    } else {
      "\n"
    }) +
    "end\nend\n"
  let wrapper = "module pblaze3_memtest_formal(" +
    inputs.join(",\n") +
    ");\n" +
    wires.join("\n") +
    "\n" +
    emitted.modules()[0].identifier() +
    " dut(" +
    bindings.join(",\n") +
    ");\n" +
    properties +
    "endmodule\n"
  ReadOnlyArray::from_array([
    { path: "dut.sv", content: emitted.source(), },
    { path: "design.lcir", content: @codec.serialize(design), },
    { path: "formal.sv", content: wrapper, },
    {
      path: "job.sby",
      content: "[options]\nmode bmc\ndepth 40\ntimeout 600\nexpect " +
      (if negative { "fail" } else { "pass" }) +
      "\n[engines]\nsmtbmc bitwuzla\n[script]\nlogger -werror .*\nread_verilog -formal -sv dut.sv formal.sv\nprep -top pblaze3_memtest_formal\n[files]\ndut.sv\nformal.sv\n",
    },
    {
      path: "claim.txt",
      content: "40-edge bounded controller safety, highest2GiB line with one-line elaboration, arbitrary response and ready/calibration/health. Legal phases, finite counts, complete-write-before-read, pass counts/address, sticky first failure, no new requests after failure, loss-of-calibration rejection. Negative asserts false256MiB limit. No unbounded liveness, full2GiB exhaustive simulation or board claim.\n",
    },
  ])
}
