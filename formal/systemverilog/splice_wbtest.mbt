///|
test "splicing requires exactly one endmodule line" {
  try
    splice_property_source("module Missing;\n", "`ifdef FORMAL\n`endif\n")
  catch {
    MissingEndmodule => ()
    _ => fail("expected missing endmodule rejection")
  } noraise {
    _ => fail("expected missing endmodule rejection")
  }
  try
    splice_property_source(
      "module A;\nendmodule\nmodule B;\nendmodule\n", "`ifdef FORMAL\n`endif\n",
    )
  catch {
    MultipleEndmodule => ()
    _ => fail("expected multiple endmodule rejection")
  } noraise {
    _ => fail("expected multiple endmodule rejection")
  }
  assert_eq(
    splice_property_source(
      "module Exact;\nendmodule\n", "`ifdef FORMAL\n`endif\n",
    ),
    (
      #|module Exact;
      #|
      #|`ifdef FORMAL
      #|`endif
      #|endmodule
      #|
    ),
  )
}
