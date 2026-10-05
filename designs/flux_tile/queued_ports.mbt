///|
pub(all) suberror QueuedTileError {
  InvalidQueueDepth(value~ : Int, minimum~ : Int, maximum~ : Int)
} derive(Debug, Eq)

///|
pub extend QueuedTileError with @debug.Debug::{to_repr}

///|
pub extend QueuedTileError with Eq::{equal, not_equal}

///|
fn queued_portable_inputs(
  builder : @wire.ModuleBuilder,
  descriptor : QueuedDescriptor,
  issue : @wire.Signal,
  active : @wire.Signal,
) -> PortablePorts raise {
  {
    command_valid: issue,
    opcode: descriptor.opcode,
    id: descriptor.id,
    rows: descriptor.rows,
    columns: descriptor.columns,
    reduction: descriptor.reduction,
    base: descriptor.base,
    stride: descriptor.stride,
    completion_ready: active,
    request_ready: builder.input("memory_request_ready", @wire.bits(1)),
    response_valid: builder.input("memory_response_valid", @wire.bits(1)),
    response_tag: builder.input("memory_response_tag", @wire.uint(32)),
    response_fault: builder.input("memory_response_fault", @wire.uint(2)),
    response_data: builder.input("memory_response_data", @wire.bits(32)),
  }
}

///|
priv struct QueuedCompletion {
  id : @wire.RegisterHandle
  fault : @wire.RegisterHandle
  bytes_completed : @wire.RegisterHandle
  fault_address : @wire.RegisterHandle
}

///|
fn queued_completion(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
) -> QueuedCompletion raise {
  {
    id: builder.register_state_in(domain, @wire.uint(32), reset~),
    fault: builder.register_state_in(domain, @wire.uint(4), reset~),
    bytes_completed: builder.register_state_in(domain, @wire.uint(32), reset~),
    fault_address: builder.register_state_in(domain, @wire.uint(32), reset~),
  }
}
