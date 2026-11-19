///|
fn width(w : Int32) -> String {
  if w == 1 {
    ""
  } else {
    "[" + (w - 1).to_string() + ":0] "
  }
}

///|
// Vivado requires explicit input net kind under default_nettype none.
fn vendor_source(source : String) -> String {
  source
  .split("\n")
  .map(line => {
    if line.has_prefix("  input logic ") {
      "  input wire logic " + line[14:].to_owned()
    } else {
      line.to_owned()
    }
  })
  .join("\n")
}

///|
fn mapped(
  e : @sv.EmittedDesign,
  name : String,
  kind : @sv.SymbolKind,
) -> String {
  e
  .manifest()
  .mappings()
  .iter()
  .find_first(x => x.source_name() == name && x.kind() == kind)
  .unwrap()
  .identifier()
}

///|
fn instance(
  hw : @ir.Module,
  e : @sv.EmittedDesign,
  label : String,
  net : (String) -> String,
) -> String {
  let con : Array[String] = []
  for n in hw.nodes() {
    if n.kind() is Input(name) {
      con.push("." + mapped(e, name, InputPort) + "(" + net(name) + ")")
    }
  }
  for p in hw.outputs() {
    con.push("." + mapped(e, p.name(), OutputPort) + "(" + net(p.name()) + ")")
  }
  "  " +
  e.modules()[0].identifier() +
  " " +
  label +
  "(" +
  con.join(",") +
  ");\n"
}

///|
fn export_target(root : String, parallel~ : Bool = false) -> Unit raise {
  guard !@fs.path_exists(root) else { fail("fresh output root required") }
  @fs.create_dir(root)
  let hw = if parallel { @fp.parallel_dot_product() } else { @fp.dot_product() }
  let design = @ir.Design::single(
    if parallel {
      "bf16-fp32-parallel-dot/v1"
    } else {
      "bf16-fp32-dot/v1"
    },
    hw,
  )
  let e = @sv.emit_design(design)
  let control = if parallel {
    @target.parallel_controller()
  } else {
    @target.controller()
  }
  let cd = @ir.Design::single(
    if parallel {
      "prx100-fp-parallel-control/v1"
    } else {
      "prx100-fp-control/v1"
    },
    control,
  )
  let ce = @sv.emit_design(cd)
  @fs.write_string_to_file(root + "/dot.lcir", @codec.serialize(design))
  @fs.write_string_to_file(root + "/control.lcir", @codec.serialize(cd))
  @fs.write_string_to_file(root + "/dot.raw.sv", e.source())
  @fs.write_string_to_file(root + "/control.raw.sv", ce.source())
  @fs.write_string_to_file(root + "/dot.sv", vendor_source(e.source()))
  @fs.write_string_to_file(root + "/control.sv", vendor_source(ce.source()))
  @fs.write_string_to_file(
    root + "/dot.names",
    e.manifest().to_canonical_text(),
  )
  @fs.write_string_to_file(
    root + "/control.names",
    ce.manifest().to_canonical_text(),
  )
  let text = StringBuilder()
  text.write_string(
    (
      #|`default_nettype none
      #|module prx100_fp_top(input wire clk50,input wire reset_n);
      #|wire clock_raw,clock,cfg_eos;
      #|IBUF clk_i(.I(clk50),.O(clock_raw));
      #|BUFG clk_b(.I(clock_raw),.O(clock));
      #|STARTUPE2 #(.PROG_USR("FALSE"),.SIM_CCLK_FREQ(0.0)) startup_i(
      #|.CFGCLK(),.CFGMCLK(),.EOS(cfg_eos),.PREQ(),.CLK(1'b0),.GSR(1'b0),.GTS(1'b0),.KEYCLEARB(1'b1),
      #|.PACK(1'b0),.USRCCLKO(1'b0),.USRCCLKTS(1'b1),.USRDONEO(1'b1),.USRDONETS(1'b1));
      #|(* ASYNC_REG="TRUE", SHREG_EXTRACT="NO" *) reg [3:0] reset_pipe=4'b1111;
      #|always @(posedge clock or negedge reset_n or negedge cfg_eos)
      #|if(!reset_n || !cfg_eos) reset_pipe<=4'b1111; else reset_pipe<={reset_pipe[2:0],1'b0};
      #|wire reset=reset_pipe[3];
      #|
    ),
  )
  for n in control.nodes() {
    if n.kind() is Input(name) && name != "clock" && name != "reset" {
      text.write_string(
        "wire " + width(n.signal_type().width().bits()) + name + ";\n",
      )
    }
  }
  for p in control.outputs() {
    text.write_string(
      "wire " + width(p.signal_type().width().bits()) + p.name() + ";\n",
    )
  }
  text.write_string(instance(control, ce, "control_i", x => x))
  text.write_string(
    instance(hw, e, "dot_i", name => {
      if hw.outputs().iter().any(p => p.name() == name) {
        "c_" + name
      } else {
        name
      }
    }),
  )
  text.write_string(
    (
      #|prx100_fp_jtag jtag_i(.aclk(clock),.aresetn(!reset),
      #|.m_axi_awaddr(s_axi_awaddr),.m_axi_awprot(),.m_axi_awvalid(s_axi_awvalid),.m_axi_awready(s_axi_awready),
      #|.m_axi_wdata(s_axi_wdata),.m_axi_wstrb(s_axi_wstrb),.m_axi_wvalid(s_axi_wvalid),.m_axi_wready(s_axi_wready),
      #|.m_axi_bresp(s_axi_bresp),.m_axi_bvalid(s_axi_bvalid),.m_axi_bready(s_axi_bready),
      #|.m_axi_araddr(s_axi_araddr),.m_axi_arprot(),.m_axi_arvalid(s_axi_arvalid),.m_axi_arready(s_axi_arready),
      #|.m_axi_rdata(s_axi_rdata),.m_axi_rresp(s_axi_rresp),.m_axi_rvalid(s_axi_rvalid),.m_axi_rready(s_axi_rready));
      #|endmodule
      #|`default_nettype wire
      #|
    ),
  )
  @fs.write_string_to_file(root + "/prx100_fp_top.sv", text.to_string())
}
