///|
fn queue_storage_sequential_mapped_memory(
  mapping : ArrayView[@ir.MemoryId?],
  original : @ir.MemoryId,
) -> @ir.MemoryId raise FormalGateError {
  guard mapping.get(original.ordinal()) is Some(Some(mapped)) else {
    raise InvalidFormalBundleIdentity(
      "queue storage sequential: missing original memory",
    )
  }
  mapped
}

///|
// Copy the authoritative memory and read-result storage; only canonical IDs
// change. There is no memory initialization, reset, free read-data input or
// replacement pointer/port equation. Port IDs and source names stay intact.
fn queue_storage_sequential_memory(
  memory : @ir.MemorySpec,
  nodes : ArrayView[@ir.NodeId?],
  memories : ArrayView[@ir.MemoryId?],
) -> @ir.MemorySpec raise FormalGateError {
  fn mapped(id) raise FormalGateError {
    dependency_generation_mapped(nodes, id)
  }
  fn domain(original : @ir.ClockDomain) raise FormalGateError {
    @ir.ClockDomain::new(
      original.id(),
      mapped(original.clock()),
      original.edge(),
    )
  }
  let reads : Array[@ir.MemoryReadPort] = []
  for port in memory.read_ports() {
    let enable = port.enable().map(mapped)
    reads.push(
      @ir.MemoryReadPort::new(
        port.id(),
        port.name(),
        domain(port.domain()),
        mapped(port.address()),
        enable?,
        port.latency(),
        port.enable_behavior(),
        mapped(port.result()),
      ),
    )
  }
  let writes : Array[@ir.MemoryWritePort] = []
  for port in memory.write_ports() {
    let enable = port.enable().map(mapped)
    let mask : @ir.MemoryWriteMask = match port.mask() {
      All => All
      Granular(signal~, granularity~) =>
        Granular(signal=mapped(signal), granularity~)
    }
    writes.push(
      @ir.MemoryWritePort::new(
        port.id(),
        port.name(),
        domain(port.domain()),
        mapped(port.address()),
        mapped(port.data()),
        enable?,
        mask,
      ),
    )
  }
  @ir.MemorySpec::new(
    queue_storage_sequential_mapped_memory(memories, memory.id()),
    memory.name(),
    memory.element_type(),
    memory.depth(),
    domain(memory.domain()),
    reads,
    writes,
    memory.read_write_policy(),
    memory.multi_write_policy(),
    memory.bounds_policy(),
  )
}
