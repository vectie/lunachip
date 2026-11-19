///|
fn export_ordered_mac(root : String) -> Unit raise {
  guard !@fs.path_exists(root) else {
    fail("fresh ordered MAC output directory")
  }
  @fs.create_dir(root)
  let design = @ir.Design::single(
    "qwen-ordered-bf16-mac/v1",
    @fp.ordered_bf16_mac_lane(),
  )
  let e = @sv.emit_design(design)
  save(
    root,
    "array.sv",
    @system.ordered_array_rtl(e, normalize(optimized(e.source()))),
  )
  save(root, "lane.lcir", @codec.serialize(design))
  save(
    root, "array.xdc", "create_clock -name compute -period 1.428 [get_ports clock]\nset_clock_uncertainty -setup 0.100 [get_clocks compute]\nset_property HD.CLK_SRC BUFGCTRL_X0Y0 [get_ports clock]\n",
  )
}
