///|
/// Free-running modulo-2^32 edge counts. Read differences between idle,
/// sequence-bracketed snapshots. The controller accepts every response beat.
fn cycle_profile(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  c : Map[String, @wire.Signal],
  loader : ResidentLoader,
  wide_owned : @wire.Signal,
  response : @wire.Signal,
  beat : @wire.Signal,
  sequence : @wire.Signal,
) -> Array[(UInt64, @wire.Signal)] raise {
  fn state(s : UInt64) -> @wire.Signal raise {
    eq(b, c["state"], s)
  }
  let bank = state(18UL)
  let issue = state(20UL)
  let handoff = b.bit_and(b.register_in(d, bank, reset~), issue)
  let drain = state(21UL)
  let advance = state(22UL)
  let write = state(23UL)
  let descriptor = any(b, [state(1UL), state(2UL), state(3UL), state(13UL)])
  let ddr_request = state(9UL)
  let ddr_response = state(10UL)
  let unary = any(b, [
    state(11UL),
    state(12UL),
    state(24UL),
    state(25UL),
    state(26UL),
    state(27UL),
    state(28UL),
  ])
  let matrix = any(b, [bank, issue, drain, advance, write])
  let other = both(b, [
    c["busy"],
    b.bit_not(any(b, [descriptor, matrix, ddr_request, ddr_response, unary])),
  ])
  let packet = b.bit_and(wide_owned, response)
  let empty = b.bit_and(wide_owned, b.bit_not(response))
  let first = eq(b, beat, 0UL)
  let conditions = [
    c["busy"],
    bank,
    issue,
    drain,
    advance,
    write,
    descriptor,
    ddr_request,
    ddr_response,
    unary,
    other,
    handoff,
    packet,
    b.bit_and(packet, issue),
    both(b, [empty, first]),
    both(b, [empty, b.bit_not(first)]),
    eq(b, loader.state.value(), 1UL),
    eq(b, loader.state.value(), 2UL),
    loader.launch,
    both(b, [bank, empty, first]),
    both(b, [bank, empty, b.bit_not(first)]),
    b.bit_and(bank, packet),
  ]
  // Per-opcode execution includes scalar DDR and SFU time but excludes
  // descriptor fetch/decode and the separately counted matrix states.
  let scalar = both(b, [c["busy"], b.bit_not(b.bit_or(descriptor, matrix))])
  for op in 0..<16 {
    conditions.push(b.bit_and(scalar, eq(b, c["opcode"], op.to_uint64())))
  }
  let regs = [(0x100UL, n(b, 32, 0x50465231UL)), (0x104UL, sequence)]
  for i, enable in conditions {
    let counter = b.register_state_in(d, @wire.uint(32), reset~)
    update(b, counter, enable, b.add(counter.value(), n(b, 32, 1UL)))
    regs.push((0x108UL + 4UL * i.to_uint64(), counter.value()))
  }
  regs.push((0x108UL + 4UL * conditions.length().to_uint64(), sequence))
  regs
}

///|
// All busy states outside the matrix/descriptor/DDR/unary partition. Two
// extra qualifiers split DDR request and response cycles between LOAD/STORE.
fn core_detail_counters(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  c : Map[String, @wire.Signal],
) -> Array[(UInt64, @wire.Signal)] raise {
  let enables = [4UL, 16UL, 5UL, 6UL, 7UL, 8UL, 17UL, 29UL, 30UL, 31UL, 19UL].map(state => {
      eq(b, c["state"], state)
    },
  )
  for state in [9UL, 10UL] {
    enables.push(b.bit_and(eq(b, c["state"], state), eq(b, c["opcode"], 14UL)))
  }
  let counters = []
  for i, enable in enables {
    let counter = b.register_state_in(d, @wire.uint(32), reset~)
    update(b, counter, enable, b.add(counter.value(), n(b, 32, 1UL)))
    counters.push((0x268UL + 4UL * i.to_uint64(), counter.value()))
  }
  counters
}
