///|
pub(all) suberror RingReaderError {
  InvalidRingDepth(value~ : Int32)
  InvalidHostBytes(value~ : UInt64, maximum~ : UInt64)
} derive(Debug, Eq)

///|
pub extend RingReaderError with @debug.Debug::{to_repr}

///|
pub extend RingReaderError with Eq::{equal, not_equal}

///|
priv struct RingInputs {
  config_valid : @wire.Signal
  config_base : @wire.Signal
  config_origin : @wire.Signal
  publish_valid : @wire.Signal
  publish_producer : @wire.Signal
  descriptor_ready : @wire.Signal
  request_ready : @wire.Signal
  response_valid : @wire.Signal
  response_tag : @wire.Signal
  response_fault : @wire.Signal
  response_data : @wire.Signal
}

///|
priv struct RingSignals {
  config_ready : @wire.Signal
  publish_ready : @wire.Signal
  configured : @wire.Signal
  producer_count : @wire.Signal
  consumer_count : @wire.Signal
  descriptor_valid : @wire.Signal
  descriptor_lanes : Array[@wire.Signal]
  fault_valid : @wire.Signal
  fault_code : @wire.Signal
  fault_address : @wire.Signal
  request_valid : @wire.Signal
  request_write : @wire.Signal
  address : @wire.Signal
  request_bytes : @wire.Signal
  request_mask : @wire.Signal
  request_data : @wire.Signal
  request_tag : @wire.Signal
  response_ready : @wire.Signal
}

///|
fn ring_inputs(builder : @wire.ModuleBuilder) -> RingInputs raise {
  {
    config_valid: builder.input("config_valid", @wire.bits(1)),
    config_base: builder.input("config_base", @wire.uint(32)),
    config_origin: builder.input("config_origin", @wire.uint(32)),
    publish_valid: builder.input("publish_valid", @wire.bits(1)),
    publish_producer: builder.input("publish_producer", @wire.uint(32)),
    descriptor_ready: builder.input("descriptor_ready", @wire.bits(1)),
    request_ready: builder.input("memory_request_ready", @wire.bits(1)),
    response_valid: builder.input("memory_response_valid", @wire.bits(1)),
    response_tag: builder.input("memory_response_tag", @wire.uint(32)),
    response_fault: builder.input("memory_response_fault", @wire.uint(2)),
    response_data: builder.input("memory_response_data", @wire.bits(32)),
  }
}

///|
fn ring_outputs(
  builder : @wire.ModuleBuilder,
  signals : RingSignals,
) -> Unit raise {
  execute_output(builder, "config_ready", signals.config_ready)
  execute_output(builder, "publish_ready", signals.publish_ready)
  execute_output(builder, "configured", signals.configured)
  execute_output(builder, "producer_count", signals.producer_count)
  execute_output(builder, "consumer_count", signals.consumer_count)
  execute_output(builder, "descriptor_valid", signals.descriptor_valid)
  for index in 0..<4 {
    execute_output(
      builder,
      "descriptor_lane_\{index}",
      signals.descriptor_lanes[index],
    )
  }
  execute_output(builder, "fault_valid", signals.fault_valid)
  execute_output(builder, "fault_code", signals.fault_code)
  execute_output(builder, "fault_address", signals.fault_address)
  execute_output(builder, "memory_request_valid", signals.request_valid)
  execute_output(builder, "memory_request_write", signals.request_write)
  execute_output(builder, "memory_request_address", signals.address)
  execute_output(builder, "memory_request_bytes", signals.request_bytes)
  execute_output(builder, "memory_request_mask", signals.request_mask)
  execute_output(builder, "memory_request_data", signals.request_data)
  execute_output(builder, "memory_request_tag", signals.request_tag)
  execute_output(builder, "memory_response_ready", signals.response_ready)
}
