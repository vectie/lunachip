///|
// Complete source/local inventory, not a proof receipt or count-only boundary.
// No shell parser, runner, solver premise or export/public ABI is introduced.
#warnings("-unused_value")
fn store_storage_projection_report(
  projection : StoreStorageProjection,
) -> String raise {
  let plan = projection.plan
  let out = StringBuilder()
  let registers = projection.hardware
    .nodes()
    .filter(node => node.kind() is Register(_))
  let inputs = projection.hardware
    .nodes()
    .filter(node => node.kind() is Input(_))
  let reads = projection.hardware
    .nodes()
    .filter(node => node.kind() is MemoryRead(..))
  let register_bits = registers
    .iter()
    .fold(init=0, (bits, node) => bits + node.signal_type().width().bits())
  let cell_bits = plan.memories
    .iter()
    .fold(init=0, (bits, memory) => {
      bits + memory.element_type().width().bits() * memory.depth().elements()
    })
  let read_bits = reads
    .iter()
    .fold(init=0, (bits, node) => bits + node.signal_type().width().bits())
  out.write_string(
    "STORE-STORAGE-PROJECTION 1\nSCOPE exact-original-control-storage-four-arithmetic-production-values-only-not-MatMul-proof\n",
  )
  out.write_string(
    "PRODUCTION sha256 \{plan.probe.source_digest}\nREVIEWED-PROBE sha256 \{sha256_hex(store_preservation_probe_report(plan.probe))}\n",
  )
  out.write_string(
    "PROJECTION sha256 \{sha256_hex(@ir_codec.serialize(@ir.Design::single("StoreStorageProjection", projection.hardware)))}\n",
  )
  out.write_string(
    "INVENTORY nodes\{projection.hardware.nodes().length()} inputs\{inputs.length()} registers\{registers.length()} register-bits\{register_bits} memories\{plan.memories.length()} cell-bits\{cell_bits} read-states\{reads.length()} read-bits\{read_bits} outputs\{projection.hardware.outputs().length()} domains\{projection.hardware.domains().length()}\n",
  )
  out.write_string(
    "ARITHMETIC four-shared-SInt32-original-register-values-arbitrary-each-sample-no-stability-or-mathematical-premise\nCONTROL no-foreign-register-or-event-cuts-no-free-memory-read-values\nINITIALIZATION original-register-initializers-preserved-SRAM-and-read-state-uninitialized-no-manufactured-reset\n",
  )
  for cut in plan.arithmetic {
    let mapped = dependency_generation_mapped(
      projection.original_to_local,
      cut.id(),
    )
    out.write_string(
      "ARITHMETIC original\{cut.id().ordinal()} local\{mapped.ordinal()} type\{Repr(cut.signal_type())} kind\{Repr(cut.kind())}\n",
    )
  }
  for root in plan.arbiter_roots {
    let mapped = dependency_generation_mapped(
      projection.original_to_local,
      root.node,
    )
    out.write_string(
      "ARBITER \{root.name} original\{root.node.ordinal()} local\{mapped.ordinal()} type\{Repr(root.signal_type)} spec\{Repr(root.spec)}\n",
    )
  }
  for index, seed in plan.seeds {
    out.write_string("SEED \{index} original\{seed.ordinal()}\n")
  }
  for original in plan.selected {
    let mapped = dependency_generation_mapped(
      projection.original_to_local,
      original.id(),
    )
    let copied_node = dependency_generation_node(projection.hardware, mapped)
    out.write_string(
      "NODE original\{original.id().ordinal()} local\{mapped.ordinal()} type\{Repr(original.signal_type())} original-kind\{Repr(original.kind())} local-kind\{Repr(copied_node.kind())}\n",
    )
  }
  for original in plan.memories {
    let mapped = queue_storage_sequential_mapped_memory(
      projection.original_to_local_memory,
      original.id(),
    )
    guard projection.hardware.memories().filter(memory => memory.id() == mapped)
      is [copied_memory] else {
      raise InvalidFormalBundleIdentity(
        "Store projection report: exact local memory",
      )
    }
    out.write_string(
      "MEMORY original\{original.id().ordinal()} local\{mapped.ordinal()} original-spec\{Repr(original)} local-spec\{Repr(copied_memory)}\n",
    )
  }
  for index, observation in plan.probe.source.outputs() {
    out.write_string(
      "PUBLIC-OUTPUT \{index} name\{observation.name()} original\{observation.driver().ordinal()} local\{dependency_generation_mapped(projection.original_to_local, observation.driver()).ordinal()}\n",
    )
  }
  for index, observation in projection.plan.probe.roots {
    out.write_string(
      "ESSENTIAL-ROOT \{index} role\{Repr(observation.binding.role())} original\{observation.original.id().ordinal()}\n",
    )
  }
  for index, observation in plan.observations {
    let mapped = dependency_generation_mapped(
      projection.original_to_local,
      observation.node(),
    )
    out.write_string(
      "OBSERVATION \{index} role\{Repr(observation.role())} original\{observation.node().ordinal()} local\{mapped.ordinal()} type\{Repr(observation.signal_type())}\n",
    )
  }
  out.write_string("END\n")
  out.to_string()
}
