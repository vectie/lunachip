///|
fn n(
  b : @wire.ModuleBuilder,
  width : Int32,
  value : UInt64,
) -> @wire.Signal raise {
  b.constant(if width == 1 { @wire.bits(1) } else { @wire.uint(width) }, value)
}

///|
fn eq(
  b : @wire.ModuleBuilder,
  x : @wire.Signal,
  value : UInt64,
) -> @wire.Signal raise {
  b.equal(x, b.constant(x.signal_type(), value))
}

///|
fn all(b : @wire.ModuleBuilder, xs : Array[@wire.Signal]) -> @wire.Signal raise {
  let mut value = xs[0]
  for x in xs[1:] {
    value = b.bit_and(value, x)
  }
  value
}

///|
fn any(b : @wire.ModuleBuilder, xs : Array[@wire.Signal]) -> @wire.Signal raise {
  let mut value = xs[0]
  for x in xs[1:] {
    value = b.bit_or(value, x)
  }
  value
}

///|
fn input(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  name : String,
  width : Int32,
) -> @wire.Signal raise {
  let signal = b.input(
    name,
    if width == 1 {
      @wire.bits(1)
    } else {
      @wire.uint(width)
    },
  )
  b.input_timing(signal, SampledIn(d.id()))
  signal
}

///|
fn out(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  name : String,
  value : @wire.Signal,
) -> Unit raise {
  let port = b.output(name, value.signal_type())
  b.output_timing(port, ProducedIn(d.id()))
  b.connect(port, value)
}

///|
fn constant_output(
  b : @wire.ModuleBuilder,
  name : String,
  value : UInt64,
) -> Unit raise {
  let port = b.output(name, @wire.bits(1))
  b.output_timing(port, Static)
  b.connect(port, n(b, 1, value))
}

///|
fn update(
  b : @wire.ModuleBuilder,
  r : @wire.RegisterHandle,
  enable : @wire.Signal,
  value : @wire.Signal,
) -> Unit raise {
  b.connect_next(r, b.mux(enable, value, r.value()))
}
