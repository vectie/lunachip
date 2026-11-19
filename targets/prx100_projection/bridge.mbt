///|
fn out_in(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  name : String,
  x : @wire.Signal,
) -> Unit raise {
  let p = b.output(name, x.signal_type())
  b.output_timing(p, ProducedIn(d.id()))
  b.connect(p, x)
}

///|
/// Aligned word/line transactions across50/100MHz with one source owner.
/// FIFO endpoints are reset together with MIG; job reset never resets them.
pub fn bridge() -> @ir.Module raise {
  build_bridge([])
}

///|
fn build_bridge(observations : Array[Observation]) -> @ir.Module raise {
  let b = @wire.ModuleBuilder::new("Prx100ProjectionDdrBridge")
  let slow = b.rising_edge(b.input("clock", @wire.clock()))
  let fast = b.rising_edge(b.input("ui_clock", @wire.clock()))
  let rs = b.input("reset", @wire.reset())
  let rf = b.input("ui_reset", @wire.reset())
  b.input_timing(rs, SampledIn(slow.id()))
  b.input_timing(rf, SampledIn(fast.id()))
  let sr = b.synchronous_reset(rs, 0UL)
  let fr = b.synchronous_reset(rf, 0UL)
  let valid = input(b, slow, "request_valid", 1)
  let write = input(b, slow, "request_write", 1)
  let address = input(b, slow, "request_address", 28)
  let data = input(b, slow, "request_data", 32)
  let ready = input(b, slow, "response_ready", 1)
  let calibrated = input(b, fast, "calibrated", 1)
  let command_ready = input(b, fast, "app_rdy", 1)
  let data_ready = input(b, fast, "app_wdf_rdy", 1)
  let read_valid = input(b, fast, "app_rd_data_valid", 1)
  let read_end = input(b, fast, "app_rd_data_end", 1)
  let words = Array::makei(4, i => {
    input(b, fast, "app_rd_word" + i.to_string(), 32)
  })
  let line_read = input(b, slow, "request_line", 1)
  let write_words = Array::makei(3, i => {
    input(b, slow, "request_data" + (i + 1).to_string(), 32)
  })
  // One aligned128-byte read owns eight ordered native lines. Only one native
  // read is outstanding; the four response registers absorb MIG's unstallable
  // return before a credit-gated FIFO drains it across the clock boundary.
  let burst = input(b, slow, "request_burst", 1)
  let state = b.register_state_in(fast, @wire.uint(3), reset=fr)
  let idle = eq(b, state.value(), 0UL)
  let sending = eq(b, state.value(), 1UL)
  let waiting = eq(b, state.value(), 2UL)
  let replying = eq(b, state.value(), 3UL)
  let collecting = eq(b, state.value(), 4UL)
  let request = b.register_state_in(fast, @wire.uint(64), reset=fr)
  let collected = Array::makei(3, _ => {
    b.register_state_in(fast, @wire.uint(32), reset=fr)
  })
  let collect_lane = b.register_state_in(fast, @wire.uint(2), reset=fr)
  let command_sent = b.register_state_in(fast, @wire.bits(1), reset=fr)
  let data_sent = b.register_state_in(fast, @wire.bits(1), reset=fr)
  let results = Array::makei(4, _ => {
    b.register_state_in(fast, @wire.uint(32), reset=fr)
  })
  let reply_lane = b.register_state_in(fast, @wire.uint(2), reset=fr)
  let line_index = b.register_state_in(fast, @wire.uint(3), reset=fr)
  let fault = b.register_state_in(fast, @wire.uint(2), reset=fr)
  let poisoned = b.register_state_in(fast, @wire.bits(1), reset=fr)
  let calibrated_once = b.register_state_in(fast, @wire.bits(1), reset=fr)
  update(b, calibrated_once, calibrated, n(b, 1, 1UL))
  let healthy = both(b, [calibrated, b.bit_not(poisoned.value())])
  let safe = b.bit_synchronizer(
    "memory_healthy",
    healthy,
    slow,
    2,
    source_domain=fast,
    reset=sr,
  )
  let source_state = b.register_state_in(slow, @wire.uint(2), reset=sr)
  let local_idle = eq(b, source_state.value(), 0UL)
  let local_wait = eq(b, source_state.value(), 1UL)
  let local_reply = eq(b, source_state.value(), 2UL)
  let local_sending = eq(b, source_state.value(), 3UL)
  let outgoing = Array::makei(3, _ => {
    b.register_state_in(slow, @wire.uint(32), reset=sr)
  })
  let send_lane = b.register_state_in(slow, @wire.uint(2), reset=sr)
  let local_address = b.register_state_in(slow, @wire.uint(28), reset=sr)
  let local_write = b.register_state_in(slow, @wire.bits(1), reset=sr)
  let local_line = b.register_state_in(slow, @wire.bits(1), reset=sr)
  let local_burst = b.register_state_in(slow, @wire.bits(1), reset=sr)
  let local_data = b.register_state_in(slow, @wire.uint(32), reset=sr)
  let local_fault = b.register_state_in(slow, @wire.uint(2), reset=sr)
  let receive_lane = b.register_state_in(slow, @wire.uint(5), reset=sr)
  let cached = b.register_state_in(slow, @wire.bits(1), reset=sr)
  let cache_address = b.register_state_in(slow, @wire.uint(24), reset=sr)
  let cache_words = Array::makei(4, _ => {
    b.register_state_in(slow, @wire.uint(32), reset=sr)
  })
  let hit = both(b, [
    safe,
    cached.value(),
    b.bit_not(write),
    b.bit_not(line_read),
    b.bit_not(burst),
    eq(b, b.slice(address, 1, 0), 0UL),
    b.equal(u(b, b.slice(address, 27, 4)), cache_address.value()),
  ])
  let payload = u(
    b,
    b.concat(
      b.concat(b.concat(b.concat(n(b, 1, 0UL), burst), line_read), write),
      b.concat(address, data),
    ),
  )
  let requests = b.asynchronous_fifo(
    "word_requests",
    slow,
    fast,
    b.ready_valid_forward(
      b.bit_or(local_sending, both(b, [valid, local_idle, b.bit_not(hit)])),
      @aggregate.Aggregate::leaf(
        b.mux(
          local_sending,
          b.zero_extend(
            table(b, send_lane.value(), outgoing.map(r => r.value())),
            64,
          ),
          payload,
        ),
      ),
    ),
    b.ready_valid_backward(b.bit_or(idle, collecting)),
    sr,
    fr,
    4,
  )
  let accept = b.bit_and(idle, requests.destination().valid())
  let received = requests.destination().payload().flatten()[0].value()
  let collect_fire = b.bit_and(collecting, requests.destination().valid())
  let collect_done = both(b, [collect_fire, eq(b, collect_lane.value(), 2UL)])
  let writing = b.slice(request.value(), 60, 60)
  let full_write = b.bit_and(writing, b.slice(request.value(), 61, 61))
  let burst_read = both(b, [
    b.slice(request.value(), 62, 62),
    b.slice(request.value(), 61, 61),
    b.bit_not(writing),
  ])
  let write_word = u(b, b.slice(request.value(), 31, 0))
  let lane = u(b, b.slice(request.value(), 35, 34))
  let command = both(b, [sending, healthy, b.bit_not(command_sent.value())])
  let wdf = both(b, [sending, healthy, writing, b.bit_not(data_sent.value())])
  let command_fire = b.bit_and(command, command_ready)
  let data_fire = b.bit_and(wdf, data_ready)
  let command_done = b.bit_or(command_sent.value(), command_fire)
  let data_done = b.bit_or(data_sent.value(), data_fire)
  let owned_read = both(b, [
    b.bit_not(writing),
    any(b, [waiting, b.bit_and(sending, command_done)]),
  ])
  let bad_read = b.bit_and(
    read_valid,
    b.bit_not(b.bit_and(owned_read, read_end)),
  )
  let calibration_lost = both(b, [
    calibrated_once.value(),
    b.bit_not(calibrated),
  ])
  let poison_now = b.bit_or(bad_read, calibration_lost)
  let read_fire = both(b, [read_valid, read_end, owned_read, healthy])
  let written = both(b, [sending, healthy, writing, command_done, data_done])
  let responses = b.asynchronous_fifo(
    "word_responses",
    fast,
    slow,
    b.ready_valid_forward(
      replying,
      @aggregate.Aggregate::leaf(
        u(
          b,
          b.concat(
            fault.value(),
            table(b, reply_lane.value(), results.map(r => r.value())),
          ),
        ),
      ),
    ),
    b.ready_valid_backward(
      both(b, [local_wait, b.bit_or(b.bit_not(local_line.value()), ready)]),
    ),
    fr,
    sr,
    4,
  )
  let flit_sent = b.bit_and(replying, responses.source().ready())
  let replied = both(b, [
    flit_sent,
    b.bit_or(writing, eq(b, reply_lane.value(), 3UL)),
  ])
  let continue_read = both(b, [
    replied,
    burst_read,
    b.bit_not(eq(b, line_index.value(), 7UL)),
  ])
  let fail_continue = both(b, [
    continue_read,
    b.bit_or(b.bit_not(healthy), poison_now),
  ])
  increment(b, line_index, accept, continue_read, n(b, 3, 1UL))
  increment(b, reply_lane, accept, flit_sent, n(b, 2, 1UL))
  let invalid_address = any(b, [
    b.bit_not(eq(b, b.slice(received, 33, 32), 0UL)),
    both(b, [
      b.slice(received, 61, 61),
      b.bit_not(eq(b, b.slice(received, 35, 32), 0UL)),
    ]),
    both(b, [
      b.slice(received, 62, 62),
      any(b, [
        b.bit_not(b.slice(received, 61, 61)),
        b.slice(received, 60, 60),
        b.bit_not(eq(b, b.slice(received, 38, 32), 0UL)),
      ]),
    ]),
  ])
  let refused = any(b, [b.bit_not(healthy), invalid_address, poison_now])
  let fail_owned = both(b, [poison_now, any(b, [sending, waiting])])
  let fail_collect = b.bit_and(poison_now, collecting)
  b.connect_next(
    state,
    b.mux(
      accept,
      b.mux(
        b.bit_and(b.slice(received, 61, 61), b.slice(received, 60, 60)),
        n(b, 3, 4UL),
        b.mux(refused, n(b, 3, 3UL), n(b, 3, 1UL)),
      ),
      b.mux(
        collect_done,
        b.mux(
          any(b, [
            b.bit_not(eq(b, fault.value(), 0UL)),
            b.bit_not(healthy),
            poison_now,
          ]),
          n(b, 3, 3UL),
          n(b, 3, 1UL),
        ),
        b.mux(
          any(b, [fail_owned, read_fire, written]),
          n(b, 3, 3UL),
          b.mux(
            replied,
            b.mux(
              continue_read,
              b.mux(
                both(b, [
                  healthy,
                  b.bit_not(poison_now),
                  eq(b, fault.value(), 0UL),
                ]),
                n(b, 3, 1UL),
                n(b, 3, 3UL),
              ),
              n(b, 3, 0UL),
            ),
            b.mux(
              both(b, [sending, b.bit_not(writing), command_done]),
              n(b, 3, 2UL),
              state.value(),
            ),
          ),
        ),
      ),
    ),
  )
  update(b, request, accept, received)
  increment(b, collect_lane, accept, collect_fire, n(b, 2, 1UL))
  for i, r in collected {
    update(
      b,
      r,
      both(b, [collect_fire, eq(b, collect_lane.value(), i.to_uint64())]),
      u(b, b.slice(received, 31, 0)),
    )
  }
  b.connect_next(
    command_sent,
    b.mux(
      b.bit_or(accept, continue_read),
      n(b, 1, 0UL),
      b.bit_or(command_sent.value(), command_fire),
    ),
  )
  b.connect_next(
    data_sent,
    b.mux(accept, n(b, 1, 0UL), b.bit_or(data_sent.value(), data_fire)),
  )
  update(b, poisoned, poison_now, n(b, 1, 1UL))
  let capture_result = any(b, [accept, fail_owned, read_fire, continue_read])
  for i, r in results {
    update(b, r, capture_result, b.mux(read_fire, words[i], n(b, 32, 0UL)))
  }
  update(
    b,
    fault,
    any(b, [accept, fail_owned, fail_collect, fail_continue]),
    b.mux(
      any(b, [fail_owned, fail_collect, fail_continue]),
      b.mux(calibration_lost, n(b, 2, 2UL), n(b, 2, 3UL)),
      b.mux(
        refused,
        b.mux(invalid_address, n(b, 2, 1UL), n(b, 2, 2UL)),
        n(b, 2, 0UL),
      ),
    ),
  )
  let source_ready = b.bit_and(
    local_idle,
    b.bit_or(hit, requests.source().ready()),
  )
  let source_accept = b.bit_and(valid, source_ready)
  let send_fire = b.bit_and(local_sending, requests.source().ready())
  let send_done = b.bit_and(send_fire, eq(b, send_lane.value(), 2UL))
  increment(b, send_lane, source_accept, send_fire, n(b, 2, 1UL))
  for i, r in outgoing {
    update(b, r, source_accept, write_words[i])
  }
  let response = responses.destination().payload().flatten()[0].value()
  let stream_valid = both(b, [
    local_wait,
    local_line.value(),
    responses.destination().valid(),
  ])
  let returned = both(b, [
    local_wait,
    responses.destination().valid(),
    b.bit_or(b.bit_not(local_line.value()), ready),
  ])
  let returned_word = u(b, b.slice(response, 31, 0))
  let response_fault = u(b, b.slice(response, 33, 32))
  let finished = both(b, [
    returned,
    b.bit_or(
      local_write.value(),
      b.equal(
        receive_lane.value(),
        b.mux(local_burst.value(), n(b, 5, 31UL), n(b, 5, 3UL)),
      ),
    ),
  ])
  let install = both(b, [
    finished,
    b.bit_not(local_write.value()),
    b.bit_not(local_burst.value()),
    eq(b, response_fault, 0UL),
    eq(b, local_fault.value(), 0UL),
    safe,
  ])
  increment(b, receive_lane, source_accept, returned, n(b, 5, 1UL))
  b.connect_next(
    source_state,
    b.mux(
      source_accept,
      b.mux(
        hit,
        n(b, 2, 2UL),
        b.mux(b.bit_and(line_read, write), n(b, 2, 3UL), n(b, 2, 1UL)),
      ),
      b.mux(
        send_done,
        n(b, 2, 1UL),
        b.mux(
          finished,
          b.mux(local_line.value(), n(b, 2, 0UL), n(b, 2, 2UL)),
          b.mux(
            b.bit_and(local_reply, ready),
            n(b, 2, 0UL),
            source_state.value(),
          ),
        ),
      ),
    ),
  )
  update(b, local_address, source_accept, address)
  update(b, local_write, source_accept, write)
  update(b, local_line, source_accept, b.bit_and(line_read, b.bit_not(write)))
  update(
    b,
    local_burst,
    source_accept,
    both(b, [burst, line_read, b.bit_not(write)]),
  )
  let selected_return = both(b, [
    returned,
    b.bit_or(
      local_write.value(),
      b.equal(
        receive_lane.value(),
        b.zero_extend(u(b, b.slice(local_address.value(), 3, 2)), 5),
      ),
    ),
  ])
  update(
    b,
    local_data,
    b.bit_or(source_accept, selected_return),
    b.mux(
      returned,
      returned_word,
      b.mux(
        hit,
        table(b, u(b, b.slice(address, 3, 2)), cache_words.map(r => r.value())),
        n(b, 32, 0UL),
      ),
    ),
  )
  update(
    b,
    local_fault,
    b.bit_or(source_accept, returned),
    b.mux(returned, b.bit_or(response_fault, local_fault.value()), n(b, 2, 0UL)),
  )
  b.connect_next(
    cached,
    b.mux(
      any(b, [
        b.bit_not(safe),
        both(b, [source_accept, b.bit_or(write, line_read)]),
        both(b, [returned, b.bit_not(eq(b, response_fault, 0UL))]),
      ]),
      n(b, 1, 0UL),
      b.mux(install, n(b, 1, 1UL), cached.value()),
    ),
  )
  update(b, cache_address, install, u(b, b.slice(local_address.value(), 27, 4)))
  for i, r in cache_words {
    update(
      b,
      r,
      both(b, [
        returned,
        b.bit_not(local_write.value()),
        eq(b, receive_lane.value(), i.to_uint64()),
      ]),
      returned_word,
    )
  }
  out_in(b, slow, "request_ready", source_ready)
  out_in(b, slow, "response_valid", b.bit_or(local_reply, stream_valid))
  out_in(
    b,
    slow,
    "response_data",
    b.mux(local_line.value(), returned_word, local_data.value()),
  )
  out_in(
    b,
    slow,
    "response_fault",
    b.mux(
      local_line.value(),
      b.bit_or(response_fault, local_fault.value()),
      local_fault.value(),
    ),
  )
  out_in(
    b,
    slow,
    "response_last",
    b.bit_or(
      b.bit_not(local_line.value()),
      b.equal(
        receive_lane.value(),
        b.mux(local_burst.value(), n(b, 5, 31UL), n(b, 5, 3UL)),
      ),
    ),
  )
  out_in(b, slow, "memory_healthy", safe)
  bridge_native_outputs(
    b,
    fast,
    request.value(),
    line_index.value(),
    command,
    wdf,
    writing,
    full_write,
    lane,
    write_word,
    collected,
    state.value(),
    poisoned.value(),
  )
  let hw = b.finish()
  for
    (name, signal) in [
      ("state", state.value()),
      ("request", request.value()),
      ("command_sent", command_sent.value()),
      ("data_sent", data_sent.value()),
      ("poisoned", poisoned.value()),
      ("source_state", source_state.value()),
      ("cache_valid", cached.value()),
      ("cache_hit", hit),
      ("source_accept", source_accept),
      ("receive_lane", receive_lane.value()),
      ("install", install),
      ("calibrated_once", calibrated_once.value()),
      ("source_line", local_line.value()),
      ("source_burst", local_burst.value()),
      ("line_index", line_index.value()),
    ] {
    observations.push({ name, node: signal.id(), })
  }
  hw
}
