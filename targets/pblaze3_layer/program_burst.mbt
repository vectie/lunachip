///|
/// The bridge holds a 128-byte response stable until READY. Serialize its
/// 32 lanes directly into the existing 32-bit program RAM write port.
priv struct ProgramBurst {
  wide : @wire.RegisterHandle
  batch : @wire.RegisterHandle
  lane : @wire.RegisterHandle
  scalar_mode : @wire.RegisterHandle
  ready : @wire.Signal
}

///|
fn program_burst(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  read_owner : @wire.Signal,
) -> ProgramBurst raise {
  let wide = b.register_state_in(d, @wire.bits(1), reset~)
  let batch = b.register_state_in(d, @wire.bits(1), reset~)
  let lane = b.register_state_in(d, @wire.uint(5), reset~)
  let scalar_mode = b.register_state_in(d, @wire.uint(1), reset~)
  {
    wide,
    batch,
    lane,
    scalar_mode,
    ready: b.bit_or(
      b.bit_not(b.bit_and(read_owner, wide.value())),
      eq(b, lane.value(), 31UL),
    ),
  }
}

///|
fn ProgramBurst::bind(
  p : ProgramBurst,
  b : @wire.ModuleBuilder,
  loader : ResidentLoader,
  count : @wire.Signal,
  take : @wire.Signal,
  word : @wire.Signal,
) -> Unit raise {
  let remaining = b.sub(
    b.shift_left(b.zero_extend(count, 16), n(b, 16, 4UL)),
    b.zero_extend(loader.index.value(), 16),
  )
  let wide = both(b, [
    eq(b, p.scalar_mode.value(), 0UL),
    eq(b, b.slice(loader.address, 6, 0), 0UL),
    b.greater_equal(remaining, n(b, 16, 32UL)),
  ])
  // Sixteen adjacent 512-byte INCR bursts. Each is naturally aligned and
  // within one 4 KiB page. Use 128-byte beats and scalar words for the edges.
  update(b, p.wide, take, wide)
  update(
    b,
    p.batch,
    take,
    both(b, [
      wide,
      eq(b, b.slice(loader.address, 8, 0), 0UL),
      b.greater_equal(remaining, n(b, 16, 2048UL)),
    ]),
  )
  update(
    b,
    p.lane,
    b.bit_or(take, word),
    b.mux(take, n(b, 5, 0UL), b.add(p.lane.value(), n(b, 5, 1UL))),
  )
}

///|
fn ProgramBurst::request_flag(
  p : ProgramBurst,
  b : @wire.ModuleBuilder,
  owner : @wire.Signal,
  core : @wire.Signal,
) -> @wire.Signal raise {
  b.bit_or(core, b.bit_and(owner, p.wide.value()))
}

///|
fn ProgramBurst::word(
  p : ProgramBurst,
  b : @wire.ModuleBuilder,
  words : Array[@wire.Signal],
) -> @wire.Signal raise {
  let mut layer = words
  for bit in 0..<5 {
    let select = b.slice(p.lane.value(), bit, bit)
    layer = Array::makei(layer.length() / 2, i => {
      b.mux(select, layer[2 * i + 1], layer[2 * i])
    })
  }
  b.mux(p.wide.value(), layer[0], words[0])
}

///|
fn ProgramBurst::counters(
  p : ProgramBurst,
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  read_request : @wire.Signal,
  word : @wire.Signal,
  receive : @wire.Signal,
) -> Array[(UInt64, @wire.Signal)] raise {
  let regs = [
    (0x240UL, n(b, 32, 0x50425231UL)),
    (0x244UL, p.scalar_mode.value()),
  ]
  for
    i, enable in [
      both(b, [read_request, b.bit_not(p.wide.value())]),
      both(b, [read_request, p.wide.value(), b.bit_not(p.batch.value())]),
      b.bit_and(read_request, p.batch.value()),
      word,
      receive,
    ] {
    let r = b.register_state_in(d, @wire.uint(32), reset~)
    update(b, r, enable, b.add(r.value(), n(b, 32, 1UL)))
    regs.push((0x248UL + 4UL * i.to_uint64(), r.value()))
  }
  regs
}
