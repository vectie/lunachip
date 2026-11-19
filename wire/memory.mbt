///|
fn ModuleBuilder::require_memory(
  self : ModuleBuilder,
  memory : Memory,
) -> MemoryDeclaration raise WireError {
  self.require_open()
  if !physical_equal(self.owner, memory.owner) {
    raise ForeignMemory
  }
  guard self.memories.get(memory.index) is Some(declaration) &&
    declaration.id == memory.id &&
    declaration.element_type == memory.element_type &&
    declaration.depth == memory.depth else {
    raise ForeignMemory
  }
  declaration
}

///|
fn require_memory_address(
  memory : MemoryDeclaration,
  address : Signal,
) -> Unit raise @ir.IrError {
  let expected_type = @ir.SignalType::UInt(memory.depth.address_width())
  if address.signal_type != expected_type {
    let expected = expected_type.width().bits()
    let actual = address.signal_type.width().bits()
    if expected != actual {
      raise WidthMismatch(operation="memory_address", expected~, actual~)
    }
    raise TypeMismatch(operation="memory_address")
  }
}

///|
fn require_memory_enable(enable : Signal) -> Unit raise @ir.IrError {
  if !enable.signal_type.is_data() || enable.signal_type.width().bits() != 1 {
    raise ExpectedEnable(node=enable.id.ordinal())
  }
}

///|
fn default_read_write_policy(
  policy : @ir.MemoryReadWritePolicy?,
) -> @ir.MemoryReadWritePolicy {
  match policy {
    Some(value) => value
    None => ReadOld
  }
}

///|
fn default_multi_write_policy(
  policy : @ir.MemoryMultiWritePolicy?,
) -> @ir.MemoryMultiWritePolicy {
  match policy {
    Some(value) => value
    None => Reject
  }
}

///|
fn default_bounds_policy(
  policy : @ir.MemoryBoundsPolicy?,
) -> @ir.MemoryBoundsPolicy {
  match policy {
    Some(value) => value
    None => Fault
  }
}

///|
fn default_read_enable_behavior(
  behavior : @ir.MemoryReadEnableBehavior?,
) -> @ir.MemoryReadEnableBehavior {
  match behavior {
    Some(value) => value
    None => HoldLast
  }
}

///|
/// Declare first-class synchronous memory state in one explicit clock domain.
///
/// Cells and read-result registers begin unknown. Port semantics are added
/// through `memory_read`, `memory_write`, or `memory_write_masked`.
pub fn ModuleBuilder::synchronous_memory(
  self : ModuleBuilder,
  name : String,
  element_type : @ir.SignalType,
  depth : Int32,
  domain : ClockDomain,
  read_write_policy? : @ir.MemoryReadWritePolicy,
  multi_write_policy? : @ir.MemoryMultiWritePolicy,
  bounds_policy? : @ir.MemoryBoundsPolicy,
) -> Memory raise {
  self.require_open()
  if !physical_equal(self.owner, domain.owner) {
    raise ForeignClockDomain
  }
  self.require_signal(domain.clock)
  if !element_type.is_data() {
    raise @ir.IrError::TypeMismatch(operation="memory element")
  }
  let canonical_depth = @ir.MemoryDepth::new(depth)
  let id = @ir.MemoryId::new(self.memories.length())
  let index = self.memories.length()
  self.memories.push({
    id,
    name,
    element_type,
    depth: canonical_depth,
    domain,
    read_write_policy: default_read_write_policy(read_write_policy),
    multi_write_policy: default_multi_write_policy(multi_write_policy),
    bounds_policy: default_bounds_policy(bounds_policy),
    read_ports: [],
    write_ports: [],
  })
  { owner: self.owner, index, id, element_type, depth: canonical_depth, }
}

///|
/// Add one one-cycle synchronous read port and return its registered result.
pub fn ModuleBuilder::memory_read(
  self : ModuleBuilder,
  memory : Memory,
  name : String,
  address : Signal,
  enable? : Signal,
  enable_behavior? : @ir.MemoryReadEnableBehavior,
) -> Signal raise {
  let declaration = self.require_memory(memory)
  self.require_signal(address)
  require_memory_address(declaration, address)
  let canonical_enable = match enable {
    Some(value) => {
      self.require_signal(value)
      require_memory_enable(value)
      Some(value.id)
    }
    None => None
  }
  let port_id = @ir.MemoryReadPortId::new(declaration.read_ports.length())
  let result = self.append(
    declaration.element_type,
    MemoryRead(memory=declaration.id, port=port_id),
  )
  declaration.read_ports.push(
    @ir.MemoryReadPort::new(
      port_id,
      name,
      declaration.domain.canonical,
      address.id,
      enable?=canonical_enable,
      OneCycle,
      default_read_enable_behavior(enable_behavior),
      result.id,
    ),
  )
  result
}

///|
fn ModuleBuilder::memory_write_with_mask(
  self : ModuleBuilder,
  memory : Memory,
  name : String,
  address : Signal,
  data : Signal,
  enable : Signal?,
  mask : @ir.MemoryWriteMask,
) -> Unit raise {
  let declaration = self.require_memory(memory)
  self.require_signal(address)
  self.require_signal(data)
  require_memory_address(declaration, address)
  if data.signal_type != declaration.element_type {
    let expected = declaration.element_type.width().bits()
    let actual = data.signal_type.width().bits()
    if expected != actual {
      raise @ir.IrError::WidthMismatch(
        operation="memory_write",
        expected~,
        actual~,
      )
    }
    raise @ir.IrError::TypeMismatch(operation="memory_write")
  }
  let canonical_enable = match enable {
    Some(value) => {
      self.require_signal(value)
      require_memory_enable(value)
      Some(value.id)
    }
    None => None
  }
  let port_id = @ir.MemoryWritePortId::new(declaration.write_ports.length())
  declaration.write_ports.push(
    @ir.MemoryWritePort::new(
      port_id,
      name,
      declaration.domain.canonical,
      address.id,
      data.id,
      enable?=canonical_enable,
      mask,
    ),
  )
}

///|
/// Add a whole-element synchronous write port.
pub fn ModuleBuilder::memory_write(
  self : ModuleBuilder,
  memory : Memory,
  name : String,
  address : Signal,
  data : Signal,
  enable? : Signal,
) -> Unit raise {
  self.memory_write_with_mask(memory, name, address, data, enable, All)
}

///|
/// Add a synchronous masked write. Mask bit zero controls the least-significant
/// granule; each following bit controls the next contiguous granule.
pub fn ModuleBuilder::memory_write_masked(
  self : ModuleBuilder,
  memory : Memory,
  name : String,
  address : Signal,
  data : Signal,
  mask : Signal,
  granularity : Int32,
  enable? : Signal,
) -> Unit raise {
  let declaration = self.require_memory(memory)
  self.require_signal(mask)
  let granule = @ir.Width::new(granularity)
  let element_width = declaration.element_type.width().bits()
  if element_width % granularity != 0 {
    raise @ir.IrError::MemoryMaskGranularity(
      memory=declaration.id.ordinal(),
      port=declaration.write_ports.length(),
      element=element_width,
      granule=granularity,
    )
  }
  let expected = element_width / granularity
  guard mask.signal_type is Bits(mask_width) else {
    raise @ir.IrError::ExpectedMemoryMask(
      memory=declaration.id.ordinal(),
      port=declaration.write_ports.length(),
      node=mask.id.ordinal(),
    )
  }
  let actual = mask_width.bits()
  if actual != expected {
    raise @ir.IrError::MemoryMaskWidth(
      memory=declaration.id.ordinal(),
      port=declaration.write_ports.length(),
      expected~,
      actual~,
    )
  }
  self.memory_write_with_mask(
    memory,
    name,
    address,
    data,
    enable,
    Granular(signal=mask.id, granularity=granule),
  )
}
