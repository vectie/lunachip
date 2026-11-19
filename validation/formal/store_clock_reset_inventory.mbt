///|
priv struct StoreClockResetInventory {
  registers : ReadOnlyArray[String]
  reset_checks : ReadOnlyArray[String]
  memory : ReadOnlyArray[String]
  memory_enables : ReadOnlyArray[String]
  register_bits : Int32
  memory_bits : Int32
}

///|
// Enumerate original state, not a reconstructed controller or zeroed SRAM.
fn store_clock_reset_inventory(
  projection : StoreStorageProjection,
  emitted : @rtl.EmittedDesign,
) -> StoreClockResetInventory raise {
  let registers : Array[String] = []
  let reset_checks : Array[String] = []
  let memory : Array[String] = []
  let memory_enables : Array[String] = []
  let mut register_bits = 0
  let mut memory_bits = 0
  for original in projection.plan.selected {
    if projection.plan.arithmetic.any(cut => cut.id() == original.id()) {
      continue
    }
    let identifier = store_preservation_node_identifier(
      projection,
      emitted,
      original.id(),
    )
    match original.kind() {
      Register(spec) => {
        guard spec.reset() is Some(control) &&
          control.signal() == projection.plan.probe.reset &&
          control.mode() is Synchronous &&
          control.polarity() is ActiveHigh else {
          raise InvalidFormalBundleIdentity(
            "Store clock/reset: original synchronous reset binding",
          )
        }
        let width = original.signal_type().width().bits()
        register_bits += width
        registers.push(identifier)
        reset_checks.push(
          "(\{identifier} == \{width}'h\{control.value().to_string(radix=16)})",
        )
      }
      MemoryRead(..) => {
        memory_bits += original.signal_type().width().bits()
        memory.push(identifier)
      }
      _ => ()
    }
  }
  let names = store_preservation_memory_identifiers(projection, emitted)
  for index, original in projection.plan.memories {
    for read in original.read_ports() {
      guard read.enable() is Some(enable) else {
        raise InvalidFormalBundleIdentity(
          "Store clock/reset: exact enabled read port",
        )
      }
      memory_enables.push(
        store_preservation_node_identifier(projection, emitted, enable),
      )
    }
    for write in original.write_ports() {
      guard write.enable() is Some(enable) else {
        raise InvalidFormalBundleIdentity(
          "Store clock/reset: exact enabled write port",
        )
      }
      memory_enables.push(
        store_preservation_node_identifier(projection, emitted, enable),
      )
    }
    for cell in 0..<original.depth().elements() {
      memory.push("\{names[index]}[\{cell}]")
      memory_bits += original.element_type().width().bits()
    }
  }
  if registers.length() != 162 ||
    reset_checks.length() != 162 ||
    memory.length() != 26 ||
    memory_enables.length() != 12 ||
    register_bits != 2427 ||
    memory_bits != 1344 {
    raise InvalidFormalBundleIdentity(
      "Store clock/reset: exact 162-register/six-memory/six-read-state roster",
    )
  }
  {
    registers: ReadOnlyArray::from_array(registers),
    reset_checks: ReadOnlyArray::from_array(reset_checks),
    memory: ReadOnlyArray::from_array(memory),
    memory_enables: ReadOnlyArray::from_array(memory_enables),
    register_bits,
    memory_bits,
  }
}

///|
// Remove ONLY emitted bounds assertions from a dedicated lemma input. The
// original memory port conditions and updates remain byte-for-byte unchanged.
fn store_clock_reset_without_bounds(
  source : String,
  bounds : ReadOnlyArray[String],
) -> String raise {
  let mut result = source
  for label in bounds {
    let marker = label + ": assert ("
    let lines = result
      .split("\n")
      .filter(line => line.contains(marker))
      .to_array()
    guard lines is [line] &&
      line.trim().has_prefix(marker) &&
      line.has_suffix(";") else {
      raise InvalidFormalBundleIdentity(
        "Store clock/reset: complete bounds statement",
      )
    }
    let statement = line.to_owned() + "\n"
    if result.split(statement).count() != 2 {
      raise InvalidFormalBundleIdentity(
        "Store clock/reset: unique bounds statement",
      )
    }
    result = result.replace(old=statement, new="")
  }
  if bounds.length() != 12 ||
    result.contains(": assert (") ||
    result.contains(": assume (") ||
    result.contains(": cover (") {
    raise InvalidFormalBundleIdentity(
      "Store clock/reset: only original twelve bounds removed",
    )
  }
  result
}
