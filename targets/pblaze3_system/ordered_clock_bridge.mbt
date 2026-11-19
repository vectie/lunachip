///|
/// Only final-column sums cross back to the scheduler. A stripe has at most
/// eight final packets, and the scheduler waits for the last before advancing.
pub fn ordered_clock_bridge_rtl(
  registered_payload~ : Bool = false,
  staged_broadcast~ : Bool = false,
  staged_issue~ : Bool = false,
) -> String {
  let original =
    #|module ordered_packet_fifo #(parameter WIDTH=1)(
    #| input wire wr_clk, rd_clk, rst, push, pop, input wire [WIDTH-1:0] din,
    #| output wire [WIDTH-1:0] dout, output wire full, near_full, empty, wr_busy, rd_busy);
    #| xpm_fifo_async #(.FIFO_MEMORY_TYPE("distributed"),.FIFO_WRITE_DEPTH(32),
    #|   .WRITE_DATA_WIDTH(WIDTH),.READ_DATA_WIDTH(WIDTH),.CDC_SYNC_STAGES(2),
    #|   .READ_MODE("fwft"),.FIFO_READ_LATENCY(0),.PROG_FULL_THRESH(16),
    #|   .USE_ADV_FEATURES("0002"),.ECC_MODE("no_ecc")) storage(
    #|   .wr_clk(wr_clk),.rd_clk(rd_clk),.rst(rst),.din(din),.dout(dout),
    #|   .wr_en(push),.rd_en(pop),.full(full),.prog_full(near_full),.empty(empty),
    #|   .wr_rst_busy(wr_busy),.rd_rst_busy(rd_busy),.sleep(1'b0),
    #|   .injectsbiterr(1'b0),.injectdbiterr(1'b0));
    #|endmodule
    #|module ordered_clock_bridge(
    #| input wire clock, mac_clock, reset, flush, issue, first, last_col,
    #| input wire [2:0] slot, input wire [4:0] phase, input wire [31:0] activation,
    #| input wire [1023:0] weights, output wire credit, fault, retire,
    #| output wire [2:0] retired_slot, output wire [2047:0] sums);
    #| reg [15:0] reset_hold = '1;
    #| always @(posedge clock) reset_hold <= (reset || flush) ? '1 : {reset_hold[14:0],1'b0};
    #| wire core_clear = reset_hold[15];
    #| wire mac_clear;
    #| xpm_cdc_sync_rst #(.DEST_SYNC_FF(3),.INIT(1),.INIT_SYNC_FF(1)) fast_reset(
    #|   .src_rst(core_clear),.dest_clk(mac_clock),.dest_rst(mac_clear));
    #| wire cmd_full,cmd_near,cmd_empty,cmd_wr_busy,cmd_rd_busy;
    #| // A 32-deep FWFT FIFO can hold two additional words in its output
    #| // stages. A 64-entry ring keeps every live payload at a distinct address.
    #| wire push = issue && !core_clear && !cmd_wr_busy && !cmd_full;
    #| reg [5:0] write_addr;
    #| (* ram_style = "block" *) reg [1055:0] payload [0:63];
    #| always @(posedge clock) begin
    #|   if (core_clear) write_addr <= 0;
    #|   else if (push) write_addr <= write_addr + 1'b1;
    #|   if (push) payload[write_addr] <= {activation,weights};
    #| end
    #| wire [15:0] cmd;
    #| reg [4:0] ring;
    #| always @(posedge mac_clock) ring <= (mac_clear || ring==17) ? 0 : ring+1'b1;
    #| wire pop = !mac_clear && !cmd_rd_busy && !cmd_empty && ring==cmd[9:5];
    #| assign credit = !(reset || flush || core_clear || cmd_wr_busy || cmd_near || cmd_full);
    #| ordered_packet_fifo #(.WIDTH(16)) commands(.wr_clk(clock),.rd_clk(mac_clock),
    #|   .rst(core_clear),.push(push),.pop(pop),
    #|   .din({write_addr,phase,slot,first,last_col}),.dout(cmd),.full(cmd_full),
    #|   .near_full(cmd_near),.empty(cmd_empty),.wr_busy(cmd_wr_busy),.rd_busy(cmd_rd_busy));
    #| reg valid_in;
    #| reg [4:0] flags;
    #| reg [1055:0] payload_q;
    #| wire [1060:0] operands = {flags,payload_q};
    #| always @(posedge mac_clock) begin
    #|   valid_in <= pop;
    #|   flags <= cmd[4:0];
    #|   payload_q <= payload[cmd[15:10]];
    #| end
    #| wire retired;
    #| wire [2047:0] raw_sums;
    #| mac_array array_i(.clock(mac_clock),.reset(mac_clear),.valid(valid_in),.first(operands[1057]),
    #|   .activation(operands[1055:1024]),.weights(operands[1023:0]),.sums(raw_sums),.result_valid(retired));
    #| reg [3:0] tag [0:45];
    #| always @(posedge mac_clock) begin
    #|   tag[0] <= {operands[1056],operands[1060:1058]};
    #|   for(integer i=1;i<46;i=i+1) tag[i]<=tag[i-1];
    #| end
    #| reg send_result;
    #| reg [2050:0] result_packet;
    #| always @(posedge mac_clock) begin
    #|   send_result <= !mac_clear && retired && tag[45][3];
    #|   result_packet <= {tag[45][2:0],raw_sums};
    #| end
    #| wire ret_full,ret_empty,ret_wr_busy,ret_rd_busy;
    #| assign retire = !(reset || flush || core_clear || ret_empty || ret_rd_busy);
    #| ordered_packet_fifo #(.WIDTH(2051)) results(.wr_clk(mac_clock),.rd_clk(clock),
    #|   .rst(mac_clear),.push(send_result && !mac_clear && !ret_full && !ret_wr_busy),.pop(retire),
    #|   .din(result_packet),.dout({retired_slot,sums}),.full(ret_full),.near_full(),
    #|   .empty(ret_empty),.wr_busy(ret_wr_busy),.rd_busy(ret_rd_busy));
    #| reg command_fault, result_fault;
    #| wire synced_result_fault;
    #| always @(posedge clock)
    #|   if(core_clear) command_fault <= 0;
    #|   else if(issue && (cmd_full || cmd_wr_busy)) command_fault <= 1;
    #| always @(posedge mac_clock)
    #|   if(mac_clear) result_fault <= 0;
    #|   else if(send_result && (ret_full || ret_wr_busy)) result_fault <= 1;
    #| xpm_cdc_single #(.DEST_SYNC_FF(3),.SRC_INPUT_REG(0)) result_fault_crossing(
    #|   .src_clk(mac_clock),.src_in(result_fault),.dest_clk(clock),.dest_out(synced_result_fault));
    #| assign fault = command_fault || synced_result_fault;
    #|endmodule
  let before =
    #| reg valid_in;
    #| reg [4:0] flags;
    #| reg [1055:0] payload_q;
    #| wire [1060:0] operands = {flags,payload_q};
    #| always @(posedge mac_clock) begin
    #|   valid_in <= pop;
    #|   flags <= cmd[4:0];
    #|   payload_q <= payload[cmd[15:10]];
    #| end
  // Keep both validity and all five command bits aligned with the extra
  // BRAM output edge. mac_clear drains both stages before reset releases.
  let after =
    #| reg valid_read, valid_in;
    #| reg [4:0] flags_read, flags;
    #| reg [1055:0] payload_read, payload_q;
    #| wire [1060:0] operands = {flags,payload_q};
    #| always @(posedge mac_clock) begin
    #|   valid_read <= pop;
    #|   valid_in <= valid_read;
    #|   flags_read <= cmd[4:0];
    #|   flags <= flags_read;
    #|   payload_read <= payload[cmd[15:10]];
    #|   payload_q <= payload_read;
    #| end
  let text = if registered_payload {
    original.replace(old=before, new=after)
  } else {
    original
  }
  let text = if staged_broadcast {
    // The array's new operand edge also delays retirement by one edge.
    text
    .replace(old="tag [0:45]", new="tag [0:46]")
    .replace(old="i<46", new="i<47")
    .replace_all(old="tag[45]", new="tag[46]")
  } else {
    text
  }
  if staged_issue {
    // Reserve the ring slot on capture; publish its command only on the
    // edge that commits the registered payload. Near-full at 16 leaves room
    // for this one pending packet in the 32-entry command FIFO.
    let before =
      #| wire push = issue && !core_clear && !cmd_wr_busy && !cmd_full;
      #| reg [5:0] write_addr;
      #| (* ram_style = "block" *) reg [1055:0] payload [0:63];
      #| always @(posedge clock) begin
      #|   if (core_clear) write_addr <= 0;
      #|   else if (push) write_addr <= write_addr + 1'b1;
      #|   if (push) payload[write_addr] <= {activation,weights};
      #| end
    let after =
      #| wire capture = issue && !core_clear && !cmd_wr_busy && !cmd_full;
      #| reg ingress_valid;
      #| (* dont_touch = "yes" *) reg [1071:0] ingress;
      #| wire push = ingress_valid && !core_clear && !cmd_wr_busy && !cmd_full;
      #| reg [5:0] write_addr;
      #| (* ram_style = "block" *) reg [1055:0] payload [0:63];
      #| always @(posedge clock) begin
      #|   if (core_clear) begin write_addr <= 0; ingress_valid <= 0; end
      #|   else begin
      #|     ingress_valid <= capture;
      #|     if (capture) begin
      #|       ingress <= {write_addr,phase,slot,first,last_col,activation,weights};
      #|       write_addr <= write_addr + 1'b1;
      #|     end
      #|   end
      #|   if (push) payload[ingress[1071:1066]] <= ingress[1055:0];
      #| end
    text
    .replace(old=before, new=after)
    .replace(
      old=".din({write_addr,phase,slot,first,last_col})",
      new=".din(ingress[1071:1056])",
    )
    .replace(
      old="else if(issue && (cmd_full || cmd_wr_busy))",
      new="else if((issue || ingress_valid) && (cmd_full || cmd_wr_busy))",
    )
  } else {
    text
  }
}
