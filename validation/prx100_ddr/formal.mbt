///|
/// Bounded digital checks with free AXI/MIG inputs and only initial reset.
/// The negative variant bypasses calibration at the DUT input only.
pub fn formal_bundle(
  negative~ : Bool = false,
) -> ReadOnlyArray[@ddr.Artifact] raise {
  let hw = @ddr.controller()
  let e = @systemverilog.emit_design(
    @ir.Design::single("prx100-standalone-ddr-diagnostic-v1", hw),
  )
  let ports = @verilator.collect_ports(hw, e.manifest())
  let declarations : Array[String] = []
  let wires : Array[String] = []
  let connections : Array[String] = []
  for p in ports {
    let range = if p.width() == 1 {
      ""
    } else {
      "[" + (p.width() - 1).to_string() + ":0] "
    }
    if p.is_input() {
      declarations.push("input wire " + range + p.source_name())
    } else {
      wires.push("wire " + range + p.source_name() + ";")
    }
    let signal = if negative && p.source_name() == "calibrated" {
      "1'b1"
    } else {
      p.source_name()
    }
    connections.push("." + p.emitted_name() + "(" + signal + ")")
  }
  let assertions =
    #|reg f_seen=1'b0;
    #|initial assume(reset);
    #|always @(posedge clock) f_seen<=1'b1;
    #|always @(posedge clock) if(f_seen && !reset) begin
    #|  p_calibration_gate: assert(calibrated || (!app_en && !app_wdf_wren));
    #|  p_native_address: assert(app_addr[2:0]==0 && app_addr[27]==0);
    #|  p_read_credit: assert(test_checked<=test_reads && test_reads-test_checked<=25'd16);
    #|  p_write_fork: assert(test_writes>=test_data_beats ? test_writes-test_data_beats<=1 : test_data_beats-test_writes<=1);
    #|  if($past(s_axi_rvalid && !s_axi_rready && !reset)) begin
    #|    p_read_hold: assert(s_axi_rvalid && s_axi_rdata==$past(s_axi_rdata) && s_axi_rresp==$past(s_axi_rresp));
    #|  end
    #|  if($past(s_axi_bvalid && !s_axi_bready && !reset)) begin
    #|    p_write_hold: assert(s_axi_bvalid && s_axi_bresp==$past(s_axi_bresp));
    #|  end
    #|end
  let wrapper = "module prx100_ddr_formal(" +
    declarations.join(",\n") +
    ");\n" +
    wires.join("\n") +
    "\n" +
    e.modules()[0].identifier() +
    " dut(" +
    connections.join(",\n") +
    ");\n" +
    assertions +
    "\nendmodule\n"
  let bundle = @ddr.export_bundle()
  let source = bundle[bundle.search_by(a => a.path == "tester.sv").unwrap()].content
  let job = "[options]\nmode bmc\ndepth 32\ntimeout 300\nexpect " +
    (if negative { "fail" } else { "pass" }) +
    "\n[engines]\nsmtbmc bitwuzla\n[script]\nread_verilog -formal -sv tester.sv formal.sv\nprep -top prx100_ddr_formal\n[files]\ntester.sv\nformal.sv\n"
  ReadOnlyArray::from_array([
    { path: "tester.sv", content: source, },
    { path: "formal.sv", content: wrapper, },
    { path: "job.sby", content: job, },
    {
      path: "claim.txt",
      content: "Bounded32-clock digital safety, initial reset only; free AXI and MIG inputs. Negative bypasses the DUT calibration gate. No memory-device, liveness, analog or unbounded claim.\n",
    },
  ])
}
