///|
pub(all) suberror ExecuteTileError {
  InvalidParameter(name~ : String, value~ : Int, maximum~ : Int)
} derive(Eq, @debug.Debug)

///|
pub extend ExecuteTileError with Eq::{not_equal, equal}

///|
pub extend ExecuteTileError with @moonbitlang/core/debug.Debug::{to_repr}

///|
fn execute_constant(
  builder : @wire.ModuleBuilder,
  width : Int,
  value : Int,
) -> @wire.Signal raise {
  builder.constant(@wire.uint(width), value.to_uint64())
}

///|
fn execute_and(
  builder : @wire.ModuleBuilder,
  conditions : Array[@wire.Signal],
) -> @wire.Signal raise {
  let mut result = conditions[0]
  for index in 1..<conditions.length() {
    result = builder.bit_and(result, conditions[index])
  }
  result
}

///|
fn execute_output(
  builder : @wire.ModuleBuilder,
  name : String,
  signal : @wire.Signal,
) -> Unit raise {
  builder.connect(builder.output(name, signal.signal_type()), signal)
}

///|
fn execute_counter(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  width : Int,
  command_accept : @wire.Signal,
  increment : @wire.Signal,
) -> @wire.Signal raise {
  let enabled = builder.bit_or(command_accept, increment)
  let counter = builder.register_state_in(
    domain,
    @wire.uint(width),
    reset~,
    enable=enabled,
  )
  let next = builder.mux(
    command_accept,
    execute_constant(builder, width, 0),
    builder.add(counter.value(), execute_constant(builder, width, 1)),
  )
  builder.connect_next(counter, next)
  counter.value()
}

///|
fn execute_latch(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  accept : @wire.Signal,
  value : @wire.Signal,
) -> @wire.Signal raise {
  builder.register_in(domain, value, reset~, enable=accept)
}
