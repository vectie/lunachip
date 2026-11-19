`timescale 1ps/1ps
// Compile with the current bridge, the prior bridge renamed
// reference_clock_bridge, the production mac_array, and AMD's XPM library.
module ordered_command_ram_tb;
  bit clock, mac_clock, reset = 1, flush, issue, first, last_col;
  logic [2:0] slot;
  logic [4:0] phase;
  logic [31:0] activation;
  logic [1023:0] weights;
  wire credit, fault, retire, old_credit, old_fault, old_retire;
  wire [2:0] retired_slot, old_slot;
  wire [2047:0] sums, old_sums;
  always #5000 clock = !clock;
  always #1771 mac_clock = !mac_clock;
  ordered_clock_bridge dut(.*);
  reference_clock_bridge golden(.credit(old_credit), .fault(old_fault),
    .retire(old_retire), .retired_slot(old_slot), .sums(old_sums), .*);

  function automatic logic [1060:0] packet(input int n);
    logic [1023:0] w;
    for (int i = 0; i < 64; i++)
      w[16*i+:16] = 16'h3780 + ((n*103 + i*251) % 4096);
    return {3'(n), 1'((n % 8) == 0), 1'((n % 8) == 7),
            32'h3f000000 + 32'(n*61), w};
  endfunction
  bit checking, last_valid;
  int expected, accepted, consumed, adjacent, stalls, returns;
  always @(negedge mac_clock) if (checking) begin
    if (dut.valid_in !== golden.valid_in) $fatal(1, "different issue cycle");
    if (dut.valid_in) begin
      if (dut.operands !== packet(expected) || dut.operands !== golden.operands)
        $fatal(1, "command %0d payload, slot or flags", expected);
      expected++;
      consumed++;
      if (last_valid) adjacent++;
    end
    last_valid = dut.valid_in;
  end
  always @(posedge clock) if (checking) begin
    if ({credit, fault, retire} !== {old_credit, old_fault, old_retire} || fault)
      $fatal(1, "different credit, retirement, or FIFO fault");
    if (retire) begin
      if ({retired_slot,sums} !== {old_slot,old_sums}) $fatal(1, "MAC result");
      returns++;
    end
    if (issue && credit) accepted++;
    if (!credit) stalls++;
  end
  task automatic send(input int from, input int count);
    for (int n = from; n < from+count; n++) begin
      @(negedge clock);
      issue = 0;
      while (!credit) @(negedge clock);
      {slot,first,last_col,activation,weights} = packet(n);
      phase = n%72 < 32 ? 0 : n%18;
      issue = 1;
    end
    @(negedge clock);
    issue = 0;
  endtask
  initial begin
    repeat (30) @(negedge clock);
    reset = 0;
    wait (credit && !dut.mac_clear);
    checking = 1;
    send(0, 300);
    wait (expected == 300);
    send(300, 16);
    if (expected == 316) $fatal(1, "flush did not exercise pending commands");
    checking = 0;
    flush = 1;
    repeat (5) @(negedge clock);
    flush = 0;
    wait (credit && !dut.mac_clear);
    expected = 1000;
    last_valid = 0;
    checking = 1;
    send(1000, 384);
    wait (expected == 1384);
    repeat (140) @(negedge clock);
    if (accepted != 700 || adjacent == 0 || stalls == 0 || returns == 0)
      $fatal(1, "insufficient wrap, backpressure or retirement coverage");
    $display("COMMAND_RAM_PASS accepted=%0d issued=%0d adjacent=%0d stalls=%0d returns=%0d",
      accepted, consumed, adjacent, stalls, returns);
    $finish;
  end
  initial begin #200000000; $fatal(1, "command RAM timeout"); end
endmodule
