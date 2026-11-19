///|
pub(all) struct Artifact {
  path : String
  content : String
} derive(Eq, @debug.Debug)

///|
pub extend Artifact with Eq::{equal, not_equal}

///|
pub extend Artifact with @debug.Debug::{to_repr}

///|
fn digest(text : String) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode(text)))
}

///|
fn mapped(
  e : @systemverilog.EmittedDesign,
  name : String,
  kind : @systemverilog.SymbolKind,
) -> String raise {
  for item in e.manifest().mappings() {
    if item.kind() == kind && item.source_name() == name {
      return item.identifier()
    }
  }
  fail("missing emitted symbol " + name)
}

///|
fn optimized(source : String) -> String raise {
  let lines = source.split("\n").to_array()
  let out : Array[String] = []
  for i = 0; i < lines.length(); {
    let line = lines[i]
    if line.has_prefix("  function automatic logic lc_fn_eq_w") {
      for j = i; j < i + 4; j = j + 1 {
        out.push(lines[j].to_owned())
      }
      let name = line.split("logic ").to_array()[1].split("(").to_array()[0].to_owned()
      out.push("    " + name + " = (a == b);")
      let mut last = i + 4
      while last < lines.length() && lines[last] != "  endfunction" {
        last = last + 1
      }
      guard last < lines.length() else { fail("unterminated equality helper") }
      out.push("  endfunction")
      continue last + 1
    }
    out.push(
      if line.has_prefix("  input logic ") {
        "  input wire logic " + line[14:].to_owned()
      } else {
        line.to_owned()
      },
    )
    continue i + 1
  }
  out.join("\n")
}

///|
fn width(w : Int32) -> String {
  if w == 1 {
    ""
  } else {
    "[" + (w - 1).to_string() + ":0] "
  }
}

///|
fn wrapper(hw : @ir.Module, e : @systemverilog.EmittedDesign) -> String raise {
  let text = StringBuilder()
  text.write_string(
    (
      #|`default_nettype none
      #|module prx100_ddr_top(input wire clk50,input wire reset_n,
      #|  inout wire [15:0] ddr3_dq,inout wire [1:0] ddr3_dqs_p,inout wire [1:0] ddr3_dqs_n,
      #|  output wire [13:0] ddr3_addr,output wire [2:0] ddr3_ba,
      #|  output wire ddr3_ras_n,ddr3_cas_n,ddr3_we_n,ddr3_reset_n,
      #|  output wire [0:0] ddr3_ck_p,ddr3_ck_n,ddr3_cke,ddr3_odt,output wire [1:0] ddr3_dm);
      #|  wire clk50_raw,clk50_global,clk200,ref_locked,ui_clk,ui_reset,calibrated,cfg_eos;
      #|  IBUF clk50_input(.I(clk50),.O(clk50_raw));
      #|  BUFG clk50_buffer(.I(clk50_raw),.O(clk50_global));
      #|  prx100_ddr_refclock refclock_i(.clk_in1(clk50_global),.clk_out1(clk200),.locked(ref_locked),.reset(1'b0));
      #|  STARTUPE2 #(.PROG_USR("FALSE"),.SIM_CCLK_FREQ(0.0)) startup_i(
      #|    .CFGCLK(),.CFGMCLK(),.EOS(cfg_eos),.PREQ(),.CLK(1'b0),.GSR(1'b0),.GTS(1'b0),.KEYCLEARB(1'b1),
      #|    .PACK(1'b0),.USRCCLKO(1'b0),.USRCCLKTS(1'b1),.USRDONEO(1'b1),.USRDONETS(1'b1));
      #|  (* ASYNC_REG="TRUE" *) reg [3:0] reset_pipe=4'b1111;
      #|  always @(posedge clk50_global or negedge reset_n or negedge cfg_eos)
      #|    if(!reset_n || !cfg_eos) reset_pipe<=4'b1111; else reset_pipe<={reset_pipe[2:0],1'b0};
      #|  wire system_reset=reset_pipe[3] || !ref_locked;
      #|
    ),
  )
  for node in hw.nodes() {
    if node.kind() is Input(name) &&
      name != "clock" &&
      name != "reset" &&
      name != "calibrated" {
      text.write_string(
        "  wire " + width(node.signal_type().width().bits()) + name + ";\n",
      )
    }
  }
  for port in hw.outputs() {
    text.write_string(
      "  wire " + width(port.signal_type().width().bits()) + port.name() + ";\n",
    )
  }
  let con : Array[String] = []
  for node in hw.nodes() {
    if node.kind() is Input(name) {
      let signal = match name {
        "clock" => "ui_clk"
        "reset" => "ui_reset"
        _ => name
      }
      con.push("." + mapped(e, name, InputPort) + "(" + signal + ")")
    }
  }
  for port in hw.outputs() {
    con.push("." + mapped(e, port.name(), OutputPort) + "(" + port.name() + ")")
  }
  text.write_string(
    "  " + e.modules()[0].identifier() + " tester_i(" + con.join(",") + ");\n",
  )
  text.write_string(
    (
      #|  wire [127:0] app_rd_data;
      #|  wire [127:0] app_wdf_data={app_wdf_word3,app_wdf_word2,app_wdf_word1,app_wdf_word0};
      #|  assign app_rd_word0=app_rd_data[31:0];
      #|  assign app_rd_word1=app_rd_data[63:32];
      #|  assign app_rd_word2=app_rd_data[95:64];
      #|  assign app_rd_word3=app_rd_data[127:96];
      #|  prx100_ddr_mig mig_i(
      #|    .ddr3_dq(ddr3_dq),.ddr3_dqs_p(ddr3_dqs_p),.ddr3_dqs_n(ddr3_dqs_n),
      #|    .ddr3_addr(ddr3_addr),.ddr3_ba(ddr3_ba),.ddr3_ras_n(ddr3_ras_n),.ddr3_cas_n(ddr3_cas_n),
      #|    .ddr3_we_n(ddr3_we_n),.ddr3_reset_n(ddr3_reset_n),.ddr3_ck_p(ddr3_ck_p),.ddr3_ck_n(ddr3_ck_n),
      #|    .ddr3_cke(ddr3_cke),.ddr3_odt(ddr3_odt),.ddr3_dm(ddr3_dm),
      #|    .sys_clk_i(clk50_raw),.clk_ref_i(clk200),.sys_rst(system_reset),
      #|    .ui_clk(ui_clk),.ui_clk_sync_rst(ui_reset),.init_calib_complete(calibrated),
      #|    .app_addr(app_addr),.app_cmd(app_cmd),.app_en(app_en),.app_rdy(app_rdy),
      #|    .app_wdf_data(app_wdf_data),.app_wdf_mask(app_wdf_mask),.app_wdf_wren(app_wdf_wren),
      #|    .app_wdf_end(app_wdf_end),.app_wdf_rdy(app_wdf_rdy),
      #|    .app_rd_data(app_rd_data),.app_rd_data_valid(app_rd_data_valid),.app_rd_data_end(app_rd_data_end),
      #|    .app_sr_req(1'b0),.app_ref_req(1'b0),.app_zq_req(1'b0),.app_sr_active(),.app_ref_ack(),.app_zq_ack());
      #|  prx100_ddr_jtag jtag_i(.aclk(ui_clk),.aresetn(!ui_reset),
      #|    .m_axi_awaddr(s_axi_awaddr),.m_axi_awprot(),.m_axi_awvalid(s_axi_awvalid),.m_axi_awready(s_axi_awready),
      #|    .m_axi_wdata(s_axi_wdata),.m_axi_wstrb(s_axi_wstrb),.m_axi_wvalid(s_axi_wvalid),.m_axi_wready(s_axi_wready),
      #|    .m_axi_bresp(s_axi_bresp),.m_axi_bvalid(s_axi_bvalid),.m_axi_bready(s_axi_bready),
      #|    .m_axi_araddr(s_axi_araddr),.m_axi_arprot(),.m_axi_arvalid(s_axi_arvalid),.m_axi_arready(s_axi_arready),
      #|    .m_axi_rdata(s_axi_rdata),.m_axi_rresp(s_axi_rresp),.m_axi_rvalid(s_axi_rvalid),.m_axi_rready(s_axi_rready));
      #|endmodule
      #|`default_nettype wire
      #|
    ),
  )
  text.to_string()
}

///|
pub fn export_bundle() -> ReadOnlyArray[Artifact] raise {
  let hw = controller()
  let design = @ir.Design::single("prx100-standalone-ddr-diagnostic-v1", hw)
  let emitted = @systemverilog.emit_design(design)
  let source = emitted.modules()[0]
  let artifacts : Array[Artifact] = [
    { path: "tester.lcir", content: @codec.serialize(design), },
    { path: "tester.names", content: emitted.manifest().to_canonical_text(), },
    { path: "tester.sv", content: optimized(source.source()), },
    { path: "tester-ordinary.sv", content: source.source(), },
    { path: "prx100_ddr_top.sv", content: wrapper(hw, emitted), },
    {
      path: "prx100_ddr.xdc",
      content: (
        #|set_property PACKAGE_PIN D18 [get_ports clk50]
        #|set_property PACKAGE_PIN M4 [get_ports reset_n]
        #|set_property IOSTANDARD LVCMOS33 [get_ports {clk50 reset_n}]
        #|create_clock -name clk50 -period 20.000 [get_ports clk50]
        #|set_false_path -from [get_ports reset_n]
        #|set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets clk50_raw]
        #|
      ),
    },
    {
      path: "job.json",
      content: "{\"schema_version\":\"lunachip.yosys-job/v1\",\"top_module\":\"" +
      source.identifier() +
      "\",\"sources\":[{\"path\":\"tester.sv\",\"sha256\":\"" +
      digest(optimized(source.source())) +
      "\"}],\"formal_tasks\":[]}\n",
    },
  ]
  artifacts.push({
    path: "SHA256SUMS",
    content: artifacts
    .map(a => digest(a.content) + "  " + a.path + "\n")
    .join(""),
  })
  ReadOnlyArray::from_array(artifacts)
}
