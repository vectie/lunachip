if {[catch {
set work /work/builds/pblaze3-ila-passive-probe-20261028-a2
if {[file exists $work]} {error {fresh guest evidence required}}
file mkdir $work
cd $work
set_param general.maxThreads 1
set fd [open passive.v w];puts $fd {module full_master(
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK", X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk, ASSOCIATED_BUSIF AXI, FREQ_HZ 200000000" *) input wire clk,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWADDR", X_INTERFACE_MODE = "master", X_INTERFACE_PARAMETER = "XIL_INTERFACENAME AXI, PROTOCOL AXI4, ADDR_WIDTH 32, DATA_WIDTH 128, ID_WIDTH 5" *) output wire [31:0] AWADDR,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWVALID" *) output wire AWVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWREADY" *) input wire AWREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWPROT" *) output wire [2:0] AWPROT,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWID" *) output wire [4:0] AWID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWLEN" *) output wire [7:0] AWLEN,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWSIZE" *) output wire [2:0] AWSIZE,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWBURST" *) output wire [1:0] AWBURST,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWLOCK" *) output wire AWLOCK,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWCACHE" *) output wire [3:0] AWCACHE,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWQOS" *) output wire [3:0] AWQOS,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARADDR" *) output wire [31:0] ARADDR,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARVALID" *) output wire ARVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARREADY" *) input wire ARREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARPROT" *) output wire [2:0] ARPROT,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARID" *) output wire [4:0] ARID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARLEN" *) output wire [7:0] ARLEN,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARSIZE" *) output wire [2:0] ARSIZE,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARBURST" *) output wire [1:0] ARBURST,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARLOCK" *) output wire ARLOCK,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARCACHE" *) output wire [3:0] ARCACHE,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARQOS" *) output wire [3:0] ARQOS,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WVALID" *) output wire WVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WREADY" *) input wire WREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WDATA" *) output wire [127:0] WDATA,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WSTRB" *) output wire [15:0] WSTRB,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI BVALID" *) input wire BVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI BREADY" *) output wire BREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI BRESP" *) input wire [1:0] BRESP,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RVALID" *) input wire RVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RREADY" *) output wire RREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RRESP" *) input wire [1:0] RRESP,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RDATA" *) input wire [127:0] RDATA,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WLAST" *) output wire WLAST,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI BID" *) input wire [4:0] BID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RID" *) input wire [4:0] RID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RLAST" *) input wire RLAST,
output wire [421:0] captured);
assign captured = {RLAST,RID,BID,WLAST,RDATA,RRESP,RREADY,RVALID,BRESP,BREADY,BVALID,WSTRB,WDATA,WREADY,WVALID,ARQOS,ARCACHE,ARLOCK,ARBURST,ARSIZE,ARLEN,ARID,ARPROT,ARREADY,ARVALID,ARADDR,AWQOS,AWCACHE,AWLOCK,AWBURST,AWSIZE,AWLEN,AWID,AWPROT,AWREADY,AWVALID,AWADDR};
assign AWADDR = 32'd0;
assign AWVALID = 1'd0;
assign AWPROT = 3'd0;
assign AWID = 5'd0;
assign AWLEN = 8'd0;
assign AWSIZE = 3'd0;
assign AWBURST = 2'd0;
assign AWLOCK = 1'd0;
assign AWCACHE = 4'd0;
assign AWQOS = 4'd0;
assign ARADDR = 32'd0;
assign ARVALID = 1'd0;
assign ARPROT = 3'd0;
assign ARID = 5'd0;
assign ARLEN = 8'd0;
assign ARSIZE = 3'd0;
assign ARBURST = 2'd0;
assign ARLOCK = 1'd0;
assign ARCACHE = 4'd0;
assign ARQOS = 4'd0;
assign WVALID = 1'd0;
assign WDATA = 128'd0;
assign WSTRB = 16'd0;
assign BREADY = 1'd0;
assign RREADY = 1'd0;
assign WLAST = 1'd0;
endmodule
module full_slave(
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK", X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk, ASSOCIATED_BUSIF AXI, FREQ_HZ 200000000" *) input wire clk,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWADDR", X_INTERFACE_MODE = "slave", X_INTERFACE_PARAMETER = "XIL_INTERFACENAME AXI, PROTOCOL AXI4, ADDR_WIDTH 32, DATA_WIDTH 128, ID_WIDTH 5" *) input wire [31:0] AWADDR,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWVALID" *) input wire AWVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWREADY" *) output wire AWREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWPROT" *) input wire [2:0] AWPROT,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWID" *) input wire [4:0] AWID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWLEN" *) input wire [7:0] AWLEN,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWSIZE" *) input wire [2:0] AWSIZE,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWBURST" *) input wire [1:0] AWBURST,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWLOCK" *) input wire AWLOCK,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWCACHE" *) input wire [3:0] AWCACHE,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWQOS" *) input wire [3:0] AWQOS,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARADDR" *) input wire [31:0] ARADDR,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARVALID" *) input wire ARVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARREADY" *) output wire ARREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARPROT" *) input wire [2:0] ARPROT,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARID" *) input wire [4:0] ARID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARLEN" *) input wire [7:0] ARLEN,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARSIZE" *) input wire [2:0] ARSIZE,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARBURST" *) input wire [1:0] ARBURST,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARLOCK" *) input wire ARLOCK,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARCACHE" *) input wire [3:0] ARCACHE,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARQOS" *) input wire [3:0] ARQOS,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WVALID" *) input wire WVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WREADY" *) output wire WREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WDATA" *) input wire [127:0] WDATA,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WSTRB" *) input wire [15:0] WSTRB,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI BVALID" *) output wire BVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI BREADY" *) input wire BREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI BRESP" *) output wire [1:0] BRESP,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RVALID" *) output wire RVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RREADY" *) input wire RREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RRESP" *) output wire [1:0] RRESP,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RDATA" *) output wire [127:0] RDATA,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WLAST" *) input wire WLAST,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI BID" *) output wire [4:0] BID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RID" *) output wire [4:0] RID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RLAST" *) output wire RLAST,
output wire [421:0] captured);
assign captured = {RLAST,RID,BID,WLAST,RDATA,RRESP,RREADY,RVALID,BRESP,BREADY,BVALID,WSTRB,WDATA,WREADY,WVALID,ARQOS,ARCACHE,ARLOCK,ARBURST,ARSIZE,ARLEN,ARID,ARPROT,ARREADY,ARVALID,ARADDR,AWQOS,AWCACHE,AWLOCK,AWBURST,AWSIZE,AWLEN,AWID,AWPROT,AWREADY,AWVALID,AWADDR};
assign AWREADY = 1'd0;
assign ARREADY = 1'd0;
assign WREADY = 1'd0;
assign BVALID = 1'd0;
assign BRESP = 2'd0;
assign RVALID = 1'd0;
assign RRESP = 2'd0;
assign RDATA = 128'd0;
assign BID = 5'd0;
assign RID = 5'd0;
assign RLAST = 1'd0;
endmodule
module full_monitor(
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK", X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk, ASSOCIATED_BUSIF AXI, FREQ_HZ 200000000" *) input wire clk,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWADDR", X_INTERFACE_MODE = "monitor", X_INTERFACE_PARAMETER = "XIL_INTERFACENAME AXI, PROTOCOL AXI4, ADDR_WIDTH 32, DATA_WIDTH 128, ID_WIDTH 5" *) input wire [31:0] AWADDR,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWVALID" *) input wire AWVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWREADY" *) input wire AWREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWPROT" *) input wire [2:0] AWPROT,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWID" *) input wire [4:0] AWID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWLEN" *) input wire [7:0] AWLEN,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWSIZE" *) input wire [2:0] AWSIZE,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWBURST" *) input wire [1:0] AWBURST,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWLOCK" *) input wire AWLOCK,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWCACHE" *) input wire [3:0] AWCACHE,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWQOS" *) input wire [3:0] AWQOS,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARADDR" *) input wire [31:0] ARADDR,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARVALID" *) input wire ARVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARREADY" *) input wire ARREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARPROT" *) input wire [2:0] ARPROT,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARID" *) input wire [4:0] ARID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARLEN" *) input wire [7:0] ARLEN,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARSIZE" *) input wire [2:0] ARSIZE,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARBURST" *) input wire [1:0] ARBURST,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARLOCK" *) input wire ARLOCK,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARCACHE" *) input wire [3:0] ARCACHE,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARQOS" *) input wire [3:0] ARQOS,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WVALID" *) input wire WVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WREADY" *) input wire WREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WDATA" *) input wire [127:0] WDATA,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WSTRB" *) input wire [15:0] WSTRB,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI BVALID" *) input wire BVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI BREADY" *) input wire BREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI BRESP" *) input wire [1:0] BRESP,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RVALID" *) input wire RVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RREADY" *) input wire RREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RRESP" *) input wire [1:0] RRESP,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RDATA" *) input wire [127:0] RDATA,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WLAST" *) input wire WLAST,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI BID" *) input wire [4:0] BID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RID" *) input wire [4:0] RID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RLAST" *) input wire RLAST,
output wire [421:0] captured);
assign captured = {RLAST,RID,BID,WLAST,RDATA,RRESP,RREADY,RVALID,BRESP,BREADY,BVALID,WSTRB,WDATA,WREADY,WVALID,ARQOS,ARCACHE,ARLOCK,ARBURST,ARSIZE,ARLEN,ARID,ARPROT,ARREADY,ARVALID,ARADDR,AWQOS,AWCACHE,AWLOCK,AWBURST,AWSIZE,AWLEN,AWID,AWPROT,AWREADY,AWVALID,AWADDR};
endmodule
module lite_master(
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK", X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk, ASSOCIATED_BUSIF AXI, FREQ_HZ 200000000" *) input wire clk,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWADDR", X_INTERFACE_MODE = "master", X_INTERFACE_PARAMETER = "XIL_INTERFACENAME AXI, PROTOCOL AXI4LITE, ADDR_WIDTH 32, DATA_WIDTH 32, ID_WIDTH 0" *) output wire [31:0] AWADDR,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWVALID" *) output wire AWVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWREADY" *) input wire AWREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWPROT" *) output wire [2:0] AWPROT,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARADDR" *) output wire [31:0] ARADDR,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARVALID" *) output wire ARVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARREADY" *) input wire ARREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARPROT" *) output wire [2:0] ARPROT,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WVALID" *) output wire WVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WREADY" *) input wire WREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WDATA" *) output wire [31:0] WDATA,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WSTRB" *) output wire [3:0] WSTRB,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI BVALID" *) input wire BVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI BREADY" *) output wire BREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI BRESP" *) input wire [1:0] BRESP,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RVALID" *) input wire RVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RREADY" *) output wire RREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RRESP" *) input wire [1:0] RRESP,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RDATA" *) input wire [31:0] RDATA,
output wire [151:0] captured);
assign captured = {RDATA,RRESP,RREADY,RVALID,BRESP,BREADY,BVALID,WSTRB,WDATA,WREADY,WVALID,ARPROT,ARREADY,ARVALID,ARADDR,AWPROT,AWREADY,AWVALID,AWADDR};
assign AWADDR = 32'd0;
assign AWVALID = 1'd0;
assign AWPROT = 3'd0;
assign ARADDR = 32'd0;
assign ARVALID = 1'd0;
assign ARPROT = 3'd0;
assign WVALID = 1'd0;
assign WDATA = 32'd0;
assign WSTRB = 4'd0;
assign BREADY = 1'd0;
assign RREADY = 1'd0;
endmodule
module lite_slave(
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK", X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk, ASSOCIATED_BUSIF AXI, FREQ_HZ 200000000" *) input wire clk,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWADDR", X_INTERFACE_MODE = "slave", X_INTERFACE_PARAMETER = "XIL_INTERFACENAME AXI, PROTOCOL AXI4LITE, ADDR_WIDTH 32, DATA_WIDTH 32, ID_WIDTH 0" *) input wire [31:0] AWADDR,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWVALID" *) input wire AWVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWREADY" *) output wire AWREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWPROT" *) input wire [2:0] AWPROT,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARADDR" *) input wire [31:0] ARADDR,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARVALID" *) input wire ARVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARREADY" *) output wire ARREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARPROT" *) input wire [2:0] ARPROT,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WVALID" *) input wire WVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WREADY" *) output wire WREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WDATA" *) input wire [31:0] WDATA,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WSTRB" *) input wire [3:0] WSTRB,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI BVALID" *) output wire BVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI BREADY" *) input wire BREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI BRESP" *) output wire [1:0] BRESP,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RVALID" *) output wire RVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RREADY" *) input wire RREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RRESP" *) output wire [1:0] RRESP,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RDATA" *) output wire [31:0] RDATA,
output wire [151:0] captured);
assign captured = {RDATA,RRESP,RREADY,RVALID,BRESP,BREADY,BVALID,WSTRB,WDATA,WREADY,WVALID,ARPROT,ARREADY,ARVALID,ARADDR,AWPROT,AWREADY,AWVALID,AWADDR};
assign AWREADY = 1'd0;
assign ARREADY = 1'd0;
assign WREADY = 1'd0;
assign BVALID = 1'd0;
assign BRESP = 2'd0;
assign RVALID = 1'd0;
assign RRESP = 2'd0;
assign RDATA = 32'd0;
endmodule
module lite_monitor(
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK", X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk, ASSOCIATED_BUSIF AXI, FREQ_HZ 200000000" *) input wire clk,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWADDR", X_INTERFACE_MODE = "monitor", X_INTERFACE_PARAMETER = "XIL_INTERFACENAME AXI, PROTOCOL AXI4LITE, ADDR_WIDTH 32, DATA_WIDTH 32, ID_WIDTH 0" *) input wire [31:0] AWADDR,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWVALID" *) input wire AWVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWREADY" *) input wire AWREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWPROT" *) input wire [2:0] AWPROT,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARADDR" *) input wire [31:0] ARADDR,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARVALID" *) input wire ARVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARREADY" *) input wire ARREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARPROT" *) input wire [2:0] ARPROT,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WVALID" *) input wire WVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WREADY" *) input wire WREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WDATA" *) input wire [31:0] WDATA,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WSTRB" *) input wire [3:0] WSTRB,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI BVALID" *) input wire BVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI BREADY" *) input wire BREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI BRESP" *) input wire [1:0] BRESP,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RVALID" *) input wire RVALID,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RREADY" *) input wire RREADY,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RRESP" *) input wire [1:0] RRESP,
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RDATA" *) input wire [31:0] RDATA,
output wire [151:0] captured);
assign captured = {RDATA,RRESP,RREADY,RVALID,BRESP,BREADY,BVALID,WSTRB,WDATA,WREADY,WVALID,ARPROT,ARREADY,ARVALID,ARADDR,AWPROT,AWREADY,AWVALID,AWADDR};
endmodule
};close $fd
puts "ILA_TOOL=[version]"
create_project passive project -part xc7k325tffg900-2
add_files -norecurse passive.v
update_compile_order -fileset sources_1
create_bd_design passive
create_bd_port -dir I -type clk clk
set_property CONFIG.FREQ_HZ 200000000 [get_bd_ports clk]
foreach kind {full lite} {
  foreach mode {master slave monitor} {
    create_bd_cell -type module -reference ${kind}_${mode} ${kind}_${mode}
    connect_bd_net [get_bd_ports clk] [get_bd_pins ${kind}_${mode}/clk]
    puts "INTERFACE_BEGIN ${kind}_${mode}"
    puts [report_property -return_string [get_bd_intf_pins ${kind}_${mode}/AXI]]
    puts "INTERFACE_END ${kind}_${mode}"
  }
  connect_bd_intf_net -intf_net ${kind}_bus [get_bd_intf_pins ${kind}_master/AXI] [get_bd_intf_pins ${kind}_slave/AXI]
  connect_bd_intf_net -intf_net ${kind}_bus [get_bd_intf_pins ${kind}_master/AXI] [get_bd_intf_pins ${kind}_monitor/AXI]
  set actual [lsort [get_bd_intf_pins -of_objects [get_bd_intf_nets ${kind}_bus]]]
  set expected [lsort [list /${kind}_master/AXI /${kind}_slave/AXI /${kind}_monitor/AXI]]
  if {$actual ne $expected} {error "passive endpoint identity differs: $actual"}
  if {[get_property MODE [get_bd_intf_pins ${kind}_monitor/AXI]] ne "Monitor"} {error "passive mode not Monitor"}
  puts "PASSIVE_ENDPOINTS $actual"
}
validate_bd_design
save_bd_design
generate_target all [get_files passive.bd]
set generated [file join $work project passive.gen sources_1 bd passive synth passive.v]
set fd [open $generated r];set rtl [read $fd];close $fd
puts "GENERATED_BEGIN"
puts $rtl
puts "GENERATED_END"
foreach kind {full lite} {
  set signals {AWADDR AWVALID AWREADY AWPROT ARADDR ARVALID ARREADY ARPROT WVALID WREADY WDATA WSTRB BVALID BREADY BRESP RVALID RREADY RRESP RDATA}
  if {$kind eq "full"} {lappend signals AWID AWLEN AWSIZE AWBURST AWLOCK AWCACHE AWQOS ARID ARLEN ARSIZE ARBURST ARLOCK ARCACHE ARQOS WLAST BID RID RLAST}
  foreach signal $signals {
    set expression [format {[.]%s[(]([^)]+)[)]} $signal]
    set matches [regexp -all -inline $expression $rtl]
    set connections {}
    foreach {whole net} $matches {if {[string match ${kind}_bus_* $net]} {lappend connections $net}}
    if {[llength $connections] != 3 || [llength [lsort -unique $connections]] != 1} {error "functional/monitor net differs: $kind $signal -> $connections"}
    puts "PASSIVE_SIGNAL $kind $signal [lindex $connections 0] three_equal_endpoints"
  }
}
puts "PASSIVE_MONITOR_PROBE=PASS"
close_project
} reason options]} {puts stderr "PASSIVE_MONITOR_FAILED=$reason";puts stderr [dict get $options -errorinfo];exit 1}
exit 0
