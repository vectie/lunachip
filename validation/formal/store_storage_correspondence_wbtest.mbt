///|
test "finite original Store storage correspondence covers pregrant opposite capture held offers whole writes and reset" {
  let scenario = store_scenario_prepare()
  let source = scenario.source
  let observer = scenario.observer
  let old_a = [2, 3, 4, 5]
  let old_b = [7, 11, 13, 17]
  let fresh_a = [-2, 6, 9, -4]
  let fresh_b = [5, -3, 8, 7]
  let old = @flux_tile.matmul_int8_oracle(
    old_a,
    old_b,
    rows=2,
    columns=2,
    reduction=2,
  )
  let fresh = @flux_tile.matmul_int8_oracle(
    fresh_a,
    fresh_b,
    rows=2,
    columns=2,
    reduction=2,
  )
  assert_eq(old, [53, 73, 93, 129])
  assert_eq(fresh, [38, 48, 13, -55])
  store_scenario_seed(scenario, 32, 3, old_a)
  store_scenario_seed(scenario, 64, 5, old_b)
  store_scenario_seed(scenario, 128, 3, fresh_a)
  store_scenario_seed(scenario, 160, 5, fresh_b)
  scenario.memory[256] = 42UL
  let expected = scenario.memory.copy()
  store_scenario_expected_words(expected, 512, 16, old)
  store_scenario_expected_words(expected, 640, 20, fresh)
  // The real production device computes both matrices. The projection sees
  // only the actual raw accumulator values, not these host-side oracle values.
  store_scenario_command(
    scenario,
    store_scenario_packet(0UL, rows=2, columns=2, base=32, stride=3),
    4UL,
  )
  store_scenario_command(
    scenario,
    store_scenario_packet(1UL, rows=2, columns=2, base=64, stride=5),
    4UL,
  )
  store_scenario_command(
    scenario,
    store_scenario_packet(2UL, rows=2, columns=2, reduction=2),
    0UL,
  )
  store_correspondence_c_words(observer, source, 0, old)
  store_scenario_command(
    scenario,
    store_scenario_packet(0UL, rows=2, columns=2, base=128, stride=3, a=1),
    4UL,
  )
  store_scenario_command(
    scenario,
    store_scenario_packet(1UL, rows=2, columns=2, base=160, stride=5, b=1),
    4UL,
  )
  assert_eq(scenario.pending, None)
  assert_eq(scenario.read_acks, 16)
  assert_eq(scenario.requests.length(), 16)
  // Admit genuine Loader work and delay only its external response. C0 is
  // already published, and the opposite A1/B1 operands are already loaded.
  scenario.latency = 200
  store_scenario_admit(
    scenario,
    store_scenario_packet(0UL, rows=1, columns=1, base=256, stride=1),
  )
  for _ in 0..<128 {
    if scenario.pending is Some(_) {
      break
    }
    store_scenario_tick(scenario)
  }
  guard scenario.pending is Some(delayed) &&
    scenario.pending_request is Some(loader_request) else {
    fail("real Loader must own an accepted outstanding host transaction")
  }
  assert_true(delayed.delay >= 190)
  assert_eq(loader_request, [0UL, 256UL, 1UL, 1UL, 0UL, 16UL])
  assert_eq(store_correspondence_arbiter(observer, source, "state"), 2UL)
  assert_eq(store_correspondence_arbiter(observer, source, "owner"), 0UL)
  store_scenario_admit(
    scenario,
    store_scenario_packet(3UL, rows=2, columns=2, base=512, stride=16),
  )
  let mut read_accepts_under_loader = 0
  for _ in 0..<128 {
    if store_correspondence_observe(observer, source, SlottedRegister(Pending)) ==
      1UL &&
      store_correspondence_observe(observer, source, StoreRegister(State)) ==
      2UL {
      break
    }
    assert_true(scenario.pending is Some(response) && response.delay > 0)
    assert_eq(store_correspondence_arbiter(observer, source, "state"), 2UL)
    assert_eq(store_correspondence_arbiter(observer, source, "owner"), 0UL)
    read_accepts_under_loader += store_correspondence_observe(
      observer,
      source,
      Event(ReadAccept),
    ).to_int()
    store_scenario_tick(scenario)
  }
  assert_eq(read_accepts_under_loader, 1)
  assert_eq(
    store_correspondence_observe(observer, source, SlottedRegister(Pending)),
    1UL,
  )
  assert_eq(
    store_correspondence_observe(
      observer,
      source,
      SlottedRegister(ResponseSlot),
    ),
    0UL,
  )
  assert_eq(
    store_correspondence_observe(observer, source, Event(ResponseData)),
    53UL,
  )
  assert_eq(
    store_correspondence_observe(observer, source, Event(StoreRequestAccept)),
    0UL,
  )
  assert_eq(
    store_correspondence_observe(observer, source, Event(StoreRequestValid)),
    1UL,
  )
  assert_eq(observer.captures[1], 0)
  // Opposite-C1 admission is legal even while the older C0 indexed response
  // remains pending. Count the actual inner accept and every capture PRE.
  store_scenario_admit(
    scenario,
    store_scenario_packet(2UL, rows=2, columns=2, reduction=2, a=1, b=1, c=1),
  )
  let mut inner_accepts_under_loader = 0
  let mut captures_under_loader = 0
  let mut final_captures_under_loader = 0
  for _ in 0..<128 {
    if observer.captures[1] == 4 {
      break
    }
    assert_true(scenario.pending is Some(response) && response.delay > 0)
    assert_eq(scenario.pending_request, Some(loader_request))
    assert_eq(scenario.requests.length(), 17)
    assert_eq(store_correspondence_arbiter(observer, source, "state"), 2UL)
    assert_eq(store_correspondence_arbiter(observer, source, "owner"), 0UL)
    assert_eq(
      store_correspondence_observe(observer, source, StoreRegister(State)),
      2UL,
    )
    assert_eq(
      store_correspondence_observe(observer, source, StoreRegister(Slot)),
      0UL,
    )
    assert_eq(
      store_correspondence_observe(observer, source, SlottedRegister(Pending)),
      1UL,
    )
    assert_eq(
      store_correspondence_observe(
        observer,
        source,
        SlottedRegister(ResponseSlot),
      ),
      0UL,
    )
    assert_eq(
      store_correspondence_observe(observer, source, Event(ResponseData)),
      53UL,
    )
    assert_eq(
      store_correspondence_observe(observer, source, Event(StoreRequestAccept)),
      0UL,
    )
    assert_eq(records_output(source, "memory_request_valid"), 0UL)
    if store_correspondence_observe(observer, source, Event(SlottedAccept)) ==
      1UL {
      assert_eq(
        store_correspondence_observe(
          observer,
          source,
          Event(SlottedLegalAccept),
        ),
        1UL,
      )
      assert_eq(
        store_correspondence_observe(observer, source, ComputeRegister(C)),
        1UL,
      )
      inner_accepts_under_loader += 1
    }
    if store_correspondence_observe(observer, source, Event(Capture)) == 1UL {
      assert_eq(
        store_correspondence_observe(observer, source, SlottedRegister(ActiveC)),
        1UL,
      )
      captures_under_loader += 1
      final_captures_under_loader += store_correspondence_observe(
        observer,
        source,
        Event(FinalCapture),
      ).to_int()
    }
    store_correspondence_c_words(observer, source, 0, old)
    store_scenario_tick(scenario)
  }
  assert_eq(inner_accepts_under_loader, 1)
  assert_eq(captures_under_loader, 4)
  assert_eq(final_captures_under_loader, 1)
  assert_eq(observer.captures, [4, 4])
  assert_eq(observer.final_captures, [1, 1])
  assert_eq(store_correspondence_observe(observer, source, ResultValid(1)), 1UL)
  store_correspondence_c_words(observer, source, 0, old)
  store_correspondence_c_words(observer, source, 1, fresh)
  // Loader's actual matching successful ACK occurs before any Store grant.
  // Disable only external request acceptance before releasing that response.
  scenario.request_ready = 0UL
  for _ in 0..<256 {
    if scenario.pending is None {
      break
    }
    assert_eq(records_output(source, "memory_request_valid"), 0UL)
    store_scenario_tick(scenario)
  }
  assert_eq(scenario.pending, None)
  assert_eq(scenario.pending_request, None)
  assert_eq(scenario.read_acks, 17)
  for _ in 0..<128 {
    if records_output(source, "memory_request_valid") == 1UL {
      break
    }
    store_scenario_tick(scenario)
  }
  assert_eq(records_output(source, "memory_request_valid"), 1UL)
  let held = store_scenario_request(source)
  assert_eq(held, [1UL, 512UL, 4UL, 15UL, 53UL, 17UL])
  let mut held_offer_edges = 0
  for _ in 0..<3 {
    assert_eq(store_correspondence_arbiter(observer, source, "state"), 1UL)
    assert_eq(store_correspondence_arbiter(observer, source, "owner"), 1UL)
    assert_eq(records_output(source, "memory_request_valid"), 1UL)
    assert_eq(store_scenario_request(source), held)
    assert_eq(scenario.pending, None)
    assert_eq(scenario.requests.length(), 17)
    store_scenario_tick(scenario)
    held_offer_edges += 1
  }
  assert_eq(held_offer_edges, 3)
  assert_eq(store_scenario_request(source), held)
  scenario.latency = 2
  scenario.request_ready = 1UL
  store_scenario_wait_completions(scenario, 8)
  assert_eq(scenario.completions[5], [73UL, 0UL, 1UL, 0UL])
  assert_eq(scenario.completions[6], [73UL, 0UL, 16UL, 0UL])
  assert_eq(scenario.completions[7], [73UL, 0UL, 0UL, 0UL])
  store_scenario_command(
    scenario,
    store_scenario_packet(3UL, rows=2, columns=2, base=640, stride=20, c=1),
    16UL,
  )
  assert_eq(scenario.requests.length(), 25)
  assert_eq(scenario.write_acks, 8)
  assert_eq(scenario.read_acks, 17)
  assert_eq(scenario.admissions, 9)
  assert_eq(observer.compute_accepts, 2)
  assert_eq(observer.store_accepts, 2)
  // Verify every actual indexed write, including row-stride transitions and
  // the signed final C1 word. The whole image detects writes outside results.
  for index in 0..<8 {
    let word = index % 4
    let address = if index < 4 {
      512 + word / 2 * 16 + word % 2 * 4
    } else {
      640 + word / 2 * 20 + word % 2 * 4
    }
    let value = if index < 4 { old[word] } else { fresh[word] }
    assert_eq(scenario.requests[17 + index], [
      1UL,
      address.to_uint64(),
      4UL,
      15UL,
      value.to_int64().reinterpret_as_uint64() & 0xffffffffUL,
      (17 + index).to_uint64(),
    ])
  }
  assert_eq(scenario.memory, expected)
  // Reach a fresh real Store offer, then reset before any external write.
  // Both C SRAMs and every reached FIFO SRAM/read state must survive exactly.
  scenario.request_ready = 0UL
  records_put(source, "completion_ready", 1, 0UL)
  store_scenario_admit(
    scenario,
    store_scenario_packet(3UL, rows=2, columns=2, base=768, stride=24),
  )
  for _ in 0..<128 {
    if records_output(source, "memory_request_valid") == 1UL {
      break
    }
    store_scenario_tick(scenario)
  }
  assert_eq(records_output(source, "memory_request_valid"), 1UL)
  assert_eq(store_scenario_request(source), [1UL, 768UL, 4UL, 15UL, 53UL, 25UL])
  assert_eq(store_correspondence_arbiter(observer, source, "state"), 1UL)
  assert_eq(store_correspondence_arbiter(observer, source, "owner"), 1UL)
  assert_eq(
    store_correspondence_observe(observer, source, StoreRegister(State)),
    2UL,
  )
  let cells_before_reset = store_correspondence_cells(observer, source)
  let reads_before_reset = store_correspondence_reads(observer, source)
  assert_true(cells_before_reset.any(value => value.is_fully_known()))
  assert_true(reads_before_reset.any(value => value.is_fully_known()))
  store_correspondence_c_words(observer, source, 0, old)
  store_correspondence_c_words(observer, source, 1, fresh)
  assert_eq(observer.store_accepts, 3)
  records_present(source, None)
  records_put(source, "reset", 1, 1UL)
  scenario.held = None
  assert_eq(scenario.pending, None)
  assert_eq(scenario.pending_request, None)
  store_scenario_tick(scenario)
  assert_eq(store_correspondence_cells(observer, source), cells_before_reset)
  assert_eq(store_correspondence_reads(observer, source), reads_before_reset)
  assert_eq(scenario.memory, expected)
  for node in observer.slice.plan.selected {
    if node.kind() is Register(_) &&
      !observer.slice.plan.arithmetic.any(cut => cut.id() == node.id()) {
      assert_eq(
        source.value(node.id()),
        @wave.LogicValue::zero(width=node.signal_type().width().bits()),
      )
    }
  }
  assert_eq(store_correspondence_observe(observer, source, ResultValid(0)), 0UL)
  assert_eq(store_correspondence_observe(observer, source, ResultValid(1)), 0UL)
  records_put(source, "reset", 1, 0UL)
  scenario.next_tag = 0UL
  scenario.request_ready = 1UL
  records_put(source, "completion_ready", 1, 1UL)
  store_scenario_tick(scenario)
  assert_eq(store_correspondence_cells(observer, source), cells_before_reset)
  assert_eq(store_correspondence_reads(observer, source), reads_before_reset)
  assert_eq(records_output(source, "completion_valid"), 0UL)
  store_scenario_command(scenario, store_scenario_packet(4UL), 0UL)
  assert_eq(scenario.admissions, 11)
  assert_eq(scenario.completions.length(), 10)
  assert_eq(scenario.requests.length(), 25)
  assert_eq(scenario.write_acks, 8)
  assert_eq(scenario.memory, expected)
  assert_eq(observer.reset_edges, 2)
  assert_eq(observer.pre_samples, observer.post_samples)
  assert_true(observer.pre_samples > 0)
  assert_true(observer.unknown_registers > 0)
  assert_true(observer.unknown_arithmetic > 0)
  assert_true(observer.unknown_reads > 0)
  assert_true(observer.unknown_cells > 0)
  println(
    "FINITE-STORE-CORRESPONDENCE PRE \{observer.pre_samples} POST \{observer.post_samples} resets \{observer.reset_edges} admissions \{scenario.admissions} retirements \{scenario.completions.length()} read-ACKs \{scenario.read_acks} write-ACKs \{scenario.write_acks} held-offers \{held_offer_edges} pregrant-inner-accepts \{inner_accepts_under_loader} pregrant-captures \{captures_under_loader} pregrant-final-captures \{final_captures_under_loader}",
  )
  println(
    "FINITE-STORE-CORRESPONDENCE unknown-register-samples \{observer.unknown_registers} unknown-arithmetic-samples \{observer.unknown_arithmetic} unknown-read-samples \{observer.unknown_reads} unknown-cell-samples \{observer.unknown_cells} retained-reset-cells \{cells_before_reset.length()} retained-reset-read-states \{reads_before_reset.length()}",
  )
}
