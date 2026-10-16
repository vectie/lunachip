///|
fn direct8_fair_idle_edge(completion_valid? : Bool = false) -> Direct8FairEdge {
  {
    reset: false,
    descriptor_valid: false,
    descriptor_ready: false,
    packet: [0UL, 0UL, 0UL, 0UL],
    request_valid: false,
    request_ready: true,
    request: [0UL, 0UL, 0UL, 0UL, 0UL, 0UL],
    response_valid: false,
    response_ready: false,
    response: [0UL, 0UL, 0UL],
    completion_valid,
    completion_ready: true,
    completion: [73UL, 0UL, 0UL, 0UL],
  }
}

///|
fn direct8_fair_expect(
  model : Direct8FairNative,
  edge : Direct8FairEdge,
  expected : String,
) -> Unit raise {
  try model.check(edge) catch {
    BadFairEdge(label) => assert_eq(label, expected)
    other => fail("unexpected fairness diagnostic: \{other}")
  } noraise {
    _ => fail("missing fairness diagnostic: " + expected)
  }
}

///|
test "direct8 fair response availability is independent of DUT readiness and preserves full tags" {
  let model = Direct8FairNative::new()
  model.seen = true
  model.owner = Some([0UL, 0xffffffffUL, 1UL, 0UL, 0UL, 0x80000001UL])
  model.response_age = 2
  let edge = direct8_fair_idle_edge()
  edge.response_valid = true
  edge.response[0] = 0x80000001UL
  edge.response[2] = 0xffffffffUL
  // The environment satisfies H2 even if a broken DUT refuses the offer.
  model.host(edge)
  direct8_fair_expect(model, edge, "dc_response_readiness")
  edge.response_ready = true
  model.check(edge)
  edge.response[0] = edge.response[0] ^ 0x80000000UL
  direct8_fair_expect(model, edge, "dc_host_owned_success_response")
  edge.response[0] = edge.response[0] ^ 0x80000000UL
  edge.response_valid = false
  edge.response_ready = false
  direct8_fair_expect(model, edge, "dc_host_response_offer_h2")
  model.response_age = 1
  model.response_hold = Some(edge.response.copy())
  direct8_fair_expect(model, edge, "dc_host_response_stable")
  model.response_hold = None
  model.owner = None
  model.request_hold = Some([0UL, 0UL, 1UL, 0UL, 0UL, 0UL])
  model.host(edge)
  direct8_fair_expect(model, edge, "dc_request_stable")
  edge.request_ready = false
  direct8_fair_expect(model, edge, "dc_host_request_ready_r2")
  model.request_hold = None
  model.completion_hold = Some([73UL, 0UL, 0UL, 0UL])
  edge.completion_ready = false
  direct8_fair_expect(model, edge, "dc_host_completion_ready_c2")
}

///|
test "direct8 ordinal retirement does not confuse repeated IDs and ACK wins at exact deadline" {
  let model = Direct8FairNative::new()
  model.seen = true
  model.taken = true
  model.active = true
  model.outstanding = 2
  model.older = 1
  model.age = 10
  model.saved_packet = direct8_completion_packet(3)
  let edge = direct8_fair_idle_edge(completion_valid=true)
  model.step(edge, false)
  assert_true(model.active)
  assert_eq(
    (model.older, model.outstanding, model.watch_retire_age),
    (0, 1, None),
  )
  model.age = 11718
  edge.completion_ready = false
  direct8_fair_expect(model, edge, "dc_watched_retirement_deadline")
  edge.completion_ready = true
  model.step(edge, false)
  assert_false(model.active)
  assert_eq(model.watch_retire_age, Some(11718))
  assert_eq((model.outstanding, model.retired), (0, 2))
}

///|
test "direct8 actual 8x8 K16 pipeline completes under explicit R2 H2 C2 with both slots and repeated IDs" {
  for slot in 0..<2 {
    let packets = Array::makei(4, index => direct8_completion_packet(index))
    if slot == 1 {
      for
        (index, selectors) in [(0, 1UL), (1, 256UL), (2, 65793UL), (3, 65536UL)] {
        packets[index][3] = selectors
      }
    }
    let model = direct8_fair_native_run(
      packets,
      [0UL, 0UL, 0UL, 0UL],
      if slot == 0 {
        0
      } else {
        3
      },
      256,
      64,
    )
    assert_true(model.request_stall_seen)
    assert_true(model.completion_stall_seen)
    if slot == 0 {
      assert_true(model.negative_seen)
    } else {
      assert_true(model.older_seen)
    }
  }
}

///|
test "direct8 full high address preflight faults still retire under fair peers without RAM initialization" {
  let packets = [
    direct8_completion_packet(0),
    direct8_completion_packet(2),
    direct8_completion_packet(3),
  ]
  packets[0][2] = (16UL << 32) | 0xffffffffUL
  let model = direct8_fair_native_run(packets, [8UL, 4UL, 5UL], 2, 0, 0)
  assert_true(model.older_seen)
}
