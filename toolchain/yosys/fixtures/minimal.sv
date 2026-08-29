module phase4_minimal(input logic clock, input logic reset, output logic value);
  always_ff @(posedge clock) begin
    if (reset) value <= 1'b0;
    else value <= ~value;
  end
endmodule
