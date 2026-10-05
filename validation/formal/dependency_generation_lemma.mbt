///|
// Fixed-purpose proof input, not a replacement device or ordinary gate task.
fn dependency_generation_reference_field(
  role : @flux_tile.QueuedConcurrentFormalRole,
  post~ : Bool,
) -> String raise FormalGateError {
  let prefix = if post { "lc_g_post_" } else { "lc_g_" }
  let field = match role {
    NextTicket => "next"
    HeadTicket => "head"
    WriterStatus(index) => "status[\{index}]"
    WriterTicket(index) => "ticket[\{index}]"
    DependencyStatus(index) => "snapshot_status[\{index}]"
    DependencyTicket(index) => "snapshot_ticket[\{index}]"
    _ => raise InvalidFormalBundleIdentity("generation lemma: non-state role")
  }
  prefix + field
}

///|
fn dependency_generation_lemma_source(
  transfer : DependencyGenerationTransfer,
  emitted : @rtl.EmittedDesign,
) -> String raise {
  let plan = transfer.plan
  let out = StringBuilder()
  let declarations : Array[String] = []
  for cut in plan.cuts {
    declarations.push(
      "  input wire \{toggle_formal_width_range(cut.signal_type.width().bits())}cut_n\{cut.node.ordinal()}",
    )
  }
  for root in plan.roots {
    declarations.push(
      "  input wire \{toggle_formal_width_range(root.binding.signal_type.width().bits())}ghost_pre_\{dependency_role_name(root.binding.role)}",
    )
  }
  for
    name in [
      "base_obligation", "step_obligation", "priority_control", "rejection_control",
      "negated_control",
    ] {
    declarations.push("  output wire \{name}")
  }
  out.write_string(
    "`default_nettype none\nmodule lc_generation_lemma(\n\{declarations.join(",\n")}\n);\n",
  )
  let reference_arrays =
    #|  (* mem2reg *) wire [1:0] lc_g_status [0:5];
    #|  (* mem2reg *) wire [31:0] lc_g_ticket [0:5];
    #|  (* mem2reg *) wire [1:0] lc_g_snapshot_status [0:1];
    #|  (* mem2reg *) wire [31:0] lc_g_snapshot_ticket [0:1];
    #|  wire [31:0] lc_g_next, lc_g_head;
    #|
  out.write_string(reference_arrays)
  let pre_equal : Array[String] = []
  let post_equal : Array[String] = []
  let reset_zero : Array[String] = []
  for root in plan.roots {
    let role_name = dependency_role_name(root.binding.role)
    let pre = dependency_generation_reference_field(
      root.binding.role,
      post=false,
    )
    let post = dependency_generation_reference_field(
      root.binding.role,
      post=true,
    )
    out.write_string("  assign \{pre} = ghost_pre_\{role_name};\n")
    out.write_string(
      "  wire \{toggle_formal_width_range(root.binding.signal_type.width().bits())}dut_post_\{role_name};\n",
    )
    pre_equal.push("(cut_n\{root.binding.node.ordinal()} == \{pre})")
    post_equal.push("(dut_post_\{role_name} == \{post})")
    reset_zero.push("(dut_post_\{role_name} == 0 && \{post} == 0)")
  }
  for
    (name, width) in [
      ("local_fault", 4),
      ("local_reject", 1),
      ("public_halted", 1),
      ("decoder_syntax_fault", 4),
      ("decoder_source_0", 3),
      ("decoder_source_1", 3),
      ("decoder_is_writer", 1),
      ("decoder_writer_slot", 3),
      ("decoder_unused_ok", 1),
      ("decoder_dimensions_ok", 1),
    ] {
    out.write_string("  wire \{toggle_formal_width_range(width)}dut_\{name};\n")
  }
  let connections : Array[String] = []
  for cut in plan.cuts {
    let name = "cut_n\{cut.node.ordinal()}"
    connections.push(
      "    .\{port_identifier(emitted, InputPort, name)}(\{name})",
    )
  }
  for output in transfer.hardware.outputs() {
    let name = output.name()
    let target = "dut_" + name
    connections.push(
      "    .\{port_identifier(emitted, OutputPort, name)}(\{target})",
    )
  }
  out.write_string(
    "  \{top_emitted_module(emitted).identifier()} lc_transfer(\n\{connections.join(",\n")}\n  );\n",
  )
  out.write_string("  wire lc_reset = cut_n\{plan.reset.ordinal()};\n")
  // Expected fault consumes raw poison; reset-gated public halted is compared
  // separately. The reset base never assumes these two aliases equal.
  out.write_string("  wire lc_halted = cut_n\{plan.raw_poison.ordinal()};\n")
  for role in dependency_generation_boundary_roles() {
    let name = dependency_role_name(role)
    guard plan.cuts.filter(cut => cut.roles.contains(name)) is [cut] else {
      raise InvalidFormalBundleIdentity("generation lemma: missing boundary")
    }
    out.write_string(
      "  wire \{toggle_formal_width_range(cut.signal_type.width().bits())}lc_o_\{name} = cut_n\{cut.node.ordinal()};\n",
    )
  }
  // The unchanged decoder defines an unused inner-accept predicate too. These
  // constants have no generation fan-in and do not constrain a cut event.
  out.write_string(
    "  wire lc_o_inner_command_valid = 1'b0;\n  wire lc_o_inner_command_ready = 1'b0;\n",
  )
  out.write_string(dependency_decode_source())
  out.write_string(dependency_generation_comb_reference_source())
  out.write_string("  wire pre_equal = \{pre_equal.join(" && ")};\n")
  out.write_string("  wire post_equal = \{post_equal.join(" && ")};\n")
  out.write_string("  wire reset_zero = \{reset_zero.join(" && ")};\n")
  let obligations =
    #|  // Raw source projections remain defined for malformed descriptors.
    #|  // Semantic predicates use truncated production fields, so compare
    #|  // those only when the independent full-byte syntax check succeeds.
    #|  wire decoder_equal = dut_decoder_syntax_fault == lc_raw_syntax_fault
    #|    && dut_decoder_source_0 == lc_raw_source0
    #|    && dut_decoder_source_1 == lc_raw_source1
    #|    && (!lc_raw_syntax_ok || (dut_decoder_is_writer == lc_raw_is_writer
    #|      && dut_decoder_writer_slot == lc_raw_writer_slot
    #|      && dut_decoder_unused_ok == lc_raw_unused_ok
    #|      && dut_decoder_dimensions_ok == lc_raw_dimensions_ok));
    #|  wire rejection_equal = dut_local_fault == lc_g_expected_local_fault
    #|    && dut_local_reject == lc_g_expected_reject;
    #|  wire halted_equal = dut_public_halted == (!lc_reset && lc_halted);
    #|  assign base_obligation = !lc_reset || (post_equal && reset_zero && halted_equal);
    #|  assign step_obligation = lc_reset || !pre_equal
    #|    || (decoder_equal && post_equal && rejection_equal && halted_equal);
    #|  // Mutations affect comparisons only. Positive states/events stay free.
    #|  wire priority_case = !lc_reset && pre_equal && lc_g_intent[0]
    #|    && lc_g_collect[0] && lc_g_ticket[0] != lc_g_next;
    #|  assign priority_control = !priority_case
    #|    || (dut_post_writer_ticket_0 == lc_g_ticket[0]);
    #|  wire rejection_case = !lc_reset && pre_equal && lc_g_expected_reject
    #|    && (lc_g_expected_local_fault == 4'd4 || lc_g_expected_local_fault == 4'd5);
    #|  assign rejection_control = !rejection_case
    #|    || ((!dut_local_reject) == lc_g_expected_reject);
    #|  assign negated_control = !step_obligation;
    #|endmodule
    #|`default_nettype wire
    #|
  out.write_string(obligations)
  out.to_string()
}

///|
/// Export fixed local generation proof inputs, not a proof receipt or ordinary
/// dependency task. All state/event inputs are free; tools must select the
/// explicit base/step implications and validate the three sensitivity controls.
/// Decoder comparisons use exact private production nodes; this does not
/// compose the lemma into full-device safety.
pub fn generate_dependency_generation_lemma_artifacts() -> ReadOnlyArray[
  FormalBundleArtifact,
] raise {
  let fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let transfer = dependency_generation_materialize(fixture)
  let design = @ir.Design::single(
    "DependencyGenerationTransfer",
    transfer.hardware,
  )
  let emitted = @rtl.emit_design(design)
  let production = top_emitted_module(emitted).source()
  let (boolean_source, _) = dependency_boolean_helpers(
    transfer.hardware,
    production,
  )
  let lemma = dependency_generation_lemma_source(transfer, emitted)
  let artifacts : Array[FormalBundleArtifact] = [
    {
      path: "production.lcir",
      content: @ir_codec.serialize(
        @ir.Design::single(
          "QueuedConcurrentDependencyPilot",
          fixture.hardware(),
        ),
      ),
    },
    { path: "transfer.lcir", content: @ir_codec.serialize(design), },
    { path: "transfer-production.sv", content: production, },
    { path: "transfer-boolean.sv", content: boolean_source, },
    { path: "decoder.svfragment", content: dependency_decode_source(), },
    {
      path: "reference.svfragment",
      content: dependency_generation_comb_reference_source(),
    },
    { path: "lemma.sv", content: lemma, },
  ]
  let inventory = StringBuilder()
  inventory.write_string(
    "SCOPE local-generation-inputs-only-no-receipt-or-composition\n",
  )
  inventory.write_string("STATE independent-DUT-and-ghost-pre-336-bits-each\n")
  inventory.write_string(
    "CUTS exact-original-node-aliases-free-binary-no-event-assumptions\n",
  )
  for cut in transfer.plan.cuts {
    inventory.write_string(
      "CUT node \{cut.node.ordinal()} width \{cut.signal_type.width().bits()} roles \{cut.roles.iter().to_array().join(",")}\n",
    )
  }
  for binding in transfer.plan.decoder_bindings {
    inventory.write_string(
      "DECODER \{binding.name} node \{binding.node.ordinal()} width \{binding.signal_type.width().bits()} type \{Repr(binding.signal_type)}\n",
    )
  }
  for artifact in artifacts {
    inventory.write_string(
      "SOURCE \{artifact.path} sha256 \{sha256_hex(artifact.content)}\n",
    )
  }
  artifacts.push({ path: "inputs.txt", content: inventory.to_string(), })
  ReadOnlyArray::from_array(artifacts)
}
