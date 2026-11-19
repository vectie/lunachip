// Vendor pin/clock/MIG/JTAG boundary derived from the sealed standalone target.

///|
fn physical_header() -> String {
  (
    #|`default_nettype none
    #|module prx100_fpd_top(input wire clk50,input wire reset_n,
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
  )
}

///|
fn physical_tail() -> String {
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
  ) +
  jtag_boundary() +
  "endmodule\n`default_nettype wire\n"
}
