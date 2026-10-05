///|
priv struct ConcurrentInputs {
  load : ConcurrentTransferPorts
  compute : ConcurrentComputePorts
  store : ConcurrentTransferPorts
  bus : ArbiterBusInputs
}

///|
priv struct ConcurrentTransferSignals {
  command_ready : @wire.Signal
  completion_valid : @wire.Signal
  completion_id : @wire.Signal
  completion_fault : @wire.Signal
  bytes_completed : @wire.Signal
  fault_address : @wire.Signal
}

///|
priv struct ConcurrentComputeSignals {
  command_ready : @wire.Signal
  completion_valid : @wire.Signal
  completion_id : @wire.Signal
  completion_fault : @wire.Signal
}

///|
priv struct ConcurrentMemorySignals {
  request_valid : @wire.Signal
  request_write : @wire.Signal
  address : @wire.Signal
  request_bytes : @wire.Signal
  request_mask : @wire.Signal
  request_data : @wire.Signal
  request_tag : @wire.Signal
  response_ready : @wire.Signal
  halted : @wire.Signal
}

///|
// Read-only composition boundary; no engine register handles escape the graph.
priv struct ConcurrentSignals {
  load : ConcurrentTransferSignals
  compute : ConcurrentComputeSignals
  store : ConcurrentTransferSignals
  memory : ConcurrentMemorySignals
  stored : StoredSignals
}
