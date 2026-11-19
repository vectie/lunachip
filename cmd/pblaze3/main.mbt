///|
fn save(root : String, name : String, text : String) -> Unit raise {
  @fs.write_string_to_file(root + "/" + name, text)
}

///|
fn export_target(
  root : String,
  streaming~ : Bool = false,
  profile~ : Bool = false,
  vectors~ : Bool = false,
  wide512~ : Bool = false,
  rows64~ : Bool = false,
  banked64~ : Bool = false,
  prefetch256~ : Bool = false,
  scalar_lines~ : Bool = false,
  store_bursts~ : Bool = false,
  chain~ : Bool = false,
  program_bursts~ : Bool = false,
  stream_unary~ : Bool = false,
  staged_decode~ : Bool = false,
  stream_reductions~ : Bool = false,
  paired_rows~ : Bool = false,
  full_rows~ : Bool = false,
  dual_read~ : Bool = false,
  indirect_bf16~ : Bool = false,
  bounded_add~ : Bool = false,
  deep_batch~ : Bool = false,
  strided_rows~ : Bool = false,
  ordered_array~ : Bool = false,
  staged_fill~ : Bool = false,
  staged_add_inputs~ : Bool = false,
  group64_rows~ : Bool = false,
  stripe512~ : Bool = false,
  prefetch_row_blocks~ : Bool = false,
  staged_unary_inputs~ : Bool = false,
  staged_reduction_term~ : Bool = false,
  staged_scalar_add~ : Bool = false,
  staged_scalar_alignment~ : Bool = false,
  deep_fp32_add~ : Bool = false,
  registered_payload~ : Bool = false,
  staged_response_last~ : Bool = false,
  staged_broadcast~ : Bool = false,
  compact_multiply_pack~ : Bool = false,
  staged_multiply_product~ : Bool = false,
  incremental_row_address~ : Bool = false,
  registered_multiply_inputs~ : Bool = false,
  staged_issue~ : Bool = false,
  full_mac_product~ : Bool = false,
  eager_weight_reads~ : Bool = false,
  state_scratch_mux~ : Bool = false,
  direct_reduction_writeback~ : Bool = false,
) -> Unit raise {
  guard !@fs.path_exists(root) else { fail("fresh output directory required") }
  let core = if vectors {
    @fp.interleaved_layer_machine(
      memory=GiB2,
      pipelined_vectors=true,
      wide512~,
      rows64~,
      banked64~,
      prefetch256~,
      scalar_lines~,
      store_bursts~,
      stream_unary~,
      staged_decode~,
      stream_reductions~,
      paired_rows~,
      full_rows~,
      dual_read~,
      indirect_bf16~,
      bounded_add~,
      deep_batch~,
      strided_rows~,
      ordered_array~,
      staged_add_inputs~,
      group64_rows~,
      stripe512~,
      prefetch_row_blocks~,
      staged_unary_inputs~,
      staged_reduction_term~,
      staged_scalar_add~,
      staged_scalar_alignment~,
      deep_fp32_add~,
      compact_multiply_pack~,
      staged_multiply_product~,
      incremental_row_address~,
      registered_multiply_inputs~,
      eager_weight_reads~,
      state_scratch_mux~,
      direct_reduction_writeback~,
    )
  } else {
    @fp.feedback_layer_machine(delivery=true, memory=GiB2)
  }
  let control = @target.controller(
    group64_rows~,
    stripe512~,
    prefetch_row_blocks~,
    deep_batch~,
    strided_rows~,
    indirect_bf16~,
    stream_unary~,
    chain~,
    program_bursts~,
    profile~,
    wide512~,
    wide1024=prefetch256,
    scalar_lines~,
    store_bursts~,
  )
  let bridge = @axi.bridge(
    staged_response_last~,
    group64_rows~,
    stripe512~,
    prefetch_row_blocks~,
    staged_fill~,
    deep_batch~,
    strided_rows~,
    streaming~,
    wide512~,
    wide1024=prefetch256,
    store_bursts~,
  )
  @fs.create_dir(root)
  let names : Array[String] = []
  let emitted = [
    (core, "core", "pblaze3-qwen-layer/v1"),
    (control, "controller", "pblaze3-layer-control/v1"),
    (bridge, "bridge", "pblaze3-axi-memory/v1"),
  ].map(item => {
    let (hw, name, semantic) = item
    let design = @ir.Design::single(semantic, hw)
    save(root, name + ".lcir", @codec.serialize(design))
    let e = @sv.emit_design(design) catch {
      @sv.UnreachableNode(module_name~, node~) =>
        fail("unreachable node \{node} in \{module_name}")
      e => raise e
    }
    save(root, name + "-ordinary.sv", e.source())
    save(
      root,
      name + ".sv",
      if name == "core" {
        memory_style(normalize(optimized(e.source())))
      } else {
        normalize(optimized(e.source()))
      },
    )
    save(root, name + ".names", e.manifest().to_canonical_text())
    for suffix in [".lcir", "-ordinary.sv", ".sv", ".names"] {
      names.push(name + suffix)
    }
    e
  })
  if ordered_array {
    let design = @ir.Design::single(
      "qwen-ordered-bf16-mac/v1",
      @fp.ordered_bf16_mac_lane(full_product=full_mac_product),
    )
    let lane = @sv.emit_design(design)
    let array = @system.ordered_array_rtl(
      lane,
      normalize(optimized(lane.source())),
      staged_broadcast~,
    )
    save(root, "ordered-array.sv", array)
    save(root, "ordered-lane.lcir", @codec.serialize(design))
    names.push("ordered-array.sv")
    names.push("ordered-lane.lcir")
    let scalar = @fs.read_file_to_string(root + "/core.sv")
    save(
      root,
      "core.sv",
      scalar +
      "\n" +
      array +
      "\n" +
      @system.ordered_clock_bridge_rtl(
        registered_payload~,
        staged_broadcast~,
        staged_issue~,
      ) +
      "\n",
    )
  }
  save(
    root,
    "pblaze3_layer_system.sv",
    @system.wrapper(core, emitted[0], control, emitted[1], bridge, emitted[2]),
  )
  names.push("pblaze3_layer_system.sv")
  let sources = [
    "core.sv", "controller.sv", "bridge.sv", "pblaze3_layer_system.sv",
  ]
  let job : Json = {
    "schema": "pblaze3-digital-export/v1",
    "top": "pblaze3_layer_system",
    "part": "xc7k325tffg900-2",
    "memory_bytes": "2147483648",
    "profile": "provisional-8x256MiB",
    "accelerator_axi_data_bits": if prefetch256 {
      1024
    } else if wide512 {
      512
    } else if streaming {
      256
    } else {
      128
    },
    "core_period_ns": "30.000",
    "axi_lite_base": "0x40000000",
    "axi_lite_bytes": 1048576,
    "control_abi": "0x00010001",
    "accepted_launch_sequence_offset": "0x38",
    "sources": sources.map(name => {
      "path": name,
      "sha256": @v.sha256_hex(@fs.read_file_to_string(root + "/" + name)),
    }),
    "evidence": {
      "elaborated": true,
      "synthesized": false,
      "routed": false,
      "board_tested": false,
    },
  }
  if vectors && job is Object(fields) {
    if state_scratch_mux {
      fields["state_owned_scratch_write_selection"] = true
      fields["scratch_write_latency_unchanged"] = true
    }
    if eager_weight_reads {
      fields["eager_ordered_weight_reads"] = true
      fields["ordered_weight_read_edges"] = 1
      fields["ordered_weight_payload_valid_only"] = true
    }
    if full_mac_product {
      fields["ordered_full_significand_product"] = true
      fields["ordered_significand_edges"] = 13
    }
    if staged_decode {
      fields["staged_descriptor_validation"] = true
    }
    if stream_reductions {
      fields["stream_ordered_reductions"] = true
    }
    if paired_rows {
      fields["matrix_accumulator_rows"] = if ordered_array { 512 } else { 128 }
    }
    if full_rows && !ordered_array {
      fields["contiguous_weight_row_columns"] = 1024
    }
    if dual_read {
      fields["scratch_operand_read_ports"] = 2
    }
    if strided_rows && !ordered_array {
      fields["strided_weight_rows"] = true
    }
    if deep_batch && !ordered_array {
      fields["contiguous_weight_group_bytes"] = 32768
    }
    if bounded_add {
      fields["bounded_adder_pipeline"] = true
    }
    if indirect_bf16 {
      fields["indirect_bf16_load"] = true
    }
    if stream_unary {
      fields["stream_unary_min_elements"] = 64
    }
    if program_bursts {
      fields["resident_program_burst_bytes"] = 512
    }
    if chain {
      fields["resident_chain_max_descriptors"] = 65535
    }
    if group64_rows {
      fields["strided_weight_group_rows"] = 64
      fields["strided_weight_group_bytes"] = 32768
    }
    if stripe512 {
      fields["aligned_weight_group_rows"] = 32
      fields["aligned_weight_burst_bytes"] = 1024
    }
    if prefetch_row_blocks {
      fields["aligned_full_stripe_group_rows"] = 512
      fields["aligned_full_stripe_max_outstanding_bursts"] = 16
    }
    if staged_add_inputs {
      fields["vector_add_input_stage"] = true
    }
    if staged_unary_inputs {
      fields["shared_unary_add_input_stage"] = true
    }
    if direct_reduction_writeback {
      fields["reduction_writeback_from_accumulator"] = true
    }
    if staged_scalar_add {
      fields["registered_scalar_add_normalization"] = true
    }
    if staged_scalar_alignment {
      fields["registered_scalar_add_alignment"] = true
    }
    if deep_fp32_add {
      fields["deep_fp32_add"] = true
      fields["ordered_reduction_issue_interval"] = 4
      fields["shared_unary_context_interval"] = 6
    }
    if registered_payload {
      fields["ordered_payload_read_edges"] = 2
    }
    if staged_response_last {
      fields["predicted_response_last"] = true
    }
    if staged_broadcast {
      fields["ordered_broadcast_edges"] = 1
      fields["ordered_activation_groups"] = 8
    }
    if compact_multiply_pack {
      fields["compact_multiply_pack"] = true
    }
    if staged_multiply_product {
      fields["scheduler_multiply_edges"] = 4
      fields["scheduler_scalar_execute_phase"] = 5
      fields["scheduler_reduction_retire_edges"] = 8
    }
    if incremental_row_address {
      fields["incremental_row_address"] = true
      fields["descriptor_group_stride_edges"] = 2
    }
    if registered_multiply_inputs {
      fields["scheduler_multiply_input_edges"] = 1
      fields["scheduler_multiply_edges"] = 5
      fields["scheduler_scalar_execute_phase"] = 6
      fields["scheduler_reduction_retire_edges"] = 9
    }
    if staged_issue {
      fields["ordered_issue_edges"] = 1
    }
    if staged_reduction_term {
      fields["registered_reduction_term"] = true
    }
    if staged_fill {
      fields["store_fill_bank_words"] = 8
    }
    if store_bursts {
      fields["scalar_store_burst_bytes"] = 256
    }
    if scalar_lines {
      fields["scalar_load_line_bytes"] = 128
    }
    if prefetch256 {
      fields["row_major_prefetch_columns"] = 256
    }
    if banked64 {
      fields["weight_buffer_banks"] = 64
    }
    if rows64 {
      fields["row_major_product_lanes"] = 64
    }
    if ordered_array {
      fields["ordered_command_payload_entries"] = 64
      fields["ordered_command_metadata_bits"] = 16
      fields["ordered_mac_row_slots"] = 18
      fields["ordered_mac_pipeline_edges"] = 46
      fields["matrix_stripe_max_columns"] = if stripe512 { 512 } else { 256 }
      fields["contiguous_weight_group_bytes"] = 8192
    }
    fields["jtag_inference_core_hz"] = if ordered_array {
      75000000
    } else if paired_rows {
      80000000
    } else if staged_decode {
      50000000
    } else {
      40000000
    }
  }
  save(root, "job.json", job.stringify(indent=2) + "\n")
  names.push("job.json")
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
  println("exported provisional PBlaze3 2 GiB digital target: " + root)
}

///|
fn main raise {
  let argv = @env.args()[1:].to_owned()
  let state_scratch_mux = match argv {
    [
      "export-inference-ordered-array-fast-scheduler",
      _,
      "staged-reduction-stripe512-prefetch-scalar-deep-payload-last-broadcast-pack-product-address-ingress-dsp-eager-owner",
    ] => true
    _ => false
  }
  if state_scratch_mux {
    argv[2] = "staged-reduction-stripe512-prefetch-scalar-deep-payload-last-broadcast-pack-product-address-ingress-dsp-eager"
  }
  let eager_weight_reads = match argv {
    [
      "export-inference-ordered-array-fast-scheduler",
      _,
      "staged-reduction-stripe512-prefetch-scalar-deep-payload-last-broadcast-pack-product-address-ingress-dsp-eager",
    ] => true
    _ => false
  }
  if eager_weight_reads {
    argv[2] = "staged-reduction-stripe512-prefetch-scalar-deep-payload-last-broadcast-pack-product-address-ingress-dsp"
  }
  let full_mac_product = match argv {
    [
      "export-inference-ordered-array-fast-scheduler",
      _,
      "staged-reduction-stripe512-prefetch-scalar-deep-payload-last-broadcast-pack-product-address-ingress-dsp",
    ] => true
    _ => false
  }
  if full_mac_product {
    argv[2] = "staged-reduction-stripe512-prefetch-scalar-deep-payload-last-broadcast-pack-product-address-ingress"
  }
  let registered_multiply_inputs = match argv {
    [
      "export-inference-ordered-array-fast-scheduler",
      _,
      "staged-reduction-stripe512-prefetch-scalar-deep-payload-last-broadcast-pack-product-address-ingress",
    ] => true
    _ => false
  }
  let staged_issue = registered_multiply_inputs
  if registered_multiply_inputs {
    argv[2] = "staged-reduction-stripe512-prefetch-scalar-deep-payload-last-broadcast-pack-product-address"
  }
  let incremental_row_address = match argv {
    [
      "export-inference-ordered-array-fast-scheduler",
      _,
      "staged-reduction-stripe512-prefetch-scalar-deep-payload-last-broadcast-pack-product-address",
    ] => true
    _ => false
  }
  if incremental_row_address {
    argv[2] = "staged-reduction-stripe512-prefetch-scalar-deep-payload-last-broadcast-pack-product"
  }
  let staged_multiply_product = match argv {
    [
      "export-inference-ordered-array-fast-scheduler",
      _,
      "staged-reduction-stripe512-prefetch-scalar-deep-payload-last-broadcast-pack-product",
    ] => true
    _ => false
  }
  if staged_multiply_product {
    argv[2] = "staged-reduction-stripe512-prefetch-scalar-deep-payload-last-broadcast-pack"
  }
  let compact_multiply_pack = match argv {
    [
      "export-inference-ordered-array-fast-scheduler",
      _,
      "staged-reduction-stripe512-prefetch-scalar-deep-payload-last-broadcast-pack",
    ] => true
    _ => false
  }
  if compact_multiply_pack {
    argv[2] = "staged-reduction-stripe512-prefetch-scalar-deep-payload-last-broadcast"
  }
  let staged_broadcast = match argv {
    [
      "export-inference-ordered-array-fast-scheduler",
      _,
      "staged-reduction-stripe512-prefetch-scalar-deep-payload-last-broadcast",
    ] => true
    _ => false
  }
  if staged_broadcast {
    argv[2] = "staged-reduction-stripe512-prefetch-scalar-deep-payload-last"
  }
  let staged_response_last = match argv {
    [
      "export-inference-ordered-array-fast-scheduler",
      _,
      "staged-reduction-stripe512-prefetch-scalar-deep-payload-last",
    ] => true
    _ => false
  }
  if staged_response_last {
    argv[2] = "staged-reduction-stripe512-prefetch-scalar-deep-payload"
  }
  let (
    args,
    staged_add_inputs,
    group64_rows,
    staged_unary_inputs,
    stripe512,
    prefetch_row_blocks,
    staged_reduction_term,
    staged_scalar_add,
    staged_scalar_alignment,
    deep_fp32_add,
    registered_payload,
    direct_reduction_writeback,
  ) = match argv[:] {
    ["export-inference-ordered-array-fast-scheduler" as kind, root, mode] if mode ==
      "staged-add" ||
      mode == "staged-add-group32" ||
      mode == "staged-add-group32-unary" ||
      mode == "staged-add-stripe512" ||
      mode == "staged-reduction" ||
      mode == "staged-reduction-stripe512" ||
      mode == "staged-reduction-stripe512-prefetch" ||
      mode == "staged-reduction-stripe512-prefetch-scalar" ||
      mode == "staged-reduction-stripe512-prefetch-scalar-payload" ||
      mode == "staged-reduction-stripe512-prefetch-scalar-deep-payload" ||
      mode == "staged-reduction-stripe512-scalar" ||
      mode == "staged-reduction-stripe512-writeback" ||
      mode == "staged-reduction-stripe512-prefetch-writeback" =>
      (
        [kind, root],
        true,
        mode != "staged-add",
        mode != "staged-add" && mode != "staged-add-group32",
        mode == "staged-add-stripe512" ||
        mode.has_prefix("staged-reduction-stripe512"),
        mode.has_prefix("staged-reduction-stripe512-prefetch"),
        mode.has_prefix("staged-reduction"),
        mode == "staged-reduction-stripe512-scalar" ||
        mode.has_prefix("staged-reduction-stripe512-prefetch-scalar") ||
        mode.has_suffix("-writeback"),
        mode.has_prefix("staged-reduction-stripe512-prefetch-scalar"),
        mode == "staged-reduction-stripe512-prefetch-scalar-deep-payload",
        mode.has_suffix("-payload"),
        mode.has_suffix("-writeback"),
      )
    other =>
      (
        other.to_owned(),
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
      )
  }
  match args {
    ["export-compact-multiply-formal", root] =>
      export_compact_multiply_formal(root, false)
    ["export-compact-multiply-formal-negative", root] =>
      export_compact_multiply_formal(root, true)
    ["export-full-product-formal", root] =>
      export_full_product_formal(root, false)
    ["export-full-product-formal-negative", root] =>
      export_full_product_formal(root, true)
    ["export-mig-monitor", root] => export_mig_monitor(root)
    ["contract"] => println(@host.device_contract_json())
    ["export", root] => export_target(root)
    ["export-streaming-baseline", root] => export_target(root, streaming=true)
    ["export-profile", root] =>
      export_target(root, streaming=true, profile=true)
    ["export-inference-512", root] | ["export-inference", root] =>
      export_target(
        root,
        streaming=true,
        profile=true,
        vectors=true,
        wide512=true,
      )
    ["export-inference-64", root] =>
      export_target(
        root,
        streaming=true,
        profile=true,
        vectors=true,
        wide512=true,
        rows64=true,
      )
    [kind, root] if kind == "export-inference-64-prefetch" ||
      kind == "export-inference-64-load-lines" ||
      kind == "export-inference-64-store-bursts" ||
      kind == "export-inference-64-chain" ||
      kind == "export-inference-64-program-bursts" ||
      kind == "export-inference-64-stream-unary" ||
      kind == "export-inference-64-staged-decode" ||
      kind == "export-inference-64-stream-reductions" ||
      kind == "export-inference-64-paired-rows" ||
      kind == "export-inference-64-full-rows" ||
      kind == "export-inference-64-dual-read" ||
      kind == "export-inference-64-bf16-load" ||
      kind == "export-inference-64-bounded-add" ||
      kind == "export-inference-64-group32k" ||
      kind == "export-inference-64-strided-rows" ||
      kind == "export-inference-ordered-array" ||
      kind == "export-inference-ordered-array-fast-scheduler" => {
      let staged_fill = kind == "export-inference-ordered-array-fast-scheduler"
      let ordered_array = staged_fill ||
        kind == "export-inference-ordered-array"
      let strided_rows = ordered_array ||
        kind == "export-inference-64-strided-rows"
      let deep_batch = strided_rows || kind == "export-inference-64-group32k"
      let bounded_add = deep_batch || kind == "export-inference-64-bounded-add"
      let indirect_bf16 = bounded_add || kind == "export-inference-64-bf16-load"
      let dual_read = indirect_bf16 || kind == "export-inference-64-dual-read"
      let full_rows = dual_read || kind == "export-inference-64-full-rows"
      let paired_rows = full_rows || kind == "export-inference-64-paired-rows"
      let stream_reductions = paired_rows ||
        kind == "export-inference-64-stream-reductions"
      let staged_decode = stream_reductions ||
        kind == "export-inference-64-staged-decode"
      let stream_unary = staged_decode ||
        kind == "export-inference-64-stream-unary"
      export_target(
        root,
        streaming=true,
        profile=true,
        vectors=true,
        wide512=true,
        rows64=true,
        banked64=true,
        prefetch256=true,
        scalar_lines=kind != "export-inference-64-prefetch",
        store_bursts=kind == "export-inference-64-store-bursts" ||
          kind == "export-inference-64-chain" ||
          kind == "export-inference-64-program-bursts" ||
          stream_unary,
        chain=kind == "export-inference-64-chain" ||
          kind == "export-inference-64-program-bursts" ||
          stream_unary,
        program_bursts=kind == "export-inference-64-program-bursts" ||
          stream_unary,
        stream_unary~,
        staged_decode~,
        stream_reductions~,
        paired_rows~,
        full_rows~,
        dual_read~,
        indirect_bf16~,
        bounded_add~,
        deep_batch~,
        strided_rows~,
        ordered_array~,
        staged_fill~,
        staged_add_inputs~,
        group64_rows~,
        stripe512~,
        prefetch_row_blocks~,
        staged_unary_inputs~,
        staged_reduction_term~,
        staged_scalar_add~,
        staged_scalar_alignment~,
        deep_fp32_add~,
        registered_payload~,
        staged_response_last~,
        staged_broadcast~,
        compact_multiply_pack~,
        staged_multiply_product~,
        incremental_row_address~,
        registered_multiply_inputs~,
        staged_issue~,
        full_mac_product~,
        eager_weight_reads~,
        state_scratch_mux~,
        direct_reduction_writeback~,
      )
    }
    ["export-inference-64-banked", root] =>
      export_target(
        root,
        streaming=true,
        profile=true,
        vectors=true,
        wide512=true,
        rows64=true,
        banked64=true,
      )
    ["export-inference-256", root] | ["export-vector-profile", root] =>
      export_target(root, streaming=true, profile=true, vectors=true)
    _ =>
      fail(
        "usage: pblaze3 contract | export|export-inference|export-inference-256|export-inference-512|export-inference-64|export-inference-64-banked|export-inference-64-prefetch|export-inference-64-load-lines|export-inference-64-store-bursts|export-inference-64-chain|export-inference-64-program-bursts|export-inference-64-stream-unary|export-inference-64-staged-decode|export-inference-64-stream-reductions|export-inference-64-paired-rows|export-inference-64-full-rows|export-inference-64-dual-read|export-inference-64-bf16-load|export-inference-ordered-array|export-inference-ordered-array-fast-scheduler|export-streaming-baseline|export-profile|export-vector-profile NEW_OUTPUT_DIRECTORY",
      )
  }
}
