///|
fn export_full_product_formal(root : String, negative : Bool) -> Unit raise {
  guard !@fs.path_exists(root) else { fail("fresh proof directory required") }
  let old = @sv.emit_design(
    @ir.Design::single(
      "full-significand/reference",
      @fp.significand_product_pipeline(),
    ),
  )
  let gate = @sv.emit_design(
    @ir.Design::single(
      "full-significand/candidate",
      @fp.significand_product_pipeline(full_product=true),
    ),
  )
  let top = old.modules()[0].identifier()
  assert_eq(top, gate.modules()[0].identifier())
  let source = if negative {
    gate
    .source()
    .replace(
      old="assign " + mapped(gate, "result", OutputPort) + " = ",
      new="assign " + mapped(gate, "result", OutputPort) + " = 32'h1 ^ ",
    )
  } else {
    gate.source()
  }
  if negative {
    assert_true(source != gate.source())
  }
  @fs.create_dir(root)
  save(root, "gold.sv", old.source())
  save(root, "gate.sv", source)
  save(
    root,
    "proof.ys",
    "read_verilog -sv gold.sv\nrename \{top} gold\n" +
    "read_verilog -sv gate.sv\nrename \{top} gate\n" +
    "proc\nmiter -equiv -make_outputs -flatten gold gate comparison\n" +
    "hierarchy -top comparison\nopt\nwreduce\nopt\ncheck -assert\n" +
    "sat -verify -prove trigger 0 -seq 13 -tempinduct -maxsteps 2 -set-init-zero -timeout 120 -dump_vcd counterexample.vcd\n",
  )
  save(
    root, "claim.txt", "Exact unsigned 24-by-8 product, all 32 output bits, thirteen-edge latency. Matched zero initial state; unconstrained operand streams. Induction proves all output cycles from these states. The native MAC regression independently checks reset, bubbles, rounding and exceptions. Negative control flips result bit zero.\n",
  )
}
