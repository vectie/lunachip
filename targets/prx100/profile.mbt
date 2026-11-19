///|
/// Separate elaboration identities for initial smoke and retained array shape.
pub(all) enum Profile {
  Smoke
  Array8
} derive(Eq, @debug.Debug)

///|
pub fn Profile::rows(self : Profile) -> Int32 {
  match self {
    Smoke => 1
    Array8 => 8
  }
}

///|
pub fn Profile::reduction(self : Profile) -> Int32 {
  match self {
    Smoke => 2
    Array8 => 16
  }
}

///|
/// Construct the existing generator without changing its hardware or ABI.
pub fn core(profile : Profile) -> @ir.Module raise {
  @flux_tile.ring_concurrent_tile(
    rows=profile.rows(),
    columns=profile.rows(),
    max_reduction=profile.reduction(),
    host_bytes=4096UL,
    ring_depth=4,
    queue_depth=3,
  )
}

///|
pub(all) suberror BoardError {
  InvalidDivisor(Int32)
  InvalidFrame(String)
  MissingMapping(String)
} derive(Eq, @debug.Debug)

///|
pub(all) struct Artifact {
  path : String
  content : String
} derive(Eq, @debug.Debug)

///|
fn number(
  b : @wire.ModuleBuilder,
  width : Int32,
  value : UInt64,
) -> @wire.Signal raise {
  b.constant(@wire.uint(width), value)
}

///|
fn same(
  b : @wire.ModuleBuilder,
  value : @wire.Signal,
  literal : UInt64,
) -> @wire.Signal raise {
  b.equal(value, b.constant(value.signal_type(), literal))
}

///|
fn all(
  b : @wire.ModuleBuilder,
  values : ArrayView[@wire.Signal],
) -> @wire.Signal raise {
  let mut result = values[0]
  for value in values[1:] {
    result = b.bit_and(result, value)
  }
  result
}

///|
fn either(
  b : @wire.ModuleBuilder,
  values : ArrayView[@wire.Signal],
) -> @wire.Signal raise {
  let mut result = values[0]
  for value in values[1:] {
    result = b.bit_or(result, value)
  }
  result
}

///|
fn output(
  b : @wire.ModuleBuilder,
  name : String,
  signal : @wire.Signal,
) -> Unit raise {
  let port = b.output(name, signal.signal_type())
  // Both board generators create clock as node0, hence clock-domain ID0.
  b.output_timing(port, ProducedIn(@ir.ClockDomainId::new(0)))
  b.connect(port, signal)
}

///|
fn sampled_input(
  b : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  name : String,
  signal_type : @ir.SignalType,
) -> @wire.Signal raise {
  let signal = b.input(name, signal_type)
  b.input_timing(signal, SampledIn(domain.id()))
  signal
}

///|
fn as_uint(b : @wire.ModuleBuilder, value : @wire.Signal) -> @wire.Signal raise {
  b.reinterpret(value, @wire.uint(value.signal_type().width().bits()))
}

///|
fn byte_at(
  b : @wire.ModuleBuilder,
  value : @wire.Signal,
  index : Int32,
) -> @wire.Signal raise {
  as_uint(b, b.slice(value, index * 8 + 7, index * 8))
}

///|
pub extend Profile with Eq::{equal, not_equal}

///|
pub extend Profile with @debug.Debug::{to_repr}

///|
pub extend BoardError with Eq::{equal, not_equal}

///|
pub extend BoardError with @debug.Debug::{to_repr}

///|
pub extend Artifact with Eq::{equal, not_equal}

///|
pub extend Artifact with @debug.Debug::{to_repr}
