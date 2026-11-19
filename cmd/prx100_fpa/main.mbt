///|
fn save(root : String, name : String, text : String) -> Unit raise {
  @fs.write_string_to_file(root + "/" + name, text)
}

///|
fn export_target(root : String) -> Unit raise {
  guard !@fs.path_exists(root) else { fail("fresh output directory required") }
  @fs.create_dir(root)
  let core = @fp.fast_banked_dot_product()
  let control = @target.controller()
  let bridge = @projection.bridge()
  let emitted = [
    (core, "core", "bf16-fp32-fast-banked-dot/v1"),
    (control, "controller", "prx100-floating-point-fast-ddr-controller/v1"),
    (bridge, "bridge", "prx100-ddr-projection-bridge/v1"),
  ].map(x => {
    let (h, name, semantic) = x
    let d = @ir.Design::single(semantic, h)
    let e = @sv.emit_design(d)
    let source = if name == "bridge" {
      preserve_bridge(h, e)
    } else {
      normalize(optimized(e.source()))
    }
    save(root, name + ".lcir", @codec.serialize(d))
    save(root, name + "-ordinary.sv", e.source())
    save(root, name + ".sv", source)
    save(root, name + ".names", e.manifest().to_canonical_text())
    e
  })
  save(
    root,
    "prx100_fpa_system.sv",
    core_wrapper(core, emitted[0], control, emitted[1]),
  )
  save(root, "prx100_fpa_top.sv", physical_wrapper(control, bridge, emitted[2]))
  save(
    root,
    "prx100_fpa.xdc",
    (
      #|set_property PACKAGE_PIN D18 [get_ports clk50]
      #|set_property PACKAGE_PIN M4 [get_ports reset_n]
      #|set_property IOSTANDARD LVCMOS33 [get_ports {clk50 reset_n}]
      #|create_clock -name clk50 -period 20.000 [get_ports clk50]
      #|set_false_path -from [get_ports reset_n]
      #|set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets clk50_raw]
      #|
    ),
  )
  let names : Array[String] = []
  for module_name in ["core", "controller", "bridge"] {
    for suffix in [".lcir", "-ordinary.sv", ".sv", ".names"] {
      names.push(module_name + suffix)
    }
  }
  for name in ["prx100_fpa_system.sv", "prx100_fpa_top.sv", "prx100_fpa.xdc"] {
    names.push(name)
  }
  names.sort()
  save(
    root,
    "SHA256SUMS",
    names
    .map(name => {
      @v.sha256_hex(@fs.read_file_to_string(root + "/" + name)) +
      "  " +
      name +
      "\n"
    })
    .join(""),
  )
}

///|
fn run() -> Unit raise {
  match @env.args()[1:] {
    ["export", root] => export_target(root)
    ["core-formal" | "core-formal-negative" as mode, root] =>
      banked_formal(root, mode == "core-formal-negative")
    ["formal" | "formal-negative" as mode, root] =>
      formal_bundle(root, mode == "formal-negative")
    ["replay" | "core-replay" as mode, jobs, root] => {
      guard !@fs.path_exists(root) else {
        fail("fresh output directory required")
      }
      let artifacts = @validation.replay_bundle(
        @fs.read_file_to_string(jobs),
        core=mode == "core-replay",
      )
      @fs.create_dir(root)
      for a in artifacts {
        save(
          root,
          a.path,
          if a.path.has_suffix(".sv") {
            normalize(optimized(a.content))
          } else {
            a.content
          },
        )
      }
    }
    _ => fail("export ROOT | replay/core-replay JOBS ROOT")
  }
}

///|
fn main {
  run() catch {
    e => abort(e.to_string())
  }
}
