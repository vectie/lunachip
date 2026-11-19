///|
// Each of two banks keeps the original all-ready/all-valid reservation.
// The inactive bank acquires its next reservation while the other transfers.
// Independent CDC flags may settle on different edges: their conjunction
// reserves a packet, never one representative FIFO's flag.
fn interleaved_responses(
  b : @wire.ModuleBuilder,
  fast : @wire.ClockDomain,
  slow : @wire.ClockDomain,
  valid : @wire.Signal,
  head : @wire.Signal,
  extra : Array[@wire.Signal],
  ready : @wire.Signal,
  fr : @wire.SynchronousReset,
  sr : @wire.SynchronousReset,
  staggered~ : Bool = false,
) -> ResponsePath raise {
  assert_true(extra.length() == 3 || extra.length() == 7)
  let source_bank = b.register_state_in(fast, @wire.bits(1), reset=fr)
  let destination_bank = b.register_state_in(slow, @wire.bits(1), reset=sr)
  let send = Array::makei(2, _ => {
    b.register_state_in(fast, @wire.bits(1), reset=fr)
  })
  let take = Array::makei(2, _ => {
    b.register_state_in(slow, @wire.bits(1), reset=sr)
  })
  let source_ready = b.mux(
    source_bank.value(),
    send[1].value(),
    send[0].value(),
  )
  let destination_valid = b.mux(
    destination_bank.value(),
    take[1].value(),
    take[0].value(),
  )
  let source_fire = b.bit_and(valid, source_ready)
  let destination_fire = b.bit_and(ready, destination_valid)
  let payloads : Array[Array[@wire.Signal]] = []
  for bank in 0..<2 {
    let selected_source = eq(b, source_bank.value(), bank.to_uint64())
    let selected_destination = eq(b, destination_bank.value(), bank.to_uint64())
    let push = b.bit_and(source_fire, selected_source)
    let pop = b.bit_and(destination_fire, selected_destination)
    let fifos = [head, ..extra].mapi((lane, data) => {
      let index = bank * (1 + extra.length()) + lane
      b.asynchronous_fifo(
        if index == 0 {
          "word_responses"
        } else {
          "wide_response_" + index.to_string()
        },
        fast,
        slow,
        b.ready_valid_forward(push, @aggregate.Aggregate::leaf(data)),
        b.ready_valid_backward(pop),
        fr,
        sr,
        32,
        synchronizer_stages=if staggered { 2 + lane % 2 } else { 2 },
      )
    })
    let all_ready = both(b, fifos.map(f => f.source().ready()))
    let all_valid = both(b, fifos.map(f => f.destination().valid()))
    b.connect_next(
      send[bank],
      b.mux(push, n(b, 1, 0UL), b.bit_or(send[bank].value(), all_ready)),
    )
    b.connect_next(
      take[bank],
      b.mux(pop, n(b, 1, 0UL), b.bit_or(take[bank].value(), all_valid)),
    )
    payloads.push(
      fifos.map(f => f.destination().payload().flatten()[0].value()),
    )
  }
  update(b, source_bank, source_fire, b.bit_not(source_bank.value()))
  update(
    b,
    destination_bank,
    destination_fire,
    b.bit_not(destination_bank.value()),
  )
  {
    ready: source_ready,
    valid: destination_valid,
    data: Array::makei(1 + extra.length(), lane => {
      b.mux(destination_bank.value(), payloads[1][lane], payloads[0][lane])
    }),
  }
}
