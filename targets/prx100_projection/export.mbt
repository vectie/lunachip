///|
pub(all) struct Artifact {
  path : String
  content : String
} derive(Eq, @debug.Debug)

///|
pub extend Artifact with Eq::{equal, not_equal}

///|
pub extend Artifact with @debug.Debug::{to_repr}

///|
fn digest(text : String) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode(text)))
}

///|
fn mapped(
  e : @systemverilog.EmittedDesign,
  name : String,
  kind : @systemverilog.SymbolKind,
) -> String raise {
  for item in e.manifest().mappings() {
    if item.kind() == kind && item.source_name() == name {
      return item.identifier()
    }
  }
  fail("missing mapping " + name)
}

///|
// Exact target-only normalization previously qualified on PRX100. Portable
// canonical IR and conservative emitter remain unchanged and are retained.
fn normalize(source : String) -> String raise {
  let lines = source.split("\n").to_array()
  let out : Array[String] = []
  for i = 0; i < lines.length(); {
    let line = lines[i]
    if line.has_prefix("  function automatic logic lc_fn_eq_w") {
      for j = i; j < i + 4; j = j + 1 {
        out.push(lines[j].to_owned())
      }
      let name = line.split("logic ").to_array()[1].split("(").to_array()[0].to_owned()
      out.push("    " + name + " = (a == b);")
      let mut last = i + 4
      while last < lines.length() && lines[last] != "  endfunction" {
        last = last + 1
      }
      guard last < lines.length() else { fail("unterminated equality helper") }
      out.push("  endfunction")
      continue last + 1
    }
    out.push(
      if line.has_prefix("  input logic ") {
        "  input wire logic " + line[14:].to_owned()
      } else {
        line.to_owned()
      },
    )
    continue i + 1
  }
  out.join("\n")
}

///|
/// Export canonical modules independently; wrappers connect exact named seams.
pub fn digital_bundle(
  watchdog~ : UInt64 = 50000000UL,
) -> ReadOnlyArray[Artifact] raise {
  let artifacts : Array[Artifact] = []
  for
    (name, hw) in [
      ("core", core()),
      ("controller", controller(watchdog~)),
      ("bridge", bridge()),
    ] {
    let design = @ir.Design::single("prx100-ddr-projection-" + name + "/v1", hw)
    // The opt-in portable word-read core has a distinct canonical identity.
    let design = if name == "core" {
      @ir.Design::single(
        "phase6-fetched-concurrent-word32-8x8-k16-two-slots", hw,
      )
    } else {
      design
    }
    let e = @systemverilog.emit_design(design)
    artifacts.push({ path: name + ".lcir", content: @codec.serialize(design), })
    artifacts.push({
      path: name + ".names",
      content: e.manifest().to_canonical_text(),
    })
    artifacts.push({
      path: name + "-ordinary.sv",
      content: e.modules()[0].source(),
    })
    artifacts.push({
      path: name + ".sv",
      content: if name == "bridge" {
        preserve_bridge(hw, e)
      } else {
        normalize(e.modules()[0].source())
      },
    })
  }
  let h = controller(watchdog~)
  let e = @systemverilog.emit_design(
    @ir.Design::single("prx100-ddr-projection-controller/v1", h),
  )
  let core = core()
  let core_e = @systemverilog.emit_design(
    @ir.Design::single(
      "phase6-fetched-concurrent-word32-8x8-k16-two-slots", core,
    ),
  )
  let bridge = bridge()
  let bridge_e = @systemverilog.emit_design(
    @ir.Design::single("prx100-ddr-projection-bridge/v1", bridge),
  )
  artifacts.push({
    path: "prx100_projection_system.sv",
    content: core_wrapper(core, core_e, h, e),
  })
  artifacts.push({
    path: "prx100_projection_top.sv",
    content: physical_wrapper(h, bridge, bridge_e),
  })
  artifacts.push({
    path: "prx100_projection.xdc",
    content: (
      #|set_property PACKAGE_PIN D18 [get_ports clk50]
      #|set_property PACKAGE_PIN M4 [get_ports reset_n]
      #|set_property IOSTANDARD LVCMOS33 [get_ports {clk50 reset_n}]
      #|create_clock -name clk50 -period 20.000 [get_ports clk50]
      #|set_false_path -from [get_ports reset_n]
      #|set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets clk50_raw]
      #|
    ),
  })
  artifacts.push({
    path: "controller-top.txt",
    content: e.modules()[0].identifier() + "\n",
  })
  artifacts.push({
    path: "job.json",
    content: "{\"schema_version\":\"lunachip.yosys-job/v1\",\"top_module\":\"" +
    e.modules()[0].identifier() +
    "\",\"sources\":[{\"path\":\"controller.sv\",\"sha256\":\"" +
    digest(normalize(e.modules()[0].source())) +
    "\"}],\"formal_tasks\":[]}\n",
  })
  artifacts.push({
    path: "SHA256SUMS",
    content: artifacts
    .map(a => digest(a.content) + "  " + a.path + "\n")
    .join(""),
  })
  ReadOnlyArray::from_array(artifacts)
}
