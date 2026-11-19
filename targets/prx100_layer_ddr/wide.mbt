///|
priv struct ResponsePath {
  ready : @wire.Signal
  valid : @wire.Signal
  data : Array[@wire.Signal]
}

///|
// A registered reservation joins four checked <=64-bit CDC FIFOs without
// forward combinational wires or changing the canonical FIFO primitive.
// No other writer/reader can spend a reserved entry. Source valid/payload
// remains held until the reservation pulse is consumed. Destination valid
// holds its reservation until the external receiver accepts the packet.
// Packets take at least two slow edges; UI writes take at least two UI edges.
fn response_fifo(
  b : @wire.ModuleBuilder,
  fast : @wire.ClockDomain,
  slow : @wire.ClockDomain,
  valid : @wire.Signal,
  head : @wire.Signal,
  extra : Array[@wire.Signal],
  ready : @wire.Signal,
  fr : @wire.SynchronousReset,
  sr : @wire.SynchronousReset,
  streaming~ : Bool = false,
  staggered~ : Bool = false,
) -> ResponsePath raise {
  if extra.is_empty() {
    let f = b.asynchronous_fifo(
      "word_responses",
      fast,
      slow,
      b.ready_valid_forward(valid, @aggregate.Aggregate::leaf(head)),
      b.ready_valid_backward(ready),
      fr,
      sr,
      64,
    )
    {
      ready: f.source().ready(),
      valid: f.destination().valid(),
      data: [f.destination().payload().flatten()[0].value()],
    }
  } else if streaming {
    interleaved_responses(
      b,
      fast,
      slow,
      valid,
      head,
      extra,
      ready,
      fr,
      sr,
      staggered~,
    )
  } else {
    assert_eq(extra.length(), 3)
    let send = b.register_state_in(fast, @wire.bits(1), reset=fr)
    let take = b.register_state_in(slow, @wire.bits(1), reset=sr)
    let take_fire = b.bit_and(take.value(), ready)
    let fifos = [head, ..extra].mapi((i, data) => {
      b.asynchronous_fifo(
        if i == 0 {
          "word_responses"
        } else {
          "wide_response_" + i.to_string()
        },
        fast,
        slow,
        b.ready_valid_forward(send.value(), @aggregate.Aggregate::leaf(data)),
        b.ready_valid_backward(take_fire),
        fr,
        sr,
        64,
      )
    })
    let all_ready = both(b, fifos.map(f => f.source().ready()))
    let all_valid = both(b, fifos.map(f => f.destination().valid()))
    b.connect_next(
      send,
      b.bit_and(b.bit_not(send.value()), b.bit_and(valid, all_ready)),
    )
    b.connect_next(
      take,
      b.bit_or(
        b.bit_and(take.value(), b.bit_not(ready)),
        b.bit_and(b.bit_not(take.value()), all_valid),
      ),
    )
    {
      ready: send.value(),
      valid: take.value(),
      data: fifos.map(f => f.destination().payload().flatten()[0].value()),
    }
  }
}

///|
fn source_last(
  b : @wire.ModuleBuilder,
  burst : @wire.RegisterHandle,
  wide : @wire.RegisterHandle?,
  batch~ : @wire.RegisterHandle? = None,
  eight_row~ : Bool = false,
  sixteen_row~ : Bool = false,
  delivery~ : Bool = false,
) -> @wire.Signal raise {
  if batch is Some(r) {
    return b.mux(
      r.value(),
      n(
        b,
        if sixteen_row {
          9
        } else if eight_row {
          8
        } else {
          7
        },
        if sixteen_row {
          if delivery {
            504UL
          } else {
            508UL
          }
        } else if eight_row {
          252UL
        } else {
          124UL
        },
      ),
      b.zero_extend(
        source_last(b, burst, wide, delivery~),
        if sixteen_row {
          9
        } else if eight_row {
          8
        } else {
          7
        },
      ),
    )
  }
  match wide {
    Some(r) =>
      b.mux(
        r.value(),
        n(b, 5, if delivery { 24UL } else { 28UL }),
        b.mux(burst.value(), n(b, 5, 31UL), n(b, 5, 3UL)),
      )
    None => b.mux(burst.value(), n(b, 5, 31UL), n(b, 5, 3UL))
  }
}
