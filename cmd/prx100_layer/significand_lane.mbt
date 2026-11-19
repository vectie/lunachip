///|
fn export_significand_lane(root : String) -> Unit raise {
  guard !@fs.path_exists(root) else {
    fail("fresh significand output directory")
  }
  @fs.create_dir(root)
  let design = @ir.Design::single(
    "qwen-significand-24x8/v1",
    @fp.significand_product_pipeline(),
  )
  let emitted = @sv.emit_design(design)
  let wrapper = StringBuilder()
  wrapper.write_string(normalize(emitted.source()))
  wrapper.write_string(
    "\nmodule lane(input wire clock, input wire [23:0] activation, input wire [7:0] weight, output wire [31:0] result);\n",
  )
  wrapper.write_string(emitted.modules()[0].identifier() + " product(")
  for i, name in ["clock", "activation", "weight", "result"] {
    if i > 0 {
      wrapper.write_string(", ")
    }
    let port = mapped(
      emitted,
      name,
      if name == "result" {
        OutputPort
      } else {
        InputPort
      },
    )
    wrapper.write_string("." + port + "(" + name + ")")
  }
  wrapper.write_string(");\nendmodule\n")
  save(root, "lane.sv", wrapper.to_string())
  save(root, "lane.lcir", @codec.serialize(design))
  save(
    root, "lane.xdc", "create_clock -name lane_clock -period 1.428 [get_ports clock]\nset_property HD.CLK_SRC BUFGCTRL_X0Y0 [get_ports clock]\n",
  )
}
