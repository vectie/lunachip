///|
// Standalone original-module formal top keeps properties removable/selectable
// by the existing direct-top chformal path. Reversible header/insertion only;
// original memory/register/control body remains the qualified Boolean source.
fn store_preservation_adapter(
  projection : StoreStorageProjection,
  emitted : @rtl.EmittedDesign,
  observer : String,
) -> String raise {
  let dut = top_emitted_module(emitted)
  let lines : Array[String] = []
  let declarations = StringBuilder()
  for node in projection.hardware.nodes() {
    guard node.kind() is Input(name) else { continue }
    let identifier = port_identifier(emitted, InputPort, name)
    let signal_type = queue_storage_prefix_logic(node.signal_type())
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
  for output in projection.hardware.outputs() {
    let identifier = port_identifier(emitted, OutputPort, output.name())
    let signal_type = queue_storage_prefix_logic(output.signal_type())
    lines.push("output \{signal_type} \{identifier}")
    declarations.write_string("  \{signal_type} \{identifier};\n")
  }
  let ports = StringBuilder()
  for index, line in lines {
    ports.write_string(
      "  \{line}\{if index + 1 == lines.length() { "" } else { "," }}\n",
    )
  }
  let header = "module \{dut.identifier()} (\n" + ports.to_string() + ");\n\n"
  let replacement = "module \{dut.identifier()};\n" +
    declarations.to_string() +
    "\n"
  let (source, _) = dependency_boolean_helpers(
    projection.hardware,
    dut.source(),
  )
  if source.split(header).count() != 2 ||
    source.split("endmodule\n").count() != 2 ||
    observer.contains("endmodule") {
    raise InvalidFormalBundleIdentity(
      "Store proof: exact standalone source splice",
    )
  }
  let inserted = observer + "endmodule\n"
  let result = source
    .replace(old=header, new=replacement)
    .replace(old="endmodule\n", new=inserted)
  if result
    .replace(old=inserted, new="endmodule\n")
    .replace(old=replacement, new=header) !=
    source {
    raise InvalidFormalBundleIdentity(
      "Store proof: reversible unchanged original body",
    )
  }
  result
}

///|
fn store_preservation_proof_source(
  fixture : @flux_tile.StorePreservationFixture,
  projection : StoreStorageProjection,
  emitted : @rtl.EmittedDesign,
  negative? : Bool = false,
) -> String raise {
  let expected = store_storage_projection(fixture)
  let canonical = @ir.Design::single(
    "StoreStorageProjection",
    expected.hardware,
  )
  if projection.hardware != expected.hardware ||
    projection.plan != expected.plan ||
    projection.original_to_local != expected.original_to_local ||
    projection.original_to_local_memory != expected.original_to_local_memory ||
    emitted != @rtl.emit_design(canonical) {
    raise InvalidFormalBundleIdentity(
      "Store proof: accepted exact projection/emission drift",
    )
  }
  let observer = store_preservation_proof_bindings(projection, emitted) +
    store_preservation_production_source() +
    store_preservation_control_source() +
    store_preservation_transfer_source(negative) +
    store_preservation_retention_source(projection, emitted) +
    store_preservation_properties(top_emitted_module(emitted).identifier()).source()
  store_preservation_adapter(projection, emitted, observer)
}

///|
#warnings("-unused_value")
fn store_preservation_proof_inputs(
  fixture : @flux_tile.StorePreservationFixture,
) -> StorePreservationProofInputs raise {
  let projection = store_storage_projection(fixture)
  let emitted = @rtl.emit_design(
    @ir.Design::single("StoreStorageProjection", projection.hardware),
  )
  let top = top_emitted_module(emitted)
  let (boolean_source, _) = dependency_boolean_helpers(
    projection.hardware,
    top.source(),
  )
  let bounds : Array[String] = []
  for memory in projection.hardware.memories() {
    for read in memory.read_ports() {
      bounds.push(
        "lc_mem\{memory.id().ordinal()}_read\{read.id().ordinal()}_bounds",
      )
    }
    for write in memory.write_ports() {
      bounds.push(
        "lc_mem\{memory.id().ordinal()}_write\{write.id().ordinal()}_bounds",
      )
    }
  }
  if bounds.length() != 12 ||
    !bounds.all(label => top.source().split(label + ": assert").count() == 2) {
    raise InvalidFormalBundleIdentity(
      "Store proof: all original enabled memory bounds retained",
    )
  }
  {
    projection,
    emitted,
    boolean_source,
    positive: store_preservation_proof_source(fixture, projection, emitted),
    negative: store_preservation_proof_source(
      fixture,
      projection,
      emitted,
      negative=true,
    ),
    properties: store_preservation_properties(top.identifier()),
    top_identifier: top.identifier(),
    memory_bounds: ReadOnlyArray::from_array(bounds),
    global_assertions: ["lc_store_nonrising_hold"],
  }
}
