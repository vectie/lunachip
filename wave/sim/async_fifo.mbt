///|
fn control_is_known_one(control : @wave.LogicValue) -> Bool raise {
  control.is_fully_known() && control.to_uint64() == 1UL
}

///|
fn checked_prepared_state_cells(
  current : UInt64,
  additional : UInt64,
  maximum : Int32,
) -> UInt64 raise SimulatorError {
  let total = if additional > 18446744073709551615UL - current {
    18446744073709551615UL
  } else {
    current + additional
  }
  if total > maximum.to_uint64() {
    raise UnsupportedTotalStateCells(total~, maximum~)
  }
  total
}

///|
fn validate_prepared_state_budget(
  hardware_module : @ir.Module,
  maximum : Int32,
) -> Unit raise {
  let mut total = 0UL
  for memory in hardware_module.memories() {
    let depth = memory.depth().elements()
    if depth > maximum {
      raise UnsupportedMemoryDepth(memory=memory.name(), depth~, maximum~)
    }
    total = checked_prepared_state_cells(total, depth.to_uint64(), maximum)
  }
  for primitive in hardware_module.cdc_primitives() {
    match primitive {
      AsyncFifo(fifo) =>
        total = checked_prepared_state_cells(
          total,
          fifo.depth().to_uint64() * fifo.source_payload().length().to_uint64(),
          maximum,
        )
      _ => ()
    }
  }
}

///|
fn prepare_async_fifo_storage(
  hardware_module : @ir.Module,
) -> (
  Array[PreparedAsyncFifo],
  Array[AsyncFifoReadBinding?],
  Array[PendingAsyncFifoWrite?],
) raise {
  let async_fifos : Array[PreparedAsyncFifo] = []
  let bindings : Array[AsyncFifoReadBinding?] = Array::make(
    hardware_module.nodes().length(),
    None,
  )
  let pending : Array[PendingAsyncFifoWrite?] = []
  for primitive in hardware_module.cdc_primitives() {
    match primitive {
      AsyncFifo(fifo) => {
        let fifo_index = async_fifos.length()
        let lanes : Array[Array[@wave.LogicValue]] = []
        for node_id in fifo.source_payload() {
          let node = hardware_module.node(node_id).unwrap()
          lanes.push(
            Array::make(
              fifo.depth(),
              @wave.LogicValue::unknown(width=node.signal_type().width().bits()),
            ),
          )
        }
        for leaf, raw_read in fifo.raw_reads() {
          bindings[raw_read.ordinal()] = Some({ fifo: fifo_index, leaf, })
        }
        async_fifos.push({ index: fifo_index, primitive: fifo, lanes, })
        pending.push(None)
      }
      _ => ()
    }
  }
  (async_fifos, bindings, pending)
}

///|
fn Simulator::async_fifo_address(
  self : Simulator,
  fifo : @ir.AsyncFifoPrimitive,
  node : @ir.NodeId,
) -> Int32? raise {
  let value = self.read_slot(node)
  if !value.is_fully_known() {
    return None
  }
  let address = value.to_uint64()
  if address >= fifo.depth().to_uint64() {
    raise AsyncFifoAddressOutOfRange(
      primitive=fifo.id().ordinal(),
      address~,
      depth=fifo.depth(),
    )
  }
  Some(address.to_int())
}

///|
fn Simulator::prepare_async_fifo_update(
  self : Simulator,
  prepared : PreparedAsyncFifo,
) -> Unit raise {
  let fifo = prepared.primitive
  if !control_is_known_one(self.read_slot(fifo.source_transfer())) {
    return
  }
  guard self.async_fifo_address(fifo, fifo.write_address()) is Some(address) else {
    return
  }
  let values : Array[@wave.LogicValue] = []
  for node in fifo.source_payload() {
    values.push(self.read_slot(node))
  }
  self.pending_async_fifos[prepared.index] = Some({ address, values, })
}

///|
fn Simulator::async_fifo_read(
  self : Simulator,
  node : @ir.NodeId,
) -> @wave.LogicValue raise {
  guard self.async_fifo_reads[node.ordinal()] is Some(binding) else {
    raise UnknownNode(node.ordinal())
  }
  let prepared = self.async_fifos[binding.fifo]
  guard self.async_fifo_address(
      prepared.primitive,
      prepared.primitive.read_address(),
    )
    is Some(address) else {
    return @wave.LogicValue::unknown(
      width=prepared.lanes[binding.leaf][0].width(),
    )
  }
  prepared.lanes[binding.leaf][address]
}
