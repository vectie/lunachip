///|
// Private supporting inputs, not a task, proof receipt or new abstraction.
#warnings("-unused_field")
priv struct QueuePacketCompositionExport {
  sequential : QueuePacketCompositionSequential
  emitted : @rtl.EmittedDesign
  boolean_source : String
  positive : String
  negative : String
  properties : @formal_core.FormalExport
  top_identifier : String
  memory_identifiers : ReadOnlyArray[String]
  memory_bounds : ReadOnlyArray[String]
  global_assertions : ReadOnlyArray[String]
  strengthening_assertions : ReadOnlyArray[String]
}

///|
fn queue_packet_composition_source(
  fixture : @flux_tile.QueueConservationFixture,
  sequential : QueuePacketCompositionSequential,
  emitted : @rtl.EmittedDesign,
  negative? : Bool = false,
) -> String raise {
  let expected = queue_packet_composition_sequential(fixture)
  queue_packet_composition_require_inventory(expected.probe)
  queue_packet_composition_require_inventory(sequential.probe)
  let canonical = @ir.Design::single(
    "QueuePacketCompositionSequential",
    expected.hardware,
  )
  if @ir_codec.serialize(
      @ir.Design::single(
        "QueuePacketCompositionSequential",
        sequential.hardware,
      ),
    ) !=
    @ir_codec.serialize(canonical) ||
    sequential.probe != expected.probe ||
    sequential.cuts != expected.cuts ||
    sequential.original_to_local != expected.original_to_local ||
    sequential.original_to_local_memory != expected.original_to_local_memory ||
    sequential.inventory_digest != expected.inventory_digest ||
    emitted != @rtl.emit_design(canonical) {
    raise InvalidFormalBundleIdentity(
      "packet composition proof inputs: exact accepted graph/emission drift",
    )
  }
  let observer = queue_packet_composition_bindings(sequential, emitted) +
    queue_packet_composition_original_monitor(sequential, emitted, negative) +
    queue_packet_composition_strengthening_source(sequential, emitted) +
    queue_packet_composition_retention_source(sequential, emitted)
  queue_packet_composition_adapter(sequential, emitted, observer)
}

///|
#warnings("-unused_value")
fn queue_packet_composition_export(
  fixture : @flux_tile.QueueConservationFixture,
) -> QueuePacketCompositionExport raise {
  let sequential = queue_packet_composition_sequential(fixture)
  queue_packet_composition_require_inventory(sequential.probe)
  let emitted = @rtl.emit_design(
    @ir.Design::single("QueuePacketCompositionSequential", sequential.hardware),
  )
  let top = top_emitted_module(emitted)
  let (boolean_source, _) = dependency_boolean_helpers(
    sequential.hardware,
    top.source(),
  )
  let memory_bounds : Array[String] = []
  for lane in sequential.probe.lanes {
    let mapped = queue_storage_sequential_mapped_memory(
      sequential.original_to_local_memory,
      lane.memory.id(),
    )
    for operation in ["read0", "write0"] {
      let label = "lc_mem\{mapped.ordinal()}_\{operation}_bounds"
      if top.source().split(label + ": assert").count() != 2 {
        raise InvalidFormalBundleIdentity(
          "packet composition proof inputs: original memory bounds",
        )
      }
      memory_bounds.push(label)
    }
  }
  let properties = queue_packet_composition_properties()
  {
    sequential,
    emitted,
    boolean_source,
    properties,
    positive: queue_packet_composition_source(fixture, sequential, emitted),
    negative: queue_packet_composition_source(
      fixture,
      sequential,
      emitted,
      negative=true,
    ),
    top_identifier: top.identifier(),
    memory_identifiers: queue_packet_composition_memory_identifiers(
      sequential, emitted,
    ),
    memory_bounds: ReadOnlyArray::from_array(memory_bounds),
    global_assertions: ["lc_packet_nonrising_hold"],
    strengthening_assertions: ["lc_packet_strengthening"],
  }
}
