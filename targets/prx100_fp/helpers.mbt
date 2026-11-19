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
  value : @wire.Signal,
  literal : UInt64,
) -> @wire.Signal raise {
  b.equal(value, b.constant(value.signal_type(), literal))
}

///|
fn both(
  b : @wire.ModuleBuilder,
  xs : ArrayView[@wire.Signal],
) -> @wire.Signal raise {
  let mut r = xs[0]
  for x in xs[1:] {
    r = b.bit_and(r, x)
  }
  r
}

///|
fn any(
  b : @wire.ModuleBuilder,
  xs : ArrayView[@wire.Signal],
) -> @wire.Signal raise {
  let mut r = xs[0]
  for x in xs[1:] {
    r = b.bit_or(r, x)
  }
  r
}

///|
fn u(b : @wire.ModuleBuilder, x : @wire.Signal) -> @wire.Signal raise {
  b.reinterpret(x, @wire.uint(x.signal_type().width().bits()))
}

///|
fn input(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  name : String,
  width : Int32,
) -> @wire.Signal raise {
  let x = b.input(
    name,
    if width == 1 {
      @wire.bits(1)
    } else {
      @wire.uint(width)
    },
  )
  b.input_timing(x, SampledIn(d.id()))
  x
}

///|
fn out(b : @wire.ModuleBuilder, name : String, x : @wire.Signal) -> Unit raise {
  let p = b.output(name, x.signal_type())
  b.output_timing(p, ProducedIn(@ir.ClockDomainId::new(0)))
  b.connect(p, x)
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
