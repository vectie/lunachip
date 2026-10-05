///|
pub(all) suberror PortableTileError {
  InvalidHostBytes(value~ : UInt64, maximum~ : UInt64)
} derive(Debug, Eq)

///|
pub extend PortableTileError with @debug.Debug::{to_repr}

///|
pub extend PortableTileError with Eq::{equal, not_equal}

///|
priv struct PortablePorts {
  command_valid : @wire.Signal
  opcode : @wire.Signal
  id : @wire.Signal
  rows : @wire.Signal
  columns : @wire.Signal
  reduction : @wire.Signal
  base : @wire.Signal
  stride : @wire.Signal
  completion_ready : @wire.Signal
  request_ready : @wire.Signal
  response_valid : @wire.Signal
  response_tag : @wire.Signal
  response_fault : @wire.Signal
  response_data : @wire.Signal
}

///|
priv struct PortableCommand {
  opcode : @wire.Signal
  id : @wire.Signal
  rows : @wire.Signal
  columns : @wire.Signal
  reduction : @wire.Signal
  base : @wire.Signal
  stride : @wire.Signal
}

///|
fn portable_inputs(builder : @wire.ModuleBuilder) -> PortablePorts raise {
  let command_valid = builder.input("command_valid", @wire.bits(1))
  let opcode = builder.input("command_opcode", @wire.uint(3))
  let id = builder.input("command_id", @wire.uint(32))
  let rows = builder.input("command_rows", @wire.uint(13))
  let columns = builder.input("command_columns", @wire.uint(13))
  let reduction = builder.input("command_reduction", @wire.uint(13))
  let base = builder.input("command_base", @wire.uint(32))
  let stride = builder.input("command_stride", @wire.uint(32))
  let completion_ready = builder.input("completion_ready", @wire.bits(1))
  let request_ready = builder.input("memory_request_ready", @wire.bits(1))
  let response_valid = builder.input("memory_response_valid", @wire.bits(1))
  let response_tag = builder.input("memory_response_tag", @wire.uint(32))
  let response_fault = builder.input("memory_response_fault", @wire.uint(2))
  let response_data = builder.input("memory_response_data", @wire.bits(32))
  {
    command_valid,
    opcode,
    id,
    rows,
    columns,
    reduction,
    base,
    stride,
    completion_ready,
    request_ready,
    response_valid,
    response_tag,
    response_fault,
    response_data,
  }
}

///|
fn portable_command(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  accept : @wire.Signal,
  ports : PortablePorts,
) -> PortableCommand raise {
  {
    opcode: execute_latch(builder, domain, reset, accept, ports.opcode),
    id: execute_latch(builder, domain, reset, accept, ports.id),
    rows: execute_latch(builder, domain, reset, accept, ports.rows),
    columns: execute_latch(builder, domain, reset, accept, ports.columns),
    reduction: execute_latch(builder, domain, reset, accept, ports.reduction),
    base: execute_latch(builder, domain, reset, accept, ports.base),
    stride: execute_latch(builder, domain, reset, accept, ports.stride),
  }
}
