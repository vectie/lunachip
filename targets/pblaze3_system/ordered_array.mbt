///|
/// Emit the 64 independently weighted lanes used by the board and timing fixture.
pub fn ordered_array_rtl(
  e : @sv.EmittedDesign,
  lane_rtl : String,
  staged_broadcast~ : Bool = false,
) -> String raise {
  let sb = StringBuilder()
  sb.write_string(lane_rtl)
  sb.write_string(
    "\nmodule mac_array(input wire clock, reset, valid, first, input wire [31:0] activation, input wire [1023:0] weights, output wire [2047:0] sums, output wire result_valid);\n",
  )
  if staged_broadcast {
    // One common edge for data and control. Eight preserved activation
    // replicas each drive eight adjacent logical lanes instead of all 64.
    sb.write_string(
      (
        #|(* dont_touch = "yes" *) reg [31:0] activation_group [0:7];
        #|reg [1023:0] weights_stage;
        #|reg valid_stage, first_stage;
        #|always @(posedge clock) begin
        #|  valid_stage <= valid && !reset;
        #|  first_stage <= first;
        #|  weights_stage <= weights;
        #|  for(integer g=0; g<8; g=g+1) activation_group[g] <= activation;
        #|end
        #|
      ),
    )
  }
  sb.write_string("for (genvar i=0; i<64; i=i+1) begin : rows\nwire retired;\n")
  sb.write_string(
    "(* keep_hierarchy = \"yes\" *) " + e.modules()[0].identifier() + " mac(",
  )
  for
    i, (name, pin) in [
      ("clock", "clock"),
      ("reset", "reset"),
      ("first", if staged_broadcast { "first_stage" } else { "first" }),
      ("valid", if staged_broadcast { "valid_stage" } else { "valid" }),
      (
        "activation",
        if staged_broadcast {
          "activation_group[i/8]"
        } else {
          "activation"
        },
      ),
      (
        "weight",
        if staged_broadcast {
          "weights_stage[16*i+:16]"
        } else {
          "weights[16*i+:16]"
        },
      ),
      ("result", "sums[32*i+:32]"),
      ("result_valid", "retired"),
    ] {
    if i > 0 {
      sb.write_string(", ")
    }
    sb.write_string(
      "." +
      mapped(
        e,
        name,
        if name == "result" || name == "result_valid" {
          OutputPort
        } else {
          InputPort
        },
      ) +
      "(" +
      pin +
      ")",
    )
  }
  sb.write_string(");\nif(i==0) assign result_valid=retired;\nend\nendmodule\n")
  sb.to_string()
}
