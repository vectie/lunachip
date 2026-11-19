///|
fn validate_memory_clock(
  nodes : ArrayView[Node],
  memory : MemorySpec,
) -> Unit raise IrError {
  let clock = memory.domain().clock()
  let clock_node = require_node(nodes, clock)
  if !clock_node.signal_type().is_clock() {
    raise ExpectedClock(node=clock.ordinal())
  }
  match memory.domain().edge() {
    Rising => ()
  }
}

///|
fn validate_memory_port_domain(
  memory : MemorySpec,
  role : MemoryPortRole,
  port : Int32,
  domain : ClockDomain,
) -> Unit raise IrError {
  if domain != memory.domain() {
    raise MemoryDomainMismatch(memory=memory.id().ordinal(), role~, port~)
  }
}

///|
fn validate_memory_address(
  nodes : ArrayView[Node],
  memory : MemorySpec,
  role : MemoryPortRole,
  port : Int32,
  address : NodeId,
) -> Unit raise IrError {
  let node = require_node(nodes, address)
  guard node.signal_type() is UInt(width) else {
    raise ExpectedMemoryAddress(
      memory=memory.id().ordinal(),
      role~,
      port~,
      node=address.ordinal(),
    )
  }
  let expected = memory.depth().address_width().bits()
  let actual = width.bits()
  if actual != expected {
    raise MemoryAddressWidth(
      memory=memory.id().ordinal(),
      role~,
      port~,
      expected~,
      actual~,
    )
  }
}

///|
fn validate_memory_enable(
  nodes : ArrayView[Node],
  memory : MemorySpec,
  role : MemoryPortRole,
  port : Int32,
  enable : NodeId?,
) -> Unit raise IrError {
  if enable is Some(id) {
    let node = require_node(nodes, id)
    if !node.signal_type().is_data() || node.signal_type().width().bits() != 1 {
      raise ExpectedMemoryEnable(
        memory=memory.id().ordinal(),
        role~,
        port~,
        node=id.ordinal(),
      )
    }
  }
}

///|
fn validate_read_port(
  nodes : ArrayView[Node],
  memory : MemorySpec,
  expected : Int32,
  port : MemoryReadPort,
  results : Array[Int32],
) -> Unit raise IrError {
  let actual = port.id().ordinal()
  if actual != expected {
    raise NonSequentialMemoryPortId(
      memory=memory.id().ordinal(),
      role=ReadPort,
      expected~,
      actual~,
    )
  }
  require_name(port.name(), "memory read port")
  validate_memory_port_domain(memory, ReadPort, actual, port.domain())
  validate_memory_address(nodes, memory, ReadPort, actual, port.address())
  validate_memory_enable(nodes, memory, ReadPort, actual, port.enable())
  match port.latency() {
    OneCycle => ()
  }
  let result = port.result()
  if results.contains(result.ordinal()) {
    raise DuplicateMemoryReadResult(node=result.ordinal())
  }
  let result_node = require_node(nodes, result)
  if result_node.signal_type() != memory.element_type() ||
    result_node.kind() != MemoryRead(memory=memory.id(), port=port.id()) {
    raise MemoryReadResultMismatch(
      memory=memory.id().ordinal(),
      port=actual,
      node=result.ordinal(),
    )
  }
  results.push(result.ordinal())
}

///|
fn validate_write_mask(
  nodes : ArrayView[Node],
  memory : MemorySpec,
  port : MemoryWritePort,
) -> Unit raise IrError {
  match port.mask() {
    All => ()
    Granular(signal~, granularity~) => {
      let element = memory.element_type().width().bits()
      let granule = granularity.bits()
      if element % granule != 0 {
        raise MemoryMaskGranularity(
          memory=memory.id().ordinal(),
          port=port.id().ordinal(),
          element~,
          granule~,
        )
      }
      let mask = require_node(nodes, signal)
      guard mask.signal_type() is Bits(width) else {
        raise ExpectedMemoryMask(
          memory=memory.id().ordinal(),
          port=port.id().ordinal(),
          node=signal.ordinal(),
        )
      }
      let expected = element / granule
      let actual = width.bits()
      if actual != expected {
        raise MemoryMaskWidth(
          memory=memory.id().ordinal(),
          port=port.id().ordinal(),
          expected~,
          actual~,
        )
      }
    }
  }
}

///|
fn validate_write_port(
  nodes : ArrayView[Node],
  memory : MemorySpec,
  expected : Int32,
  port : MemoryWritePort,
) -> Unit raise IrError {
  let actual = port.id().ordinal()
  if actual != expected {
    raise NonSequentialMemoryPortId(
      memory=memory.id().ordinal(),
      role=WritePort,
      expected~,
      actual~,
    )
  }
  require_name(port.name(), "memory write port")
  validate_memory_port_domain(memory, WritePort, actual, port.domain())
  validate_memory_address(nodes, memory, WritePort, actual, port.address())
  validate_memory_enable(nodes, memory, WritePort, actual, port.enable())
  let data = require_node(nodes, port.data())
  if data.signal_type() != memory.element_type() {
    raise MemoryDataTypeMismatch(memory=memory.id().ordinal(), port=actual)
  }
  validate_write_mask(nodes, memory, port)
}

///|
fn validate_static_multi_write_collisions(
  memory : MemorySpec,
) -> Unit raise IrError {
  if memory.multi_write_policy() is Reject {
    let ports = memory.write_ports()
    for first in 0..<ports.length() {
      for second in (first + 1)..<ports.length() {
        if ports[first].address() == ports[second].address() {
          raise RejectedStaticMultiWriteCollision(
            memory=memory.id().ordinal(),
            first~,
            second~,
          )
        }
      }
    }
  }
}

///|
fn validate_memory(
  nodes : ArrayView[Node],
  memory : MemorySpec,
  expected : Int32,
  results : Array[Int32],
) -> Unit raise IrError {
  let actual = memory.id().ordinal()
  if actual != expected {
    raise NonSequentialMemoryId(expected~, actual~)
  }
  require_name(memory.name(), "memory")
  if !memory.element_type().is_data() {
    raise InvalidMemoryElementType(memory=actual)
  }
  if memory.read_ports().is_empty() && memory.write_ports().is_empty() {
    raise MemoryHasNoPorts(memory=actual)
  }
  validate_memory_clock(nodes, memory)
  if memory.read_write_policy() is Reject &&
    !memory.read_ports().is_empty() &&
    !memory.write_ports().is_empty() {
    raise RejectedMemoryReadWriteCollision(memory=actual)
  }
  let names : Array[String] = []
  for index, port in memory.read_ports() {
    if contains_name(names, port.name()) {
      raise DuplicateName(kind="memory port", name=port.name())
    }
    names.push(port.name())
    validate_read_port(nodes, memory, index, port, results)
  }
  for index, port in memory.write_ports() {
    if contains_name(names, port.name()) {
      raise DuplicateName(kind="memory port", name=port.name())
    }
    names.push(port.name())
    validate_write_port(nodes, memory, index, port)
  }
  validate_static_multi_write_collisions(memory)
}

///|
fn validate_memories(
  nodes : ArrayView[Node],
  memories : ArrayView[MemorySpec],
) -> Unit raise IrError {
  let names : Array[String] = []
  let results : Array[Int32] = []
  for index, memory in memories {
    if contains_name(names, memory.name()) {
      raise DuplicateName(kind="memory", name=memory.name())
    }
    names.push(memory.name())
    validate_memory(nodes, memory, index, results)
  }
  for node in nodes {
    match node.kind() {
      MemoryRead(memory~, port~) => {
        let memory_ordinal = memory.ordinal()
        if memory_ordinal < 0 || memory_ordinal >= memories.length() {
          raise UnknownMemoryId(memory_ordinal)
        }
        let ports = memories[memory_ordinal].read_ports()
        let port_ordinal = port.ordinal()
        if port_ordinal < 0 || port_ordinal >= ports.length() {
          raise UnknownMemoryReadPort(memory=memory_ordinal, port=port_ordinal)
        }
        if ports[port_ordinal].result() != node.id() {
          raise OrphanMemoryReadNode(
            node=node.id().ordinal(),
            memory=memory_ordinal,
            port=port_ordinal,
          )
        }
      }
      _ => ()
    }
  }
}
