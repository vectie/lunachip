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
fn update(
  b : @wire.ModuleBuilder,
  r : @wire.RegisterHandle,
  enable : @wire.Signal,
  value : @wire.Signal,
) -> Unit raise {
  b.connect_next(r, b.mux(enable, value, r.value()))
}

///|
fn increment(
  b : @wire.ModuleBuilder,
  r : @wire.RegisterHandle,
  clear : @wire.Signal,
  enable : @wire.Signal,
  amount : @wire.Signal,
) -> Unit raise {
  b.connect_next(
    r,
    b.mux(
      clear,
      b.constant(r.value().signal_type(), 0UL),
      b.mux(enable, b.add(r.value(), amount), r.value()),
    ),
  )
}

///|
fn table(
  b : @wire.ModuleBuilder,
  index : @wire.Signal,
  values : ArrayView[@wire.Signal],
) -> @wire.Signal raise {
  let mut value = values[0]
  for i, x in values {
    value = b.mux(eq(b, index, i.to_uint64()), x, value)
  }
  value
}
