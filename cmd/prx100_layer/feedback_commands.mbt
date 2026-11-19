///|
fn feedback_command(args : ArrayView[String]) -> Bool raise {
  match args {
    [mode, root] if mode == "unary-formal-interleaved" ||
      mode == "unary-formal-negative-interleaved" => {
      interleaved_unit_formal(root, mode.contains("negative"))
      true
    }
    ["export-feedback", root] => {
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
        feedback=true,
      )
      true
    }
    [mode, root] if mode == "export-delivery" || mode == "export-interleaved" => {
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
        feedback=true,
        delivery=true,
        interleaved=mode == "export-interleaved",
      )
      true
    }
    [mode, root] if ["replay-feedback", "replay-delivery", "replay-interleaved"].contains(
        mode,
      ) => {
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
        feedback=true,
        delivery=mode != "replay-feedback",
        interleaved=mode == "replay-interleaved",
      )
      true
    }
    [mode, root] if [
        "core-formal-feedback", "core-formal-negative-feedback", "core-formal-delivery",
        "core-formal-negative-delivery", "formal-delivery", "formal-negative-delivery",
        "core-formal-interleaved", "core-formal-negative-interleaved",
      ].contains(mode) => {
      formal_bundle(
        root,
        mode.contains("negative"),
        core=mode.has_prefix("core-"),
        parallel=true,
        overlap=true,
        wide=true,
        batch=true,
        throughput=true,
        eight_row=true,
        short_unary=true,
        sixteen_row=true,
        packed_weights=true,
        feedback=true,
        delivery=mode.has_suffix("delivery") || mode.has_suffix("interleaved"),
        interleaved=mode.has_suffix("interleaved"),
      )
      true
    }
    [mode, root] if [
        "bridge-replay-delivery", "bridge-formal-delivery", "bridge-formal-negative-delivery",
      ].contains(mode) => {
      ddr_evidence(
        root,
        mode != "bridge-replay-delivery",
        mode.contains("negative"),
        wide=true,
        batch=true,
        clock_ratio=3,
        streaming=true,
        read_ahead=true,
        eight_row=true,
        sixteen_row=true,
        aligned_extent=true,
        delivery=true,
      )
      true
    }
    _ => false
  }
}
