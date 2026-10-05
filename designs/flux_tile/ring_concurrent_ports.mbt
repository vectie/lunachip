///|
// Public host-ring ports retain their existing meanings. Engine-local memory
// channels remain private; only the shared transport reaches the host.
fn ring_concurrent_outputs(
  builder : @wire.ModuleBuilder,
  ring : RingSignals,
  queue : QueuedConcurrentSignals,
  bus : ArbiterThreeRoutes,
  response_ready : @wire.Signal,
  stored : StoredSignals,
) -> Unit raise {
  for
    (name, signal) in [
      ("config_ready", ring.config_ready),
      ("publish_ready", ring.publish_ready),
      ("configured", ring.configured),
      ("producer_count", ring.producer_count),
      ("consumer_count", ring.consumer_count),
      ("ring_fault_valid", ring.fault_valid),
      ("ring_fault_code", ring.fault_code),
      ("ring_fault_address", ring.fault_address),
      ("queue_occupancy", queue.occupancy),
      ("halted", bus.poisoned),
      ("transport_halted", bus.poisoned),
      (
        "transport_fault_address",
        builder.mux(bus.poisoned, bus.address, execute_constant(builder, 32, 0)),
      ),
      ("completion_valid", queue.retirement.valid),
      ("completion_id", queue.retirement.id),
      ("completion_fault", queue.retirement.fault),
      ("completion_bytes_completed", queue.retirement.progress),
      ("completion_fault_address", queue.retirement.address),
      ("memory_request_valid", bus.request_valid),
      ("memory_request_write", bus.request_write),
      ("memory_request_address", bus.address),
      ("memory_request_bytes", bus.request_bytes),
      ("memory_request_mask", bus.request_mask),
      ("memory_request_data", bus.request_data),
      ("memory_request_tag", bus.request_tag),
      ("memory_response_ready", response_ready),
      ("accepted_steps", stored.execute.accepted_steps),
      ("elapsed_cycles", stored.execute.elapsed_cycles),
      ("active_cycles", stored.execute.active_cycles),
      ("stall_cycles", stored.execute.stall_cycles),
      ("capture_cycles", stored.capture_cycles),
    ] {
    execute_output(builder, name, signal)
  }
}
