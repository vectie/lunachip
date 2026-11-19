///|
fn build_bridge(
  observations : Array[Observation],
  wide~ : Bool = false,
  batch~ : Bool = false,
  streaming~ : Bool = false,
  staggered~ : Bool = false,
  read_ahead~ : Bool = false,
  eight_row~ : Bool = false,
  sixteen_row~ : Bool = false,
  aligned_extent~ : Bool = false,
  delivery~ : Bool = false,
) -> @ir.Module raise {
  assert_true(!delivery || sixteen_row)
  assert_true(!read_ahead || (wide && batch && streaming))
  assert_true(!eight_row || read_ahead)
  assert_true(!sixteen_row || (eight_row && aligned_extent))
  assert_true(!aligned_extent || eight_row)
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
  // One aligned 128-byte read owns at most eight ordered native lines. All
  // unstallable returns have reserved register slots, independently of source
  // backpressure. Ordinary word/line operations retain their serial path.
  let burst = input(b, slow, "request_burst", 1)
  let request_wide = if wide {
    Some(input(b, slow, "request_wide", 1))
  } else {
    None
  }
  let state = b.register_state_in(fast, @wire.uint(3), reset=fr)
  let pipeline = eq(b, state.value(), 5UL)
  let line_bits = if sixteen_row {
    8
  } else if eight_row {
    7
  } else if read_ahead {
    6
  } else {
    4
  }
  let word_bits = if sixteen_row {
    10
  } else if eight_row {
    9
  } else if read_ahead {
    8
  } else {
    6
  }
  let issued_lines = b.register_state_in(fast, @wire.uint(line_bits), reset=fr)
  let returned_lines = b.register_state_in(
    fast,
    @wire.uint(line_bits),
    reset=fr,
  )
  let sent_words = b.register_state_in(fast, @wire.uint(word_bits), reset=fr)
  let batch_row = if batch && !read_ahead {
    Some(b.register_state_in(fast, @wire.uint(2), reset=fr))
  } else {
    None
  }
  let buffered = Array::makei(
    if sixteen_row {
      512
    } else if eight_row {
      256
    } else if read_ahead {
      128
    } else {
      32
    },
    _ => b.register_state_in(fast, @wire.uint(32), reset=fr),
  )
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
  let line_index = b.register_state_in(
    fast,
    @wire.uint(
      if sixteen_row {
        7
      } else if eight_row {
        6
      } else if batch {
        5
      } else {
        3
      },
    ),
    reset=fr,
  )
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
  let local_wide = if wide {
    Some(b.register_state_in(slow, @wire.bits(1), reset=sr))
  } else {
    None
  }
  let local_batch = if batch {
    Some(b.register_state_in(slow, @wire.bits(1), reset=sr))
  } else {
    None
  }
  let local_data = b.register_state_in(slow, @wire.uint(32), reset=sr)
  let local_fault = b.register_state_in(slow, @wire.uint(2), reset=sr)
  let receive_lane = b.register_state_in(
    slow,
    @wire.uint(
      if sixteen_row {
        9
      } else if eight_row {
        8
      } else if batch {
        7
      } else {
        5
      },
    ),
    reset=sr,
  )
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
      b.concat(
        b.concat(
          b.concat(
            if wide {
              request_wide.unwrap()
            } else {
              n(b, 1, 0UL)
            },
            burst,
          ),
          line_read,
        ),
        write,
      ),
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
  let native_wide = if wide {
    Some(b.bit_and(b.slice(request.value(), 63, 63), burst_read))
  } else {
    None
  }
  let native_batch = if batch {
    Some(b.bit_and(native_wide.unwrap(), b.slice(request.value(), 31, 31)))
  } else {
    None
  }
  let lane = u(b, b.slice(request.value(), 35, 34))
  let line_limit = if read_ahead {
    Some(
      b.mux(
        native_batch.unwrap(),
        n(
          b,
          line_bits,
          if sixteen_row {
            128UL
          } else if eight_row {
            64UL
          } else {
            32UL
          },
        ),
        n(b, line_bits, 8UL),
      ),
    )
  } else {
    None
  }
  let word_limit = if read_ahead {
    Some(
      b.mux(
        native_batch.unwrap(),
        n(
          b,
          word_bits,
          if sixteen_row {
            512UL
          } else if eight_row {
            256UL
          } else {
            128UL
          },
        ),
        n(b, word_bits, 32UL),
      ),
    )
  } else {
    None
  }
  let pipeline_command = both(b, [
    pipeline,
    healthy,
    b.less_than(
      issued_lines.value(),
      if read_ahead {
        line_limit.unwrap()
      } else {
        n(b, 4, 8UL)
      },
    ),
  ])
  let pipeline_fire = b.bit_and(pipeline_command, command_ready)
  let command = b.bit_or(
    pipeline_command,
    both(b, [sending, healthy, b.bit_not(command_sent.value())]),
  )
  let wdf = both(b, [sending, healthy, writing, b.bit_not(data_sent.value())])
  let command_fire = b.bit_and(command, command_ready)
  let data_fire = b.bit_and(wdf, data_ready)
  let command_done = b.bit_or(command_sent.value(), command_fire)
  let data_done = b.bit_or(data_sent.value(), data_fire)
  let owned_read = both(b, [
    b.bit_not(writing),
    any(b, [waiting, b.bit_and(sending, command_done)]),
  ])
  let pipeline_owned = both(b, [
    pipeline,
    b.bit_or(
      b.less_than(returned_lines.value(), issued_lines.value()),
      pipeline_fire,
    ),
  ])
  let bad_read = b.bit_and(
    read_valid,
    b.bit_not(b.bit_and(b.bit_or(owned_read, pipeline_owned), read_end)),
  )
  let calibration_lost = both(b, [
    calibrated_once.value(),
    b.bit_not(calibrated),
  ])
  let poison_now = b.bit_or(bad_read, calibration_lost)
  let read_fire = both(b, [read_valid, read_end, owned_read, healthy])
  let written = both(b, [sending, healthy, writing, command_done, data_done])
  let pipeline_return = both(b, [read_valid, read_end, pipeline_owned, healthy])
  if !batch || read_ahead {
    increment(b, issued_lines, accept, pipeline_fire, n(b, line_bits, 1UL))
    increment(b, returned_lines, accept, pipeline_return, n(b, line_bits, 1UL))
  }
  for i, r in buffered {
    update(
      b,
      r,
      both(b, [
        pipeline_return,
        eq(b, returned_lines.value(), (i / 4).to_uint64()),
      ]),
      words[i % 4],
    )
  }
  let pipeline_failed = b.bit_or(b.bit_not(healthy), poison_now)
  let available = both(b, [
    pipeline,
    b.less_than(
      sent_words.value(),
      if read_ahead {
        word_limit.unwrap()
      } else {
        n(b, 6, 32UL)
      },
    ),
    b.bit_or(
      pipeline_failed,
      if delivery {
        b.less_equal(
          b.add(
            sent_words.value(),
            b.mux(
              native_wide.unwrap(),
              n(b, word_bits, 8UL),
              n(b, word_bits, 1UL),
            ),
          ),
          u(b, b.concat(returned_lines.value(), n(b, 2, 0UL))),
        )
      } else {
        b.less_than(
          sent_words.value(),
          u(b, b.concat(returned_lines.value(), n(b, 2, 0UL))),
        )
      },
    ),
  ])
  let emit_valid = b.register_state_in(fast, @wire.bits(1), reset=fr)
  let emit_data = b.register_state_in(fast, @wire.uint(32), reset=fr)
  let emit_extra = if wide {
    Array::makei(if delivery { 7 } else { 3 }, _ => {
      b.register_state_in(fast, @wire.uint(32), reset=fr)
    })
  } else {
    []
  }
  let emit_fault = b.register_state_in(fast, @wire.uint(2), reset=fr)
  let pipeline_valid = emit_valid.value()
  let pipeline_fault = emit_fault.value()
  let pipeline_data = emit_data.value()
  let response_valid = b.bit_or(replying, pipeline_valid)
  let response_head = u(
    b,
    b.concat(
      b.mux(pipeline, pipeline_fault, fault.value()),
      b.mux(
        pipeline,
        pipeline_data,
        table(b, reply_lane.value(), results.map(r => r.value())),
      ),
    ),
  )
  let response_extra = emit_extra.map(r => {
    b.mux(pipeline, r.value(), n(b, 32, 0UL))
  })
  let response_ready = both(b, [
    local_wait,
    b.bit_or(b.bit_not(local_line.value()), ready),
  ])
  let responses = response_fifo(
    b,
    fast,
    slow,
    response_valid,
    response_head,
    response_extra,
    response_ready,
    fr,
    sr,
    streaming~,
    staggered~,
  )
  let pipeline_sent = b.bit_and(pipeline_valid, responses.ready)
  let emit_load = both(b, [
    available,
    b.bit_or(b.bit_not(pipeline_valid), pipeline_sent),
  ])
  if !batch || read_ahead {
    increment(
      b,
      sent_words,
      accept,
      emit_load,
      if wide {
        b.mux(
          native_wide.unwrap(),
          n(b, word_bits, if delivery { 8UL } else { 4UL }),
          n(b, word_bits, 1UL),
        )
      } else {
        n(b, word_bits, 1UL)
      },
    )
  }
  b.connect_next(
    emit_valid,
    b.mux(
      emit_load,
      n(b, 1, 1UL),
      b.mux(pipeline_sent, n(b, 1, 0UL), emit_valid.value()),
    ),
  )
  update(
    b,
    emit_data,
    emit_load,
    b.mux(
      pipeline_failed,
      n(b, 32, 0UL),
      if delivery {
        b.mux(
          native_wide.unwrap(),
          delivery_word(b, sent_words.value(), buffered.map(r => r.value()), 0),
          read_ahead_word(b, sent_words.value(), buffered.map(r => r.value())),
        )
      } else if read_ahead {
        read_ahead_word(b, sent_words.value(), buffered.map(r => r.value()))
      } else {
        table(b, sent_words.value(), buffered.map(r => r.value()))
      },
    ),
  )
  update(
    b,
    emit_fault,
    emit_load,
    b.mux(
      pipeline_failed,
      b.mux(calibration_lost, n(b, 2, 2UL), n(b, 2, 3UL)),
      n(b, 2, 0UL),
    ),
  )
  for i, r in emit_extra {
    update(
      b,
      r,
      emit_load,
      b.mux(
        b.bit_or(pipeline_failed, b.bit_not(native_wide.unwrap())),
        n(b, 32, 0UL),
        if delivery {
          delivery_word(
            b,
            sent_words.value(),
            buffered.map(r => r.value()),
            i + 1,
          )
        } else if read_ahead {
          read_ahead_word(
            b,
            b.add(sent_words.value(), n(b, word_bits, (i + 1).to_uint64())),
            buffered.map(r => r.value()),
          )
        } else {
          table(
            b,
            b.add(sent_words.value(), n(b, word_bits, (i + 1).to_uint64())),
            buffered.map(r => r.value()),
          )
        },
      ),
    )
  }
  let pipeline_done = both(b, [
    pipeline_sent,
    if read_ahead {
      b.equal(sent_words.value(), word_limit.unwrap())
    } else {
      eq(b, sent_words.value(), 32UL)
    },
  ])
  let advance_row = if batch {
    Some(
      if read_ahead {
        n(b, 1, 0UL)
      } else {
        both(b, [
          pipeline_done,
          native_batch.unwrap(),
          b.bit_not(eq(b, batch_row.unwrap().value(), 3UL)),
        ])
      },
    )
  } else {
    None
  }
  if batch && !read_ahead {
    let restart = b.bit_or(accept, advance_row.unwrap())
    increment(b, issued_lines, restart, pipeline_fire, n(b, 4, 1UL))
    increment(b, returned_lines, restart, pipeline_return, n(b, 4, 1UL))
    increment(
      b,
      sent_words,
      restart,
      emit_load,
      b.mux(native_wide.unwrap(), n(b, 6, 4UL), n(b, 6, 1UL)),
    )
  }
  if batch_row is Some(r) {
    increment(b, r, accept, advance_row.unwrap(), n(b, 2, 1UL))
  }
  let pipeline_finished = if batch {
    b.bit_and(pipeline_done, b.bit_not(advance_row.unwrap()))
  } else {
    pipeline_done
  }
  let flit_sent = b.bit_and(replying, responses.ready)
  let replied = both(b, [
    flit_sent,
    if wide {
      any(b, [writing, native_wide.unwrap(), eq(b, reply_lane.value(), 3UL)])
    } else {
      b.bit_or(writing, eq(b, reply_lane.value(), 3UL))
    },
  ])
  let reply_last_line = if batch {
    b.mux(
      native_batch.unwrap(),
      n(
        b,
        if sixteen_row {
          7
        } else if eight_row {
          6
        } else {
          5
        },
        if sixteen_row {
          127UL
        } else if eight_row {
          63UL
        } else {
          31UL
        },
      ),
      n(b, if sixteen_row { 7 } else if eight_row { 6 } else { 5 }, 7UL),
    )
  } else {
    n(b, 3, 7UL)
  }
  // Rejected wide reads use the serial fault path. Each delivery packet still
  // owns two native lines, so its last starting line is one below the old
  // four-word limit. Otherwise surplus fault packets can reach the next owner.
  let reply_last_line = if delivery {
    b.sub(
      reply_last_line,
      b.zero_extend(
        b.reinterpret(native_wide.unwrap(), @wire.uint(1)),
        line_index.value().signal_type().width().bits(),
      ),
    )
  } else {
    reply_last_line
  }
  let continue_read = both(b, [
    replied,
    burst_read,
    b.bit_not(b.equal(line_index.value(), reply_last_line)),
  ])
  let fail_continue = both(b, [
    continue_read,
    b.bit_or(b.bit_not(healthy), poison_now),
  ])
  increment(
    b,
    line_index,
    accept,
    continue_read,
    if delivery {
      b.mux(native_wide.unwrap(), n(b, 7, 2UL), n(b, 7, 1UL))
    } else {
      n(
        b,
        if sixteen_row {
          7
        } else if eight_row {
          6
        } else if batch {
          5
        } else {
          3
        },
        1UL,
      )
    },
  )
  increment(b, reply_lane, accept, flit_sent, n(b, 2, 1UL))
  let invalid_address = invalid_request_address(
    b,
    received,
    wide,
    batch,
    eight_row~,
    sixteen_row~,
    aligned_extent~,
  )
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
        b.mux(
          refused,
          n(b, 3, 3UL),
          b.mux(
            both(b, [
              b.slice(received, 62, 62),
              b.slice(received, 61, 61),
              b.bit_not(b.slice(received, 60, 60)),
            ]),
            n(b, 3, 5UL),
            n(b, 3, 1UL),
          ),
        ),
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
            b.bit_or(replied, pipeline_finished),
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
  let response = responses.data[0]
  let stream_valid = both(b, [local_wait, local_line.value(), responses.valid])
  let returned = both(b, [
    local_wait,
    responses.valid,
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
        source_last(
          b,
          local_burst,
          local_wide,
          batch=local_batch,
          eight_row~,
          sixteen_row~,
          delivery~,
        ),
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
  increment(
    b,
    receive_lane,
    source_accept,
    returned,
    if wide {
      b.mux(
        local_wide.unwrap().value(),
        n(
          b,
          if sixteen_row {
            9
          } else if eight_row {
            8
          } else if batch {
            7
          } else {
            5
          },
          if delivery {
            8UL
          } else {
            4UL
          },
        ),
        n(
          b,
          if sixteen_row {
            9
          } else if eight_row {
            8
          } else if batch {
            7
          } else {
            5
          },
          1UL,
        ),
      )
    } else {
      n(b, 5, 1UL)
    },
  )
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
        b.zero_extend(
          u(b, b.slice(local_address.value(), 3, 2)),
          if sixteen_row {
            9
          } else if eight_row {
            8
          } else if batch {
            7
          } else {
            5
          },
        ),
      ),
    ),
  ])
  if local_batch is Some(r) {
    update(
      b,
      r,
      source_accept,
      both(b, [
        request_wide.unwrap(),
        burst,
        line_read,
        b.bit_not(write),
        b.slice(data, 31, 31),
      ]),
    )
  }
  if local_wide is Some(r) {
    update(
      b,
      r,
      source_accept,
      both(b, [request_wide.unwrap(), burst, line_read, b.bit_not(write)]),
    )
    for i in 1..<(if delivery { 8 } else { 4 }) {
      out_in(
        b,
        slow,
        "response_data" + i.to_string(),
        b.mux(r.value(), responses.data[i], n(b, 32, 0UL)),
      )
    }
  }
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
        source_last(
          b,
          local_burst,
          local_wide,
          batch=local_batch,
          eight_row~,
          sixteen_row~,
          delivery~,
        ),
      ),
    ),
  )
  out_in(b, slow, "memory_healthy", safe)
  let native_line_index = b.mux(
    pipeline,
    if batch {
      b.zero_extend(
        b.truncate(issued_lines.value(), 3),
        if sixteen_row {
          7
        } else if eight_row {
          6
        } else {
          5
        },
      )
    } else {
      b.truncate(issued_lines.value(), 3)
    },
    line_index.value(),
  )
  let ahead_offset = if read_ahead {
    Some(
      read_ahead_offset(
        b,
        fast,
        fr,
        request.value(),
        accept,
        pipeline_fire,
        issued_lines.value(),
      ),
    )
  } else {
    None
  }
  bridge_native_outputs(
    b,
    fast,
    request.value(),
    native_line_index,
    command,
    wdf,
    writing,
    full_write,
    lane,
    write_word,
    collected,
    state.value(),
    poisoned.value(),
    row_offset=if read_ahead {
      ahead_offset
    } else if batch {
      Some(batch_native_offset(b, request.value(), batch_row.unwrap().value()))
    } else {
      None
    },
  )
  let hw = b.finish()
  for
    (name, signal) in [
      ("state", state.value()),
      ("request", request.value()),
      ("source_state", source_state.value()),
      ("source_accept", source_accept),
      ("source_line", local_line.value()),
      ("source_burst", local_burst.value()),
      ("receive_lane", receive_lane.value()),
      ("cache_valid", cached.value()),
      ("cache_hit", hit),
      ("install", install),
      ("calibrated_once", calibrated_once.value()),
      ("issued_lines", issued_lines.value()),
      ("returned_lines", returned_lines.value()),
      ("sent_words", sent_words.value()),
      ("pipeline_valid", pipeline_valid),
      ("pipeline_data", pipeline_data),
      ("pipeline_fault", pipeline_fault),
      ("pipeline_ready", responses.ready),
      ("pipeline_return", pipeline_return),
      ("pipeline_load", emit_load),
      ("pipeline_failed", pipeline_failed),
      ("line_index", native_line_index),
    ] {
    observations.push({ name, node: signal.id(), })
  }
  observe_batch(observations, batch_row, advance_row)
  if read_ahead {
    observations.push({
      name: "read_ahead_offset",
      node: ahead_offset.unwrap().id(),
    })
  }
  if streaming {
    let mut lane = 0
    for primitive in hw.cdc_primitives() {
      if primitive is AsyncFifo(f) &&
        (f.name() == "word_responses" || f.name().has_prefix("wide_response_")) {
        for
          (role, node) in [
            ("source_ready", f.source_ready()),
            ("source_valid", f.source_valid()),
            ("source_transfer", f.source_transfer()),
            ("destination_valid", f.destination_valid()),
            ("destination_ready", f.destination_ready()),
            ("destination_transfer", f.destination_transfer()),
            ("write_binary", f.write_binary()),
            ("read_binary", f.read_binary()),
          ] {
          observations.push({
            name: "join_" + lane.to_string() + "_" + role,
            node,
          })
        }
        lane += 1
      }
    }
    assert_eq(lane, if delivery { 16 } else { 8 })
  }
  hw
}
