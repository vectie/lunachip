///|
/// Vendor CDC primitive wrapper; this physical boundary is not arithmetic RTL.
/// Low calibration does not reset or discard accepted transactions. The
/// portable bridge receives synchronized health and owns poison/drain policy.
pub fn calibration_wrapper() -> String {
  (
    #|module pblaze3_calib_sync (
    #|  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 dest_clk CLK", X_INTERFACE_PARAMETER = "XIL_INTERFACENAME dest_clk, FREQ_HZ 33333333" *)
    #|  input wire dest_clk,
    #|  input wire src_in,
    #|  output wire dest_out
    #|);
    #|  xpm_cdc_single #(
    #|    .DEST_SYNC_FF(3), .INIT_SYNC_FF(1), .SIM_ASSERT_CHK(1), .SRC_INPUT_REG(0)
    #|  ) calibration_cdc (
    #|    .src_clk(1'b0), .src_in(src_in), .dest_clk(dest_clk), .dest_out(dest_out)
    #|  );
    #|endmodule
    #|
  )
}

///|
/// Three independent status flags; no multi-bit encoded state crosses here.
/// GPIO channel2 DATA at BAR-relative0x8 exposes status[2:0] read-only.
pub fn smoke_status_wrapper() -> String {
  (
    #|module pblaze3_smoke_status_sync (
    #|  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 dest_clk CLK", X_INTERFACE_PARAMETER = "XIL_INTERFACENAME dest_clk, FREQ_HZ 250000000" *)
    #|  input wire dest_clk,
    #|  input wire calibrated,
    #|  input wire link_up,
    #|  input wire ui_reset_released,
    #|  output wire [2:0] status
    #|);
    #|  xpm_cdc_array_single #(
    #|    .DEST_SYNC_FF(3), .INIT_SYNC_FF(1), .SIM_ASSERT_CHK(1),
    #|    .SRC_INPUT_REG(0), .WIDTH(3)
    #|  ) status_cdc (
    #|    .src_clk(1'b0), .src_in({ui_reset_released, link_up, calibrated}),
    #|    .dest_clk(dest_clk), .dest_out(status)
    #|  );
    #|endmodule
    #|
  )
}

///|
/// The XPM owns asynchronous assertion and synchronized recovery. The
/// canonical MoonBit counter owns the minimum 128-cycle reset duration.
/// The clock comes from the board oscillator's MMCM, never from XDMA.
fn emitted_reset() -> @sv.EmittedDesign raise {
  let design = @ir.Design::single(
    "pblaze3_transport_reset_core",
    @reset.hardware_module(),
  )
  @sv.emit_design(design)
}

///|
pub fn transport_reset_core_source() -> String raise {
  // Vivado requires an explicit input net kind under default_nettype none.
  // Match the established PRX/PBlaze target normalization; preserve the
  // portable emission separately for exact semantic/source comparison.
  emitted_reset()
  .source()
  .split("\n")
  .map(line => {
    if line.has_prefix("  input logic ") {
      "  input wire logic " + line[14:].to_owned()
    } else {
      line.to_owned()
    }
  })
  .to_array()
  .join("\n")
}

///|
pub fn transport_reset_ordinary_source() -> String raise {
  emitted_reset().source()
}

///|
pub fn transport_reset_wrapper() -> String raise {
  let emitted = emitted_reset()
  fn port(name : String, kind : @sv.SymbolKind) -> String raise {
    for mapping in emitted.manifest().mappings() {
      if mapping.source_name() == name && mapping.kind() == kind {
        return mapping.identifier()
      }
    }
    fail("missing emitted reset supervisor port: \{name}")
  }
  let instance = emitted.modules()[0].identifier() +
    " hold_i(." +
    port("clk", InputPort) +
    "(clock50), ." +
    port("reset", InputPort) +
    "(fault_sync), ." +
    port("release_n", OutputPort) +
    "(released_n));\n"
  (
    #|module pblaze3_transport_reset (
    #|  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clock50 CLK", X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clock50, FREQ_HZ 50000000" *)
    #|  input wire clock50,
    #|  input wire healthy,
    #|  output wire released_n
    #|);
    #|  wire fault_sync;
    #|  xpm_cdc_async_rst #(
    #|    .DEST_SYNC_FF(3), .INIT_SYNC_FF(1), .RST_ACTIVE_HIGH(1)
    #|  ) fault_cdc (
    #|    .src_arst(~healthy), .dest_clk(clock50), .dest_arst(fault_sync)
    #|  );
    #|
  ) +
  instance +
  "endmodule\n"
}
