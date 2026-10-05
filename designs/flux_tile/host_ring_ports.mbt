///|
fn host_ring_outputs(
  builder : @wire.ModuleBuilder,
  ring : RingSignals,
  queue : QueuedSignals,
  bus : ArbiterRoutes,
  response_ready : @wire.Signal,
) -> Unit raise {
  execute_output(builder, "config_ready", ring.config_ready)
  execute_output(builder, "publish_ready", ring.publish_ready)
  execute_output(builder, "configured", ring.configured)
  execute_output(builder, "producer_count", ring.producer_count)
  execute_output(builder, "consumer_count", ring.consumer_count)
  execute_output(builder, "ring_fault_valid", ring.fault_valid)
  execute_output(builder, "ring_fault_code", ring.fault_code)
  execute_output(builder, "ring_fault_address", ring.fault_address)
  execute_output(builder, "queue_occupancy", queue.occupancy)
  execute_output(builder, "halted", queue.halted)
  execute_output(builder, "transport_halted", bus.poisoned)
  execute_output(
    builder,
    "transport_fault_address",
    builder.mux(bus.poisoned, bus.address, execute_constant(builder, 32, 0)),
  )
  execute_output(builder, "completion_valid", queue.completion_valid)
  execute_output(builder, "completion_id", queue.completion_id)
  execute_output(builder, "completion_fault", queue.completion_fault)
  execute_output(builder, "completion_bytes_completed", queue.bytes_completed)
  execute_output(builder, "completion_fault_address", queue.fault_address)
  execute_output(builder, "memory_request_valid", bus.request_valid)
  execute_output(builder, "memory_request_write", bus.request_write)
  execute_output(builder, "memory_request_address", bus.address)
  execute_output(builder, "memory_request_bytes", bus.request_bytes)
  execute_output(builder, "memory_request_mask", bus.request_mask)
  execute_output(builder, "memory_request_data", bus.request_data)
  execute_output(builder, "memory_request_tag", bus.request_tag)
  execute_output(builder, "memory_response_ready", response_ready)
  execute_output(builder, "accepted_steps", queue.core.accepted_steps)
  execute_output(builder, "elapsed_cycles", queue.core.elapsed_cycles)
  execute_output(builder, "active_cycles", queue.core.active_cycles)
  execute_output(builder, "stall_cycles", queue.core.stall_cycles)
  execute_output(builder, "capture_cycles", queue.core.capture_cycles)
}
