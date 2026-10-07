///|
// Supporting proof inputs only; no typed task, engine result or ABI addition.
#warnings("-unused_field")
priv struct StorePreservationProofInputs {
  projection : StoreStorageProjection
  emitted : @rtl.EmittedDesign
  boolean_source : String
  positive : String
  negative : String
  properties : @formal_core.FormalExport
  top_identifier : String
  memory_bounds : ReadOnlyArray[String]
  global_assertions : ReadOnlyArray[String]
}

///|
fn store_preservation_role_alias(
  role : @flux_tile.StorePreservationRole,
) -> String {
  match role {
    StoreRegister(field) => "lc_o_store_\{Repr(field)}"
    ComputeRegister(field) => "lc_o_compute_\{Repr(field)}"
    SlottedRegister(field) => "lc_o_slotted_\{Repr(field)}"
    CoreRegister(field) => "lc_o_core_\{Repr(field)}"
    ResultValid(slot) => "lc_o_result_valid_\{slot}"
    ResultRows(slot) => "lc_o_result_rows_\{slot}"
    ResultColumns(slot) => "lc_o_result_columns_\{slot}"
    ResponseId => "lc_o_response_id"
    ResponseFault => "lc_o_response_fault"
    CReadData(slot) => "lc_o_c_read_\{slot}"
    Event(event) => "lc_e_\{Repr(event)}"
  }
}

///|
fn store_preservation_role_node(
  projection : StoreStorageProjection,
  role : @flux_tile.StorePreservationRole,
) -> @ir.NodeId raise FormalGateError {
  guard projection.plan.observations.filter(observation => {
      observation.role() == role
    })
    is [observation] else {
    raise InvalidFormalBundleIdentity(
      "Store proof: exact original role binding",
    )
  }
  observation.node()
}

///|
fn store_preservation_node_identifier(
  projection : StoreStorageProjection,
  emitted : @rtl.EmittedDesign,
  original : @ir.NodeId,
) -> String raise FormalGateError {
  let mapped = dependency_generation_mapped(
    projection.original_to_local,
    original,
  )
  guard emitted
    .manifest()
    .mappings()
    .filter(mapping => {
      mapping.kind() is Node &&
      mapping.module_ordinal() == emitted.manifest().top_module_ordinal() &&
      mapping.local_ordinal() == mapped.ordinal()
    })
    is [mapping] else {
    raise InvalidFormalBundleIdentity(
      "Store proof: exact original-to-local node manifest",
    )
  }
  mapping.identifier()
}

///|
fn store_preservation_memory_identifiers(
  projection : StoreStorageProjection,
  emitted : @rtl.EmittedDesign,
) -> ReadOnlyArray[String] raise FormalGateError {
  let names : Array[String] = []
  for memory in projection.plan.memories {
    let mapped = queue_storage_sequential_mapped_memory(
      projection.original_to_local_memory,
      memory.id(),
    )
    guard emitted
      .manifest()
      .mappings()
      .filter(mapping => {
        mapping.kind() is Memory &&
        mapping.module_ordinal() == emitted.manifest().top_module_ordinal() &&
        mapping.local_ordinal() == mapped.ordinal() &&
        mapping.source_name() == memory.name()
      })
      is [mapping] else {
      raise InvalidFormalBundleIdentity(
        "Store proof: exact original-to-local memory manifest",
      )
    }
    names.push(mapping.identifier())
  }
  ReadOnlyArray::from_array(names)
}
