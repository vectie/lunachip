///|
fn export_compact_multiply_formal(root : String, negative : Bool) -> Unit raise {
  guard !@fs.path_exists(root) else { fail("fresh proof directory required") }
  let old = @sv.emit_design(
    @ir.Design::single(
      "compact-multiply/reference",
      @fp.pipelined_multiplier(fast=true),
    ),
  )
  let gate = @sv.emit_design(
    @ir.Design::single(
      "compact-multiply/candidate",
      @fp.pipelined_multiplier(fast=true, compact_pack=true),
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
    "hierarchy -top comparison\nopt\ncheck -assert\n" +
    "sat -verify -prove trigger 0 -seq 1 -tempinduct -maxsteps 4 -set-init-zero -timeout 120 -dump_vcd counterexample.vcd\n",
  )
  save(
    root, "claim.txt", "Full generated FP32 three-edge multiply, original vs compact gradual-underflow jam. Matched zero initial register state; all operand bits and resets arbitrary. A successful induction proves all output cycles under these conditions. Negative control flips result bit zero.\n",
  )
}
