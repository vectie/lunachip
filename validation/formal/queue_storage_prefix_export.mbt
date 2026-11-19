///|
// Private proof-input source only. No task, runner, receipt or proof claim.
#warnings("-unused_field")
priv struct QueueStoragePrefixExport {
  sequential : QueueStorageSequential
  emitted : @rtl.EmittedDesign
  boolean_source : String
  positive : String
  negative : String
  properties : @formal_core.FormalExport
  top_identifier : String
  memory_identifiers : ReadOnlyArray[String]
  memory_bounds : ReadOnlyArray[String]
  // Global sampling is explicit, not misrepresented as a rising-edge property.
  global_assertions : ReadOnlyArray[String]
}

///|
// Reaccept the exact source-bound original graph and canonical emitter names
// before splicing. Count-only, supplied reports, renamed arrays and altered
// sequential bodies cannot silently become supporting proof inputs.
fn queue_storage_prefix_source(
  fixture : @flux_tile.QueueConservationFixture,
  sequential : QueueStorageSequential,
  emitted : @rtl.EmittedDesign,
  negative~ : Bool = false,
) -> String raise {
  let expected = queue_storage_sequential(fixture)
  let canonical = @ir.Design::single(
    "QueueStorageSequential",
    expected.hardware,
  )
  if @ir_codec.serialize(
      @ir.Design::single("QueueStorageSequential", sequential.hardware),
    ) !=
    @ir_codec.serialize(canonical) ||
    sequential.probe != expected.probe ||
    sequential.cuts != expected.cuts ||
    sequential.original_to_local != expected.original_to_local ||
    sequential.original_to_local_memory != expected.original_to_local_memory ||
    sequential.inventory_digest != expected.inventory_digest ||
    emitted != @rtl.emit_design(canonical) {
    raise InvalidFormalBundleIdentity(
      "queue storage prefix: exact accepted graph/emission drift",
    )
  }
  let top = top_emitted_module(emitted).identifier()
  let observer = queue_storage_prefix_observer(sequential, emitted, negative)
  let properties = queue_storage_prefix_properties(top)
  queue_storage_prefix_adapter(
    sequential,
    emitted,
    observer + properties.source(),
  )
}

///|
#warnings("-unused_value")
fn queue_storage_prefix_export(
  fixture : @flux_tile.QueueConservationFixture,
) -> QueueStoragePrefixExport raise {
  let sequential = queue_storage_sequential(fixture)
  let emitted = @rtl.emit_design(
    @ir.Design::single("QueueStorageSequential", sequential.hardware),
  )
  let top = top_emitted_module(emitted)
  let (boolean_source, _) = dependency_boolean_helpers(
    sequential.hardware,
    top.source(),
  )
  let memory_bounds : Array[String] = []
  for lane in sequential.probe.lanes {
    let mapped_memory = queue_storage_sequential_mapped_memory(
      sequential.original_to_local_memory,
      lane.memory.id(),
    )
    for operation in ["read0", "write0"] {
      let label = "lc_mem\{mapped_memory.ordinal()}_\{operation}_bounds"
      if top.source().split(label + ": assert").count() != 2 {
        raise InvalidFormalBundleIdentity(
          "queue storage prefix: original memory bound assertion",
        )
      }
      memory_bounds.push(label)
    }
  }
  {
    sequential,
    emitted,
    boolean_source,
    positive: queue_storage_prefix_source(fixture, sequential, emitted),
    negative: queue_storage_prefix_source(
      fixture,
      sequential,
      emitted,
      negative=true,
    ),
    properties: queue_storage_prefix_properties(top.identifier()),
    top_identifier: top.identifier(),
    memory_identifiers: queue_storage_prefix_memory_identifiers(
      sequential, emitted,
    ),
    memory_bounds: ReadOnlyArray::from_array(memory_bounds),
    global_assertions: ["lc_storage_nonrising_hold"],
  }
}
