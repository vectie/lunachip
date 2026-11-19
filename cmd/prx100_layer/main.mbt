///|
fn save(root : String, name : String, text : String) -> Unit raise {
  @fs.write_string_to_file(root + "/" + name, text)
}

///|
fn export_target(
  root : String,
  parallel~ : Bool = false,
  overlap~ : Bool = false,
  transfer~ : Bool = false,
  wide~ : Bool = false,
  batch~ : Bool = false,
  throughput~ : Bool = false,
  streaming~ : Bool = false,
  compute~ : Bool = false,
  read_ahead~ : Bool = false,
  eight_row~ : Bool = false,
  short_unary~ : Bool = false,
  sixteen_row~ : Bool = false,
  aligned_extent~ : Bool = false,
  packed_weights~ : Bool = false,
  feedback~ : Bool = false,
  delivery~ : Bool = false,
  interleaved~ : Bool = false,
) -> Unit raise {
  guard !@fs.path_exists(root) else { fail("fresh output directory required") }
  @fs.create_dir(root)
  let core = if interleaved {
    @fp.interleaved_layer_machine()
  } else if feedback {
    @fp.feedback_layer_machine(delivery~)
  } else if packed_weights {
    @fp.contiguous_layer_machine()
  } else if sixteen_row {
    @fp.sixteen_row_layer_machine()
  } else if short_unary {
    @fp.short_unary_layer_machine()
  } else if eight_row {
    @fp.eight_row_layer_machine()
  } else if compute {
    @fp.compute_layer_machine()
  } else if throughput {
    @fp.throughput_layer_machine()
  } else if batch {
    @fp.batched_layer_machine()
  } else if wide {
    @fp.wide_layer_machine()
  } else if overlap {
    @fp.overlapped_layer_machine()
  } else if parallel {
    @fp.parallel_layer_machine()
  } else {
    @fp.layer_machine()
  }
  let control = if delivery {
    @target.delivery_controller()
  } else if sixteen_row {
    @target.sixteen_row_controller()
  } else if eight_row {
    @target.eight_row_controller()
  } else if batch {
    @target.batched_controller()
  } else if wide {
    @target.wide_controller()
  } else {
    @target.controller()
  }
  let bridge = if delivery {
    @ddr.delivery_bridge()
  } else if sixteen_row {
    @ddr.sixteen_row_bridge()
  } else if aligned_extent {
    @ddr.aligned_eight_row_bridge()
  } else if eight_row {
    @ddr.eight_row_bridge()
  } else if read_ahead {
    @ddr.read_ahead_bridge()
  } else if streaming {
    @ddr.streaming_bridge()
  } else if batch {
    @ddr.batched_bridge()
  } else if wide {
    @ddr.wide_bridge()
  } else if transfer {
    @ddr.bridge()
  } else {
    @projection.bridge()
  }
  let emitted = [
    (core, "core", "qwen-layer-machine/v1"),
    (control, "controller", "prx100-qwen-layer-control/v1"),
    (bridge, "bridge", "prx100-ddr-projection-bridge/v1"),
  ].map(item => {
    let (h, name, semantic) = item
    let design = @ir.Design::single(semantic, h)
    save(root, name + ".lcir", @codec.serialize(design))
    let e = @sv.emit_design(design)
    save(root, name + "-ordinary.sv", e.source())
    save(
      root,
      name + ".sv",
      if name == "bridge" {
        preserve_bridge(h, e)
      } else if name == "core" {
        memory_style(normalize(optimized(e.source())))
      } else {
        normalize(optimized(e.source()))
      },
    )
    save(root, name + ".names", e.manifest().to_canonical_text())
    e
  })
  save(
    root,
    "prx100_layer_system.sv",
    core_wrapper(core, emitted[0], control, emitted[1]),
  )
  save(
    root,
    "prx100_layer_top.sv",
    physical_wrapper(control, bridge, emitted[2]),
  )
  save(
    root,
    "prx100_layer.xdc",
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
  for name in ["core", "controller", "bridge"] {
    for suffix in [".lcir", "-ordinary.sv", ".sv", ".names"] {
      names.push(name + suffix)
    }
  }
  for
    name in [
      "prx100_layer_system.sv", "prx100_layer_top.sv", "prx100_layer.xdc",
    ] {
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
  if feedback_command(@env.args()[1:]) {
    return
  }
  match @env.args()[1:] {
    ["adder-formal-feedback", root] =>
      throughput_adder_formal(root, false, feedback=true)
    ["adder-formal-negative-feedback", root] =>
      throughput_adder_formal(root, true, feedback=true)
    ["feedback-unit", root] => feedback_unit(root)
    ["export-contiguous", root] =>
      export_target(
        root,
        parallel=true,
        overlap=true,
        transfer=true,
        wide=true,
        batch=true,
        throughput=true,
        streaming=true,
        eight_row=true,
        short_unary=true,
        sixteen_row=true,
        aligned_extent=true,
        packed_weights=true,
      )
    ["replay-contiguous", root] =>
      replay_bundle(
        root,
        parallel=true,
        overlap=true,
        wide=true,
        batch=true,
        throughput=true,
        eight_row=true,
        short_unary=true,
        sixteen_row=true,
        packed_weights=true,
      )
    ["core-formal-contiguous", root] =>
      formal_bundle(
        root,
        false,
        core=true,
        parallel=true,
        overlap=true,
        wide=true,
        batch=true,
        throughput=true,
        eight_row=true,
        short_unary=true,
        sixteen_row=true,
        packed_weights=true,
      )
    ["core-formal-negative-contiguous", root] =>
      formal_bundle(
        root,
        true,
        core=true,
        parallel=true,
        overlap=true,
        wide=true,
        batch=true,
        throughput=true,
        eight_row=true,
        short_unary=true,
        sixteen_row=true,
        packed_weights=true,
      )
    ["export-sixteen-row", root] =>
      export_target(
        root,
        parallel=true,
        overlap=true,
        transfer=true,
        wide=true,
        batch=true,
        throughput=true,
        streaming=true,
        read_ahead=true,
        eight_row=true,
        short_unary=true,
        aligned_extent=true,
        sixteen_row=true,
      )
    ["replay-sixteen-row", root] =>
      replay_bundle(
        root,
        parallel=true,
        overlap=true,
        wide=true,
        batch=true,
        throughput=true,
        eight_row=true,
        short_unary=true,
        sixteen_row=true,
      )
    ["core-formal-sixteen-row", root] =>
      formal_bundle(
        root,
        false,
        core=true,
        parallel=true,
        overlap=true,
        wide=true,
        batch=true,
        throughput=true,
        eight_row=true,
        short_unary=true,
        sixteen_row=true,
      )
    ["core-formal-negative-sixteen-row", root] =>
      formal_bundle(
        root,
        true,
        core=true,
        parallel=true,
        overlap=true,
        wide=true,
        batch=true,
        throughput=true,
        eight_row=true,
        short_unary=true,
        sixteen_row=true,
      )
    ["formal-sixteen-row", root] =>
      formal_bundle(
        root,
        false,
        core=false,
        parallel=true,
        overlap=true,
        wide=true,
        batch=true,
        throughput=true,
        eight_row=true,
        short_unary=true,
        sixteen_row=true,
      )
    ["formal-negative-sixteen-row", root] =>
      formal_bundle(
        root,
        true,
        core=false,
        parallel=true,
        overlap=true,
        wide=true,
        batch=true,
        throughput=true,
        eight_row=true,
        short_unary=true,
        sixteen_row=true,
      )
    ["bridge-replay-sixteen-row", root] =>
      ddr_evidence(
        root,
        false,
        false,
        wide=true,
        batch=true,
        streaming=true,
        clock_ratio=3,
        read_ahead=true,
        eight_row=true,
        aligned_extent=true,
        sixteen_row=true,
      )
    ["bridge-formal-sixteen-row", root] =>
      ddr_evidence(
        root,
        true,
        false,
        wide=true,
        batch=true,
        streaming=true,
        clock_ratio=3,
        read_ahead=true,
        eight_row=true,
        aligned_extent=true,
        sixteen_row=true,
      )
    ["bridge-formal-negative-sixteen-row", root] =>
      ddr_evidence(
        root,
        true,
        true,
        wide=true,
        batch=true,
        streaming=true,
        clock_ratio=3,
        read_ahead=true,
        eight_row=true,
        aligned_extent=true,
        sixteen_row=true,
      )
    ["address-formal-sixteen-row", root] =>
      address_formal(root, false, sixteen_row=true)
    ["address-formal-negative-sixteen-row", root] =>
      address_formal(root, true, sixteen_row=true)
    ["export-short-unary-aligned", root] =>
      export_target(
        root,
        parallel=true,
        overlap=true,
        transfer=true,
        wide=true,
        batch=true,
        throughput=true,
        streaming=true,
        read_ahead=true,
        eight_row=true,
        short_unary=true,
        aligned_extent=true,
      )
    ["address-formal-aligned", root] => address_formal(root, false)
    ["address-formal-negative-aligned", root] => address_formal(root, true)
    ["bridge-replay-aligned-eight-row", root] =>
      ddr_evidence(
        root,
        false,
        false,
        wide=true,
        batch=true,
        streaming=true,
        clock_ratio=3,
        read_ahead=true,
        eight_row=true,
        aligned_extent=true,
      )
    ["bridge-formal-aligned-eight-row", root] =>
      ddr_evidence(
        root,
        true,
        false,
        wide=true,
        batch=true,
        streaming=true,
        clock_ratio=3,
        read_ahead=true,
        eight_row=true,
        aligned_extent=true,
      )
    ["bridge-formal-negative-aligned-eight-row", root] =>
      ddr_evidence(
        root,
        true,
        true,
        wide=true,
        batch=true,
        streaming=true,
        clock_ratio=3,
        read_ahead=true,
        eight_row=true,
        aligned_extent=true,
      )
    ["export-short-unary", root] =>
      export_target(
        root,
        parallel=true,
        overlap=true,
        transfer=true,
        wide=true,
        batch=true,
        throughput=true,
        streaming=true,
        read_ahead=true,
        eight_row=true,
        short_unary=true,
      )
    ["replay-short-unary", root] =>
      replay_bundle(
        root,
        parallel=true,
        overlap=true,
        wide=true,
        batch=true,
        throughput=true,
        eight_row=true,
        short_unary=true,
      )
    ["core-formal-short-unary", root] =>
      formal_bundle(
        root,
        false,
        core=true,
        parallel=true,
        overlap=true,
        wide=true,
        batch=true,
        throughput=true,
        eight_row=true,
        short_unary=true,
      )
    ["core-formal-negative-short-unary", root] =>
      formal_bundle(
        root,
        true,
        core=true,
        parallel=true,
        overlap=true,
        wide=true,
        batch=true,
        throughput=true,
        eight_row=true,
        short_unary=true,
      )
    ["replay-eight-row", root] =>
      replay_bundle(
        root,
        parallel=true,
        overlap=true,
        wide=true,
        batch=true,
        throughput=true,
        eight_row=true,
      )
    ["core-formal-eight-row", root] =>
      formal_bundle(
        root,
        false,
        core=true,
        parallel=true,
        overlap=true,
        wide=true,
        batch=true,
        throughput=true,
        eight_row=true,
      )
    ["core-formal-negative-eight-row", root] =>
      formal_bundle(
        root,
        true,
        core=true,
        parallel=true,
        overlap=true,
        wide=true,
        batch=true,
        throughput=true,
        eight_row=true,
      )
    ["formal-eight-row", root] =>
      formal_bundle(root, false, wide=true, batch=true, eight_row=true)
    ["formal-negative-eight-row", root] =>
      formal_bundle(root, true, wide=true, batch=true, eight_row=true)
    ["bridge-replay-eight-row", root] =>
      ddr_evidence(
        root,
        false,
        false,
        wide=true,
        batch=true,
        streaming=true,
        clock_ratio=3,
        read_ahead=true,
        eight_row=true,
      )
    ["bridge-formal-eight-row", root] =>
      ddr_evidence(
        root,
        true,
        false,
        wide=true,
        batch=true,
        streaming=true,
        clock_ratio=3,
        read_ahead=true,
        eight_row=true,
      )
    ["bridge-formal-negative-eight-row", root] =>
      ddr_evidence(
        root,
        true,
        true,
        wide=true,
        batch=true,
        streaming=true,
        clock_ratio=3,
        read_ahead=true,
        eight_row=true,
      )
    ["export-eight-row", root] =>
      export_target(
        root,
        parallel=true,
        overlap=true,
        transfer=true,
        wide=true,
        batch=true,
        throughput=true,
        streaming=true,
        read_ahead=true,
        eight_row=true,
      )
    ["significand-lane-compute", root] => export_significand_lane(root)
    ["ordered-mac-array", root] => export_ordered_mac(root)
    ["mig-read-benchmark", root] => export_mig_reader(root)
    ["ordered-mac-replay", root] => ordered_mac_replay(root)
    ["significand-lane-replay", root] => significand_replay(root)
    ["multiply-formal-compute", root] => compute_multiplier_formal(root, false)
    ["multiply-formal-negative-compute", root] =>
      compute_multiplier_formal(root, true)
    ["core-formal-negative-compute", root] =>
      formal_bundle(
        root,
        true,
        core=true,
        parallel=true,
        overlap=true,
        wide=true,
        batch=true,
        throughput=true,
        compute=true,
      )
    ["export-compute", root] =>
      export_target(
        root,
        parallel=true,
        overlap=true,
        transfer=true,
        wide=true,
        batch=true,
        throughput=true,
        streaming=true,
        compute=true,
      )
    ["replay-compute", root] =>
      replay_bundle(
        root,
        parallel=true,
        overlap=true,
        wide=true,
        batch=true,
        throughput=true,
        compute=true,
      )
    ["replay-compute-smoke", root] =>
      replay_bundle(
        root,
        parallel=true,
        overlap=true,
        wide=true,
        batch=true,
        throughput=true,
        compute=true,
        minimum_cycles=1,
      )
    ["core-formal-compute", root] =>
      formal_bundle(
        root,
        false,
        core=true,
        parallel=true,
        overlap=true,
        wide=true,
        batch=true,
        throughput=true,
        compute=true,
      )
    ["adder-pipe-formal-bounded", root] =>
      throughput_adder_pipeline_formal(root, false, bounded=true)
    ["adder-pipe-formal-negative-bounded", root] =>
      throughput_adder_pipeline_formal(root, true, bounded=true)
    ["adder-pipe-formal-throughput", root] =>
      throughput_adder_pipeline_formal(root, false)
    ["adder-pipe-formal-negative-throughput", root] =>
      throughput_adder_pipeline_formal(root, true)
    ["adder-formal-throughput", root] => throughput_adder_formal(root, false)
    ["adder-formal-negative-throughput", root] =>
      throughput_adder_formal(root, true)
    ["multiply-formal-throughput", root] =>
      throughput_adder_formal(root, false, product=true)
    ["multiply-formal-negative-throughput", root] =>
      throughput_adder_formal(root, true, product=true)
    ["export-throughput", root] =>
      export_target(
        root,
        parallel=true,
        overlap=true,
        transfer=true,
        wide=true,
        batch=true,
        throughput=true,
      )
    ["export-read-ahead", root] =>
      export_target(
        root,
        parallel=true,
        overlap=true,
        transfer=true,
        wide=true,
        batch=true,
        throughput=true,
        streaming=true,
        compute=true,
        read_ahead=true,
      )
    ["bridge-replay-read-ahead", root] =>
      ddr_evidence(
        root,
        false,
        false,
        wide=true,
        batch=true,
        streaming=true,
        clock_ratio=3,
        read_ahead=true,
      )
    ["bridge-formal-read-ahead", root] =>
      ddr_evidence(
        root,
        true,
        false,
        wide=true,
        batch=true,
        streaming=true,
        clock_ratio=3,
        read_ahead=true,
      )
    ["bridge-formal-negative-read-ahead", root] =>
      ddr_evidence(
        root,
        true,
        true,
        wide=true,
        batch=true,
        streaming=true,
        clock_ratio=3,
        read_ahead=true,
      )
    ["export-streaming", root] =>
      export_target(
        root,
        parallel=true,
        overlap=true,
        transfer=true,
        wide=true,
        batch=true,
        throughput=true,
        streaming=true,
      )
    ["bridge-formal-streaming", root] =>
      ddr_evidence(
        root,
        true,
        false,
        wide=true,
        batch=true,
        clock_ratio=3,
        streaming=true,
      )
    ["bridge-formal-negative-streaming", root] =>
      ddr_evidence(
        root,
        true,
        true,
        wide=true,
        batch=true,
        clock_ratio=3,
        streaming=true,
      )
    ["bridge-replay-streaming", root] =>
      ddr_evidence(
        root,
        false,
        false,
        wide=true,
        batch=true,
        clock_ratio=3,
        streaming=true,
      )
    ["replay-throughput-smoke", root] =>
      replay_bundle(
        root,
        parallel=true,
        overlap=true,
        wide=true,
        batch=true,
        throughput=true,
        minimum_cycles=1,
      )
    ["replay-throughput", root] =>
      replay_bundle(
        root,
        parallel=true,
        overlap=true,
        wide=true,
        batch=true,
        throughput=true,
      )
    ["core-formal-throughput", root] =>
      formal_bundle(
        root,
        false,
        core=true,
        parallel=true,
        overlap=true,
        wide=true,
        batch=true,
        throughput=true,
      )
    ["bridge-formal-throughput", root] =>
      ddr_evidence(root, true, false, wide=true, batch=true, clock_ratio=3)
    ["bridge-formal-negative-throughput", root] =>
      ddr_evidence(root, true, true, wide=true, batch=true, clock_ratio=3)
    ["export", root] => export_target(root)
    ["export-parallel", root] => export_target(root, parallel=true)
    ["export-overlap", root] => export_target(root, parallel=true, overlap=true)
    ["export-transfer", root] =>
      export_target(root, parallel=true, overlap=true, transfer=true)
    ["export-batch", root] =>
      export_target(
        root,
        parallel=true,
        overlap=true,
        transfer=true,
        wide=true,
        batch=true,
      )
    ["replay-batch", root] =>
      replay_bundle(root, parallel=true, overlap=true, wide=true, batch=true)
    ["bridge-replay-batch", root] =>
      ddr_evidence(root, false, false, wide=true, batch=true)
    ["bridge-formal-batch", root] =>
      ddr_evidence(root, true, false, wide=true, batch=true)
    ["bridge-formal-negative-batch", root] =>
      ddr_evidence(root, true, true, wide=true, batch=true)
    ["formal-batch", root] => formal_bundle(root, false, wide=true, batch=true)
    ["formal-negative-batch", root] =>
      formal_bundle(root, true, wide=true, batch=true)
    ["core-formal-batch", root] =>
      formal_bundle(
        root,
        false,
        core=true,
        parallel=true,
        overlap=true,
        wide=true,
        batch=true,
      )
    ["export-wide", root] =>
      export_target(root, parallel=true, overlap=true, transfer=true, wide=true)
    ["bridge-replay-transfer", root] => ddr_evidence(root, false, false)
    ["bridge-replay-wide", root] => ddr_evidence(root, false, false, wide=true)
    ["bridge-formal-wide", root] => ddr_evidence(root, true, false, wide=true)
    ["bridge-formal-negative-wide", root] =>
      ddr_evidence(root, true, true, wide=true)
    ["formal-wide", root] => formal_bundle(root, false, wide=true)
    ["formal-negative-wide", root] => formal_bundle(root, true, wide=true)
    ["core-formal-wide", root] =>
      formal_bundle(
        root,
        false,
        core=true,
        parallel=true,
        overlap=true,
        wide=true,
      )
    ["core-formal-negative-wide", root] =>
      formal_bundle(
        root,
        true,
        core=true,
        parallel=true,
        overlap=true,
        wide=true,
      )
    ["bridge-formal-transfer", root] => ddr_evidence(root, true, false)
    ["bridge-formal-negative-transfer", root] => ddr_evidence(root, true, true)
    ["fixture", source, root] => make_fixture(source, root)
    ["emulate", fixture, root] => emulate_fixture(fixture, root)
    ["replay", root] => replay_bundle(root)
    ["replay-parallel", root] => replay_bundle(root, parallel=true)
    ["replay-overlap", root] => replay_bundle(root, parallel=true, overlap=true)
    ["replay-wide", root] =>
      replay_bundle(root, parallel=true, overlap=true, wide=true)
    ["arithmetic-replay", root] => arithmetic_replay(root)
    ["pipeline-replay", root] => pipeline_replay(root)
    ["formal", root] => formal_bundle(root, false)
    ["formal-negative", root] => formal_bundle(root, true)
    ["core-formal", root] => formal_bundle(root, false, core=true)
    ["core-formal-parallel", root] =>
      formal_bundle(root, false, core=true, parallel=true)
    ["core-formal-overlap", root] =>
      formal_bundle(root, false, core=true, parallel=true, overlap=true)
    _ => fail("export NEW_ROOT | fixture SOURCE NEW_ROOT")
  }
}

///|
fn main {
  run() catch {
    e => abort("\{Repr(e)}")
  }
}
