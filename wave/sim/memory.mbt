///|
fn Simulator::port_control(
  self : Simulator,
  enable : @ir.NodeId?,
) -> @wave.LogicValue raise {
  match enable {
    Some(id) => self.read_slot(id)
    None => @wave.LogicValue::one(width=1)
  }
}

///|
fn control_may_be_one(control : @wave.LogicValue) -> Bool raise {
  control.bit_at(0) != Zero
}

///|
fn Simulator::memory_address(
  self : Simulator,
  memory : @ir.MemorySpec,
  role : @ir.MemoryPortRole,
  port : Int32,
  address : @ir.NodeId,
) -> Int32? raise {
  let value = self.read_slot(address)
  if !value.is_fully_known() {
    return match memory.bounds_policy() {
      Fault => raise MemoryAddressUnknown(memory=memory.name(), role~, port~)
      Undefined => None
    }
  }
  let raw = value.to_uint64()
  if raw >= memory.depth().elements().to_uint64() {
    return match memory.bounds_policy() {
      Fault =>
        raise MemoryAddressOutOfRange(
          memory=memory.name(),
          role~,
          port~,
          address=raw,
          depth=memory.depth().elements(),
        )
      Undefined => None
    }
  }
  Some(raw.to_int())
}

///|
fn masked_write_value(
  old_value : @wave.LogicValue,
  new_value : @wave.LogicValue,
  mask : @wave.LogicValue,
  granularity : Int32,
) -> @wave.LogicValue raise {
  let mut value_bits = 0UL
  let mut known_mask = 0UL
  for granule in 0..<mask.width() {
    let lsb = granule * granularity
    let msb = lsb + granularity - 1
    let selected = mask
      .slice(msb=granule, lsb=granule)
      .mux(new_value.slice(msb~, lsb~), old_value.slice(msb~, lsb~))
    value_bits = value_bits | (selected.value_bits() << lsb)
    known_mask = known_mask | (selected.known_mask() << lsb)
  }
  @wave.LogicValue::from_masks(
    width=old_value.width(),
    value_bits~,
    known_mask~,
  )
}

///|
fn Simulator::write_candidate(
  self : Simulator,
  old_value : @wave.LogicValue,
  port : @ir.MemoryWritePort,
) -> @wave.LogicValue raise {
  let data = self.read_slot(port.data())
  match port.mask() {
    All => data
    Granular(signal~, granularity~) =>
      masked_write_value(
        old_value,
        data,
        self.read_slot(signal),
        granularity.bits(),
      )
  }
}

///|
fn Simulator::validate_rejected_write_collisions(
  self : Simulator,
  memory : @ir.MemorySpec,
) -> Unit raise {
  if !(memory.multi_write_policy() is Reject) {
    return
  }
  let selected_addresses : Array[Int32] = []
  let selected_ports : Array[Int32] = []
  for port in memory.write_ports() {
    let control = self.port_control(port.enable())
    if !control_may_be_one(control) {
      continue
    }
    guard self.memory_address(
        memory,
        WritePort,
        port.id().ordinal(),
        port.address(),
      )
      is Some(address) else {
      continue
    }
    let mut first : Int32? = None
    for index in 0..<selected_addresses.length() {
      if selected_addresses[index] == address {
        first = Some(selected_ports[index])
        break
      }
    }
    match first {
      Some(first_port) =>
        raise MemoryWriteCollision(
          memory=memory.name(),
          address=address.to_uint64(),
          first_port~,
          second_port=port.id().ordinal(),
        )
      None => {
        selected_addresses.push(address)
        selected_ports.push(port.id().ordinal())
      }
    }
  }
}

///|
fn pending_memory_write_index(
  writes : ArrayView[PendingMemoryWrite],
  address : Int32,
) -> Int32? {
  for index in 0..<writes.length() {
    if writes[index].address == address {
      return Some(index)
    }
  }
  None
}

///|
fn resolved_memory_value(
  old_cells : ArrayView[@wave.LogicValue],
  writes : ArrayView[PendingMemoryWrite],
  address : Int32,
) -> @wave.LogicValue {
  match pending_memory_write_index(writes, address) {
    Some(index) => writes[index].value
    None => old_cells[address]
  }
}

///|
fn Simulator::pending_memory_writes(
  self : Simulator,
  memory : @ir.MemorySpec,
  old_cells : ArrayView[@wave.LogicValue],
) -> Array[PendingMemoryWrite] raise {
  self.validate_rejected_write_collisions(memory)
  let writes : Array[PendingMemoryWrite] = []
  let ports = memory.write_ports()
  // Apply low-priority ports first. Lower port ID is the final per-granule
  // writer and therefore has deterministic priority independent of iteration.
  for offset in 0..<ports.length() {
    let port = ports[ports.length() - offset - 1]
    let control = self.port_control(port.enable())
    if !control_may_be_one(control) {
      continue
    }
    guard self.memory_address(
        memory,
        WritePort,
        port.id().ordinal(),
        port.address(),
      )
      is Some(address) else {
      continue
    }
    let existing = pending_memory_write_index(writes, address)
    let old_value = match existing {
      Some(index) => writes[index].value
      None => old_cells[address]
    }
    let candidate = self.write_candidate(old_value, port)
    let write = PendingMemoryWrite::{
      address,
      value: control.mux(candidate, old_value),
    }
    match existing {
      Some(index) => writes[index] = write
      None => writes.push(write)
    }
  }
  writes
}

///|
fn Simulator::read_collision_control(
  self : Simulator,
  memory : @ir.MemorySpec,
  address : Int32,
) -> @wave.LogicValue raise {
  let mut collision = @wave.LogicValue::zero(width=1)
  for port in memory.write_ports() {
    let control = self.port_control(port.enable())
    if !control_may_be_one(control) {
      continue
    }
    match
      self.memory_address(
        memory,
        WritePort,
        port.id().ordinal(),
        port.address(),
      ) {
      Some(write_address) if write_address == address =>
        collision = collision.bit_or(control)
      _ => ()
    }
  }
  collision
}

///|
fn Simulator::memory_read_update(
  self : Simulator,
  memory : @ir.MemorySpec,
  port : @ir.MemoryReadPort,
  old_cells : ArrayView[@wave.LogicValue],
  pending_writes : ArrayView[PendingMemoryWrite],
) -> @wave.LogicValue raise {
  let old_result = self.read_slot(port.result())
  let disabled = match port.enable_behavior() {
    HoldLast => old_result
    Undefined =>
      @wave.LogicValue::unknown(width=memory.element_type().width().bits())
  }
  let control = self.port_control(port.enable())
  if !control_may_be_one(control) {
    return disabled
  }
  let active = match
    self.memory_address(memory, ReadPort, port.id().ordinal(), port.address()) {
    None =>
      @wave.LogicValue::unknown(width=memory.element_type().width().bits())
    Some(address) => {
      let collision = self.read_collision_control(memory, address)
      match memory.read_write_policy() {
        ReadOld => old_cells[address]
        ReadNew => resolved_memory_value(old_cells, pending_writes, address)
        NoChange => collision.mux(old_result, old_cells[address])
        Undefined =>
          collision.mux(
            @wave.LogicValue::unknown(
              width=memory.element_type().width().bits(),
            ),
            old_cells[address],
          )
        Reject =>
          // Canonical validation rejects every read/write-capable memory with
          // this policy, so a valid read-only memory has no collision.
          old_cells[address]
      }
    }
  }
  control.mux(active, disabled)
}

///|
fn Simulator::prepare_memory_update(
  self : Simulator,
  memory : @ir.MemorySpec,
) -> Unit raise {
  let ordinal = memory.id().ordinal()
  let old_cells = self.memory_cells[ordinal]
  let pending_writes = self.pending_memory_writes(memory, old_cells)
  for port in memory.read_ports() {
    self.pending_state[port.result().ordinal()] = Some(
      self.memory_read_update(memory, port, old_cells, pending_writes),
    )
  }
  self.pending_memories[ordinal] = Some(pending_writes)
}
