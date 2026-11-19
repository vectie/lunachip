///|
priv struct Direct8PayloadNative {
  mut reads : Int32
  mut pending_frames : Int32
  mut request_frames : Int32
  mut slots : UInt64
}

///|
fn Direct8PayloadNative::new() -> Direct8PayloadNative {
  { reads: 0, pending_frames: 0, request_frames: 0, slots: 0UL, }
}

///|
fn Direct8PayloadNative::step(
  self : Direct8PayloadNative,
  read : (String) -> UInt64 raise,
) -> Unit raise {
  if read("i_reset") == 1UL {
    return
  }
  let state = read("q_engine_state_2")
  if state >= 1UL && state <= 3UL {
    let slot = read("o_store_slot")
    direct8_fair_require(
      read("p_c_valid_\{slot}") == 1UL &&
      read("p_c_rows_\{slot}") == read("t_engine_rows") &&
      read("p_c_columns_\{slot}") == read("t_engine_columns"),
      "d8p_store_shape",
    )
    self.slots = self.slots | (1UL << slot.to_int())
    if state == 2UL {
      self.request_frames += 1
    }
  }
  if read("o_pending") == 1UL {
    direct8_fair_require(
      read("p_response_id") == read("p_store_id"),
      "d8p_pending_identity",
    )
    direct8_fair_require(read("p_response_fault") == 0UL, "d8p_pending_status")
    self.pending_frames += 1
  }
  if read("o_read_accept") == 1UL {
    direct8_fair_require(read("p_read_fault") == 0UL, "d8p_pending_status")
    self.reads += 1
  }
}

///|
test "pending payload metadata holds on competing two-slot pipelines and preflight rejection" {
  let packets = Array::makei(8, index => direct8_completion_packet(index % 4))
  for (index, selectors) in [(4, 1UL), (5, 256UL), (6, 65793UL), (7, 65536UL)] {
    packets[index][3] = selectors
  }
  let observer = Direct8PayloadNative::new()
  ignore(
    direct8_fair_native_run(
      packets,
      Array::make(8, 0UL),
      3,
      512,
      128,
      require_competing=true,
      observe_engines=true,
      observe_latency=true,
      observe_done=true,
      payload_observer=observer,
    ),
  )
  assert_eq((observer.reads, observer.slots), (128, 3UL))
  assert_true(observer.pending_frames >= 128 && observer.request_frames >= 128)
  let rejected = Direct8PayloadNative::new()
  ignore(
    direct8_fair_native_run(
      [direct8_completion_packet(3)],
      [5UL],
      0,
      0,
      0,
      payload_observer=rejected,
    ),
  )
  assert_eq(
    (rejected.reads, rejected.pending_frames, rejected.slots),
    (0, 0, 0UL),
  )
}

///|
test "payload algebra rejects high ID bits bad status and full-width metadata mismatch" {
  // Abstract observer controls, not solver traces or reachable counterexamples.
  for slot in 0..<=1 {
    for mutation in 0..<5 {
      let frame : Map[String, UInt64] = {
        "q_engine_state_2": 2UL,
        "o_store_slot": slot.to_uint64(),
        "t_engine_rows": 8UL,
        "t_engine_columns": 8UL,
        "o_pending": 1UL,
        "p_response_id": 0x80000049UL,
        "p_store_id": 0x80000049UL,
      }
      frame["p_c_valid_\{slot}"] = 1UL
      frame["p_c_rows_\{slot}"] = 8UL
      frame["p_c_columns_\{slot}"] = 8UL
      let observer = Direct8PayloadNative::new()
      let read : (String) -> UInt64 raise = name => {
        frame.get(name).unwrap_or(0UL)
      }
      observer.step(read)
      match mutation {
        0 => frame["p_response_id"] = 73UL
        1 => frame["p_response_fault"] = 1UL
        2 => {
          frame["q_engine_state_2"] = 1UL
          frame["o_pending"] = 0UL
          frame["o_read_accept"] = 1UL
          frame["p_read_fault"] = 2UL
        }
        3 => frame["p_c_valid_\{slot}"] = 0UL
        _ => frame["t_engine_rows"] = 4104UL
      }
      try observer.step(read) catch {
        BadFairEdge(label) =>
          assert_eq(
            label,
            if mutation == 0 {
              "d8p_pending_identity"
            } else if mutation <= 2 {
              "d8p_pending_status"
            } else {
              "d8p_store_shape"
            },
          )
        error => fail("unexpected payload observer failure: \{error}")
      } noraise {
        _ => fail("corrupted original metadata must fail")
      }
    }
  }
}
