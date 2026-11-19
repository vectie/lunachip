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

///|
fn pattern(
  b : @wire.ModuleBuilder,
  beat : @wire.Signal,
  seed : @wire.Signal,
  mode : @wire.Signal,
  expected : Bool,
) -> Array[@wire.Signal] raise {
  let address = u(b, b.concat(beat, n(b, 4, 0UL)))
  let index = b.zero_extend(address, 32)
  let words : Array[@wire.Signal] = []
  for salt in [0x13579bdfUL, 0x2468ace0UL, 0x9e3779b9UL, 0x5a5aa5a5UL] {
    let x = b.bit_xor(b.bit_xor(index, seed), n(b, 32, salt))
    let x = b.bit_xor(x, b.shift_left(x, n(b, 5, 13UL)))
    let x = b.bit_xor(x, b.logical_shift_right(x, n(b, 5, 17UL)))
    let x = b.bit_xor(x, b.shift_left(x, n(b, 5, 5UL)))
    let x = b.mux(eq(b, mode, 5UL), b.bit_not(x), x)
    let x = if expected {
      b.mux(eq(b, mode, 6UL), b.bit_and(x, n(b, 32, 0x00ff00ffUL)), x)
    } else {
      x
    }
    let x = b.mux(
      eq(b, mode, 0UL),
      n(b, 32, 0UL),
      b.mux(
        eq(b, mode, 1UL),
        n(b, 32, 0xffffffffUL),
        b.mux(
          eq(b, mode, 2UL),
          n(b, 32, 0xaaaaaaaaUL),
          b.mux(eq(b, mode, 3UL), n(b, 32, 0x55555555UL), x),
        ),
      ),
    )
    words.push(x)
  }
  words
}
