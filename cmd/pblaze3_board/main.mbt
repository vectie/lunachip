///|
fn digest(bytes : Bytes) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(bytes))
}

///|
fn run() -> Unit raise {
  let (text, source, root, selected_release) = match @env.args()[1:] {
    ["export", text, source, root] => (text, source, root, None)
    ["export", text, source, root, "--vivado-release", release] =>
      (text, source, root, Some(release))
    _ =>
      fail(
        "export vendor-baseline|ddr-smoke|accelerator|ddr-status-ila|ddr-mig-ila|ddr-xdma-ila|accelerator-core-ila|ddr-smoke-ila|accelerator-ila VENDOR_DIRECTORY NEW_OUTPUT [--vivado-release RELEASE]",
      )
  }
  let mode = @board.parse_mode(text)
  let release = selected_release.unwrap_or(mode.vivado_release())
  let recipe = @board.build_tcl_for_release(mode, release)
  let manifest = @board.manifest_for_release(mode, release)
  guard !@fs.path_exists(root) else { fail("output directory must be fresh") }
  let originals = [
    (
      "vendor-mig.prj", "f5e52e299b830a1c528b8cb629c505d3dcf45d4a014f5941c03d76adc3543f7e",
    ),
    (
      "vendor-io.xdc", "8cab531e38913882e1ba5ab748563a392b3dab04113848c85322dbfbb0662a3b",
    ),
    (
      "vendor-design.bd", "18b2bdfa8321de7d66843ca1687e2f0d3bcd4ab97ed5c11b1f74ed1268eb51de",
    ),
  ]
  for (name, expected) in originals {
    guard digest(@fs.read_file_to_bytes(source + "/" + name)) == expected else {
      fail("vendor input identity mismatch: \{name}")
    }
  }
  // The supplied bytes begin EF BB 3F (corrupt BOM). Retain those exact
  // archival bytes, but explicitly normalize the known prefix for valid XML.
  let vendor_bytes = @fs.read_file_to_bytes(source + "/vendor-mig.prj")
  let mig = @board.mig_project(@board.normalize_vendor_xml(vendor_bytes), mode)
  let files = [
    ("build.tcl", recipe),
    (
      "pblaze3.xdc",
      @board.constraints() +
      (if mode.is_diagnostic() {
        "create_clock -name clk_in1_50M -period 20.000 [get_ports clk_in1_50M]\n"
      } else {
        ""
      }),
    ),
    ("reset-boundary.xdc", @board.reset_boundary_constraints()),
    ("pblaze3_calib_sync.sv", @board.calibration_wrapper()),
    ("pblaze3_smoke_status_sync.sv", @board.smoke_status_wrapper()),
    ("pblaze3_transport_reset.sv", @board.transport_reset_wrapper()),
    ("pblaze3_transport_reset_core.sv", @board.transport_reset_core_source()),
    (
      "pblaze3_transport_reset_core-ordinary.sv",
      @board.transport_reset_ordinary_source(),
    ),
    ("mig.prj", mig),
    ("board.json", manifest.stringify(indent=2) + "\n"),
    (
      "vendor-provenance.json",
      @fs.read_file_to_string(source + "/provenance.json"),
    ),
  ]
  if mode.is_diagnostic() {
    files.push(
      (
        "diagnostic.json",
        @board.diagnostic_manifest(mode).stringify(indent=2) + "\n",
      ),
    )
    files.push(
      ("pblaze3_diagnostic_status.sv", @board.diagnostic_status_wrapper()),
    )
    files.push(
      ("pblaze3_diagnostic_clock.sv", @board.diagnostic_clock_wrapper()),
    )
    files.push(("debug-hub.xdc", @board.diagnostic_hub_constraints()))
    for file in @board.diagnostic_axi_wrappers(mode) {
      files.push(file)
    }
  }
  @fs.create_dir(root)
  let inventory = StringBuilder()
  for (name, content) in files {
    @fs.write_string_to_file(root + "/" + name, content)
    inventory.write_string(digest(@utf8.encode(content)) + "  " + name + "\n")
  }
  @fs.write_string_to_file(root + "/SHA256SUMS", inventory.to_string())
  println(
    "Prepared \{mode.name()} board inputs at \{root}; physical geometry remains unverified",
  )
}

///|
fn main {
  run() catch {
    e => abort("\{Repr(e)}")
  }
}
