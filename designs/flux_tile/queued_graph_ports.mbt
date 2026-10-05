///|
priv struct QueuedContext {
  state : @wire.RegisterHandle
  halt : @wire.RegisterHandle
  head : Array[@wire.RegisterHandle]
  completion : QueuedCompletion
  states : Array[@wire.Signal]
  descriptor : QueuedDescriptor
  issue : @wire.Signal
}

///|
priv struct QueuedSignals {
  descriptor_ready : @wire.Signal
  occupancy : @wire.Signal
  halted : @wire.Signal
  completion_valid : @wire.Signal
  completion_id : @wire.Signal
  completion_fault : @wire.Signal
  bytes_completed : @wire.Signal
  fault_address : @wire.Signal
  core : PortableSignals
}

///|
fn queued_outputs(
  builder : @wire.ModuleBuilder,
  signals : QueuedSignals,
) -> Unit raise {
  execute_output(builder, "descriptor_ready", signals.descriptor_ready)
  execute_output(builder, "queue_occupancy", signals.occupancy)
  execute_output(builder, "halted", signals.halted)
  execute_output(builder, "completion_valid", signals.completion_valid)
  execute_output(builder, "completion_id", signals.completion_id)
  execute_output(builder, "completion_fault", signals.completion_fault)
  execute_output(builder, "completion_bytes_completed", signals.bytes_completed)
  execute_output(builder, "completion_fault_address", signals.fault_address)
  portable_memory_outputs(builder, signals.core)
}
