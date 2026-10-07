///|
// Independent whole-header reconstruction + complete original-body check.
// Shared test naming/type/comparison oracles do not call this slice's adapter.
fn dependency_conjunction_proof_test_observer(
  inputs : DependencyConjunctionProofInputs,
  source : String,
) -> String raise {
  let sequential = inputs.sequential
  guard inputs.emitted
    .modules()
    .filter(item => {
      item.module_ordinal() == inputs.emitted.manifest().top_module_ordinal()
    })
    is [dut] else {
    fail("nonunique top")
  }
  let lines : Array[String] = []
  let declarations = StringBuilder()
  for node in sequential.hardware.nodes() {
    guard node.kind() is Input(name) else { continue }
    let identifier = queue_storage_export_test_name(
      inputs.emitted,
      InputPort,
      node.id().ordinal(),
    )
    let signal_type = queue_storage_export_test_type(node.signal_type())
    lines.push("input \{signal_type} \{identifier}")
    if name == "clock" {
      declarations.write_string(
        "  logic \{identifier} = 1'b0;\n  always @($global_clock) \{identifier} <= ~\{identifier};\n  wire lc_clock = \{identifier};\n",
      )
    } else {
      declarations.write_string(
        "  (* anyseq *) \{signal_type} \{identifier};\n",
      )
    }
  }
  for index, output in sequential.hardware.outputs() {
    let identifier = queue_storage_export_test_name(
      inputs.emitted,
      OutputPort,
      index,
    )
    let signal_type = queue_storage_export_test_type(output.signal_type())
    lines.push("output \{signal_type} \{identifier}")
    declarations.write_string("  \{signal_type} \{identifier};\n")
  }
  let ports = StringBuilder()
  for index, line in lines {
    let comma = if index + 1 == lines.length() { "" } else { "," }
    ports.write_string("  \{line}\{comma}\n")
  }
  let header = "module \{dut.identifier()} (\n" + ports.to_string() + ");\n\n"
  let replacement = "module \{dut.identifier()};\n" +
    declarations.to_string() +
    "\n"
  let boolean = queue_storage_export_test_boolean(
    sequential.hardware,
    dut.source(),
  )
  assert_eq(inputs.boolean_source, boolean)
  guard boolean.split(header).to_array() is [preamble, tail] else {
    fail("complete header")
  }
  guard tail.split("endmodule\n").to_array() is [body, suffix] else {
    fail("complete body ending")
  }
  let prefix = preamble.to_owned() + replacement + body.to_owned()
  guard source.split(prefix).to_array() is ["", observed_tail] else {
    fail("production body changed")
  }
  guard observed_tail.split("endmodule\n").to_array()
    is [observer, observed_suffix] else {
    fail("observer ending")
  }
  assert_eq(observed_suffix, suffix)
  observer.to_owned()
}

///|
fn dependency_conjunction_proof_test_original_tail(
  variant : DependencyFormalFixture,
) -> String raise {
  let carrier : DependencyFormalDut = {
    identifier: "NotInstantiated",
    filename: "",
    source: "",
    production_filename: "",
    production_source: "",
    ports: [],
    observation_ports: [],
  }
  let (properties, _, _, _) = dependency_property_export(LatestWriter)
  let original = dependency_harness(variant, carrier, properties.source())
  let decoder = dependency_decode_source()
  guard original.split(decoder).to_array() is [_, tail] else {
    fail("original complete decoder")
  }
  guard tail.split("endmodule\n`default_nettype wire\n").to_array()
    is [body, ""] else {
    fail("original complete harness end")
  }
  decoder + body.to_owned()
}

///|
test "dependency proof inputs retain whole production body original decoder ghost sixteen properties and three controls" {
  let queue_fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let dependency_fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let before = @ir_codec.serialize(
    @ir.Design::single(
      "QueuedConcurrentQueueConservationPilot",
      queue_fixture.hardware(),
    ),
  )
  let inputs = dependency_conjunction_proof_inputs(
    queue_fixture, dependency_fixture,
  )
  let sequential = inputs.sequential
  assert_eq(
    sha256_hex(before),
    "35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc",
  )
  assert_eq(
    sequential.inventory_digest,
    "442cb1ac95b10b5e4c8cd9983ca80c9e2b93bbf07e08588d21214ad92f9e1fa4",
  )
  assert_eq(
    sha256_hex(
      @ir_codec.serialize(
        @ir.Design::single(
          "DependencyConjunctionSequential",
          sequential.hardware,
        ),
      ),
    ),
    "26214abad606bbe414fa9a7186d47fc9d7766bae3481d38f7b5aaa5c636860cd",
  )
  let observer = dependency_conjunction_proof_test_observer(
    inputs,
    inputs.positive,
  )
  let (original_properties, legal, assertions, covers) = dependency_property_export(
    LatestWriter,
  )
  assert_eq(inputs.properties, original_properties)
  assert_eq(legal.length(), 4)
  assert_eq(assertions.length(), 7)
  assert_eq(covers.length(), 5)
  assert_eq(inputs.global_assertions, ["lc_dependency_nonrising_hold"])
  assert_eq(inputs.negatives.length(), 3)
  let sources = [
    inputs.positive,
    inputs.negatives[0],
    inputs.negatives[1],
    inputs.negatives[2],
  ]
  for source in sources {
    let observed = dependency_conjunction_proof_test_observer(inputs, source)
    assert_eq(source.split("(* anyseq *)").count(), 79)
    assert_eq(observed.split(dependency_decode_source()).count(), 2)
    assert_eq(observed.split(dependency_ghost_source()).count(), 2)
    assert_eq(observed.split(original_properties.source()).count(), 2)
    assert_eq(observed.split("lc_dependency_nonrising_hold: assert").count(), 2)
    assert_false(observed.contains("generation_all_boundary_matches_reference"))
    for property in original_properties.properties() {
      let operation = match property.kind() {
        Assumption => "assume"
        Assertion => "assert"
        Cover => "cover"
      }
      let block = "  always @(posedge lc_clock) begin\n    \{property.stable_name()}: \{operation} ((lc_\{property.source_name()}) === 1'b1);\n  end\n"
      assert_eq(source.split(block).count(), 2)
    }
    for label in inputs.memory_bounds {
      assert_eq(source.split(label + ": assert").count(), 2)
    }
    for cut in sequential.cuts {
      let mapped = queue_storage_test_node(
        sequential.original_to_local,
        cut.node,
      )
      let identifier = queue_storage_export_test_name(
        inputs.emitted,
        InputPort,
        mapped.ordinal(),
      )
      let declaration = "  (* anyseq *) \{queue_storage_export_test_type(cut.signal_type)} \{identifier};\n"
      assert_eq(source.split(declaration).count(), 2)
    }
  }
  let output_name = fn(name : String) -> String raise {
    guard sequential.hardware
      .outputs()
      .map(output => output.name())
      .search(name)
      is Some(index) else {
      fail("missing actual output")
    }
    queue_storage_export_test_name(inputs.emitted, OutputPort, index)
  }
  for binding in sequential.probe.bindings {
    let role = dependency_role_name(binding.role)
    let name = "dependency_" + role
    guard sequential.probe.observations.filter(item => item.name == name)
      is [observation] else {
      fail("exact original dependency alias")
    }
    assert_eq(observation.node, binding.node)
    assert_eq(observation.signal_type, binding.signal_type)
    assert_false(sequential.cuts.any(cut => cut.node == binding.node))
    let assignment = "  assign lc_o_\{role} = \{output_name(name)};\n"
    for source in sources {
      assert_eq(source.split(assignment).count(), 2)
    }
  }
  for (role, width, input) in dependency_public_ports() {
    if role == "clock" {
      continue
    }
    let identifier = if input {
      guard sequential.cuts.filter(cut => cut.roles == [role]) is [cut] else {
        fail("public pin missing")
      }
      assert_eq(cut.signal_type, queue_public_port_type(role, width))
      let original = dependency_generation_node(
        sequential.probe.packet.source,
        cut.node,
      )
      assert_eq(original.kind(), Input(role))
      queue_storage_export_test_name(
        inputs.emitted,
        InputPort,
        queue_storage_test_node(sequential.original_to_local, cut.node).ordinal(),
      )
    } else {
      output_name("public_" + role)
    }
    for source in sources {
      assert_eq(
        source.split("  assign lc_\{role} = \{identifier};\n").count(),
        2,
      )
    }
  }
  assert_eq(
    observer
    .split(dependency_conjunction_proof_test_original_tail(LatestWriter))
    .count(),
    2,
  )
  for
    index, variant in [
      DependencyFormalFixture::NegativeFailedGeneration,
      NegativeNewIntentPriority,
      NegativeInnerIdentity,
    ] {
    let tail = dependency_conjunction_proof_test_original_tail(variant)
    assert_eq(inputs.negatives[index].split(tail).count(), 2)
  }
  let mut normalized = inputs.negatives[0]
  for index in 0..<6 {
    let positive = "  assign lc_checked_status[\{index}] = lc_o_status[\{index}];\n"
    let negative = "  assign lc_checked_status[\{index}] = (lc_g_status[\{index}] == 2'd3 && lc_o_status[\{index}] == 2'd3 ? 2'd2 : lc_o_status[\{index}]);\n"
    assert_eq(normalized.split(negative).count(), 2)
    normalized = normalized.replace(old=negative, new=positive)
  }
  assert_eq(normalized, inputs.positive)
  let positive_priority = "  wire [31:0] lc_checked_priority_ticket = lc_o_ticket[lc_priority_slot];\n"
  let negative_priority = "  wire [31:0] lc_checked_priority_ticket = (lc_priority_check ? lc_priority_old_ticket : lc_o_ticket[lc_priority_slot]);\n"
  assert_eq(inputs.negatives[1].split(negative_priority).count(), 2)
  assert_eq(
    inputs.negatives[1].replace(old=negative_priority, new=positive_priority),
    inputs.positive,
  )
  let positive_inner = "  wire [12:0] lc_checked_inner_reduction = lc_o_compute_latched_reduction;\n"
  let negative_inner = "  wire [12:0] lc_checked_inner_reduction = (lc_o_compute_latched_reduction ^ (lc_inner_accept ? 13'd1 : 13'd0));\n"
  assert_eq(inputs.negatives[2].split(negative_inner).count(), 2)
  assert_eq(
    inputs.negatives[2].replace(old=negative_inner, new=positive_inner),
    inputs.positive,
  )
  // Independently construct all 79 register + four read + 12 cell terms.
  let pair : Array[String] = []
  let mut bits = 0
  for root in sequential.probe.roots {
    pair.push(output_name("current_" + root.name))
    bits += root.signal_type.width().bits()
  }
  for lane in sequential.probe.packet.lanes {
    let read = queue_storage_test_node(
      sequential.original_to_local,
      lane.result.id(),
    )
    pair.push(
      queue_storage_export_test_name(inputs.emitted, Node, read.ordinal()),
    )
    bits += lane.result.signal_type().width().bits()
    guard sequential.original_to_local_memory[lane.memory.id().ordinal()]
      is Some(memory) else {
      fail("actual memory mapping missing")
    }
    let identifier = queue_storage_export_test_name(
      inputs.emitted,
      Memory,
      memory.ordinal(),
    )
    assert_eq(inputs.memory_identifiers[lane.lane], identifier)
    for cell in 0..<lane.memory.depth().elements() {
      pair.push("\{identifier}[\{cell}]")
      bits += lane.memory.element_type().width().bits()
    }
  }
  assert_eq(pair.length(), 95)
  assert_eq(bits, 2226)
  let actual_pair = "  wire [2225:0] lc_dependency_actual_pair = {\{pair.join(", ")}};\n"
  for source in sources {
    assert_eq(source.split(actual_pair).count(), 2)
    assert_false(source.contains("lc_dut."))
    assert_false(source.contains("$initstate"))
  }
  assert_eq(
    before,
    @ir_codec.serialize(
      @ir.Design::single(
        "QueuedConcurrentQueueConservationPilot",
        queue_fixture.hardware(),
      ),
    ),
  )
}
