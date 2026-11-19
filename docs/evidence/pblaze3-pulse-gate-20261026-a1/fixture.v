module pulse_fixture(input wire clk, input wire data, output reg result);
  always @(posedge clk) result <= data;
endmodule
