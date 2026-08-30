///|
test "coordinated reset and two through four stage latency are exact" {
  for stages in [2, 3, 4] {
    let fixture = handshake_fixture(stages)
    let simulator = @sim.Simulator::prepare(fixture.hardware_module)
    coordinated_reset(simulator, fixture)
    assert_eq(output_bits(simulator, "source_ready"), "1")
    assert_eq(output_bits(simulator, "destination_valid"), "0")
    assert_eq(output_bits(simulator, "destination_word"), "00000000")
    accept_source(simulator, fixture, 3UL, logic(8, 165UL), logic(3, 5UL))
    assert_eq(output_bits(simulator, "source_ready"), "0")
    assert_eq(node_bits(simulator, fixture.primitive.request_toggle()), "1")
    assert_eq(
      node_bits(simulator, fixture.primitive.held_payload()[0]),
      "10100101",
    )
    for index in 0..<stages {
      destination_edge(
        simulator,
        fixture,
        4UL + index.to_uint64(),
        logic(1, 0UL),
      )
      assert_eq(output_bits(simulator, "destination_valid"), "0")
    }
    let capture_time = 4UL + stages.to_uint64()
    capture_destination(simulator, fixture, capture_time, logic(1, 0UL))
    assert_eq(output_bits(simulator, "destination_valid"), "1")
    assert_eq(output_bits(simulator, "destination_word"), "10100101")
    assert_eq(output_bits(simulator, "destination_tag"), "101")
    for index in 0..<stages {
      source_edge(simulator, fixture, capture_time + 1UL + index.to_uint64())
      assert_eq(
        output_bits(simulator, "source_ready"),
        if index + 1 == stages {
          "1"
        } else {
          "0"
        },
      )
    }

    // Reset from idle toggle phase one returns every visible and private role
    // to the canonical phase-zero empty state.
    let reset_time = capture_time + 1UL + stages.to_uint64()
    simulator.apply_event(
      event(
        reset_time,
        [
          drive("source_reset", logic(1, 1UL)),
          drive("destination_reset", logic(1, 1UL)),
          drive("source_valid", logic(1, 0UL)),
        ],
        [fixture.source_domain, fixture.destination_domain],
      ),
    )
    assert_eq(output_bits(simulator, "source_ready"), "1")
    assert_eq(output_bits(simulator, "destination_valid"), "0")
    assert_eq(output_bits(simulator, "destination_word"), "00000000")
    assert_eq(node_bits(simulator, fixture.primitive.request_toggle()), "0")
    assert_eq(node_bits(simulator, fixture.primitive.acknowledge_toggle()), "0")
    for stage in fixture.primitive.request_stages() {
      assert_eq(node_bits(simulator, stage), "0")
    }
    for stage in fixture.primitive.acknowledge_stages() {
      assert_eq(node_bits(simulator, stage), "0")
    }
    simulator.apply_event(
      event(
        reset_time + 1UL,
        [
          drive("source_reset", logic(1, 0UL)),
          drive("destination_reset", logic(1, 0UL)),
        ],
        [fixture.destination_domain, fixture.source_domain],
      ),
    )
    assert_eq(output_bits(simulator, "source_ready"), "1")
    assert_eq(output_bits(simulator, "destination_valid"), "0")
  }
}

///|
test "source hold destination backpressure queued refill and restore are exact" {
  let stages = 2
  let fixture = handshake_fixture(stages)
  let simulator = @sim.Simulator::prepare(fixture.hardware_module)
  coordinated_reset(simulator, fixture)
  accept_source(simulator, fixture, 3UL, logic(8, 17UL), logic(3, 1UL))
  ignore(propagate_request(simulator, fixture, stages, 4UL, logic(1, 0UL)))
  capture_destination(simulator, fixture, 6UL, logic(1, 0UL))
  assert_eq(output_bits(simulator, "destination_word"), "00010001")
  ignore(propagate_acknowledgement(simulator, fixture, stages, 7UL))
  assert_eq(output_bits(simulator, "source_ready"), "1")

  accept_source(simulator, fixture, 9UL, logic(8, 34UL), logic(3, 2UL))
  assert_eq(output_bits(simulator, "source_ready"), "0")
  simulator.apply_event(
    event(
      10UL,
      [
        drive("source_valid", logic(1, 1UL)),
        drive("source_word", logic(8, 255UL)),
        drive("source_tag", logic(3, 7UL)),
      ],
      [fixture.source_domain],
    ),
  )
  assert_eq(
    node_bits(simulator, fixture.primitive.held_payload()[0]),
    "00100010",
  )
  assert_eq(node_bits(simulator, fixture.primitive.held_payload()[1]), "010")
  destination_edge(simulator, fixture, 11UL, logic(1, 0UL))
  destination_edge(simulator, fixture, 12UL, logic(1, 0UL))
  destination_edge(simulator, fixture, 13UL, logic(1, 0UL))
  assert_eq(output_bits(simulator, "destination_valid"), "1")
  assert_eq(output_bits(simulator, "destination_word"), "00010001")
  assert_eq(node_bits(simulator, fixture.primitive.acknowledge_toggle()), "1")

  let before_refill = simulator.snapshot()
  destination_edge(simulator, fixture, 14UL, logic(1, 1UL))
  let after_refill = simulator.snapshot()
  assert_eq(output_bits(simulator, "destination_valid"), "1")
  assert_eq(output_bits(simulator, "destination_word"), "00100010")
  assert_eq(output_bits(simulator, "destination_tag"), "010")
  assert_eq(node_bits(simulator, fixture.primitive.acknowledge_toggle()), "0")
  simulator.restore(before_refill)
  destination_edge(simulator, fixture, 14UL, logic(1, 1UL))
  assert_eq(simulator.snapshot(), after_refill)
  destination_edge(simulator, fixture, 15UL, logic(1, 1UL))
  assert_eq(output_bits(simulator, "destination_valid"), "0")
  assert_eq(output_bits(simulator, "destination_word"), "00100010")
}

///|
test "coincident caller permutations retain global pre-state sampling" {
  let fixture = handshake_fixture(2)
  let first = @sim.Simulator::prepare(fixture.hardware_module)
  let second = @sim.Simulator::prepare(fixture.hardware_module)
  coordinated_reset(first, fixture)
  coordinated_reset(second, fixture)
  let forward = event(
    3UL,
    [
      drive("source_valid", logic(1, 1UL)),
      drive("source_word", logic(8, 90UL)),
      drive("source_tag", logic(3, 3UL)),
    ],
    [fixture.source_domain, fixture.destination_domain],
  )
  let reversed = event(
    3UL,
    [
      drive("source_tag", logic(3, 3UL)),
      drive("source_word", logic(8, 90UL)),
      drive("source_valid", logic(1, 1UL)),
    ],
    [fixture.destination_domain, fixture.source_domain],
  )
  assert_eq(forward, reversed)
  first.apply_event(forward)
  second.apply_event(reversed)
  assert_eq(first.snapshot(), second.snapshot())
  assert_eq(node_bits(first, fixture.primitive.request_stages()[0]), "0")
  destination_edge(first, fixture, 4UL, logic(1, 0UL))
  destination_edge(second, fixture, 4UL, logic(1, 0UL))
  destination_edge(first, fixture, 5UL, logic(1, 0UL))
  destination_edge(second, fixture, 5UL, logic(1, 0UL))
  assert_eq(output_bits(first, "destination_valid"), "0")
  destination_edge(first, fixture, 6UL, logic(1, 0UL))
  destination_edge(second, fixture, 6UL, logic(1, 0UL))
  assert_eq(first.snapshot(), second.snapshot())
  assert_eq(output_bits(first, "destination_valid"), "1")
  assert_eq(output_bits(first, "destination_word"), "01011010")
}

///|
test "four-state controls are non-transfers while structural merges remain visible" {
  let fixture = handshake_fixture(2)
  let source_unknown = @sim.Simulator::prepare(fixture.hardware_module)
  coordinated_reset(source_unknown, fixture)
  source_unknown.apply_event(
    event(
      3UL,
      [
        drive("source_valid", logic(1, 0UL)),
        drive("source_word", mixed(8, 165UL, 243UL)),
        drive("source_tag", mixed(3, 5UL, 5UL)),
      ],
      [fixture.source_domain],
    ),
  )
  assert_eq(node_bits(source_unknown, fixture.primitive.request_toggle()), "0")
  assert_eq(
    node_bits(source_unknown, fixture.primitive.held_payload()[0]),
    "00000000",
  )
  source_unknown.apply_event(
    event(
      4UL,
      [
        drive("source_valid", @wave.LogicValue::unknown(width=1)),
        drive("source_word", logic(8, 255UL)),
        drive("source_tag", logic(3, 7UL)),
      ],
      [fixture.source_domain],
    ),
  )
  assert_eq(node_bits(source_unknown, fixture.primitive.request_toggle()), "x")
  assert_eq(output_bits(source_unknown, "source_ready"), "x")
  assert_eq(
    node_bits(source_unknown, fixture.primitive.held_payload()[0]),
    "xxxxxxxx",
  )

  let payload_unknown = @sim.Simulator::prepare(fixture.hardware_module)
  coordinated_reset(payload_unknown, fixture)
  accept_source(
    payload_unknown,
    fixture,
    3UL,
    mixed(8, 165UL, 243UL),
    mixed(3, 5UL, 5UL),
  )
  destination_edge(payload_unknown, fixture, 4UL, logic(1, 0UL))
  destination_edge(payload_unknown, fixture, 5UL, logic(1, 0UL))
  destination_edge(payload_unknown, fixture, 6UL, logic(1, 0UL))
  assert_eq(output_bits(payload_unknown, "destination_word"), "1010xx01")
  assert_eq(output_bits(payload_unknown, "destination_tag"), "1x1")

  let ready_unknown = @sim.Simulator::prepare(fixture.hardware_module)
  coordinated_reset(ready_unknown, fixture)
  accept_source(ready_unknown, fixture, 3UL, logic(8, 51UL), logic(3, 4UL))
  destination_edge(ready_unknown, fixture, 4UL, logic(1, 0UL))
  destination_edge(ready_unknown, fixture, 5UL, logic(1, 0UL))
  destination_edge(ready_unknown, fixture, 6UL, logic(1, 0UL))
  destination_edge(
    ready_unknown,
    fixture,
    7UL,
    @wave.LogicValue::unknown(width=1),
  )
  assert_eq(output_bits(ready_unknown, "destination_valid"), "x")
  assert_eq(output_bits(ready_unknown, "destination_word"), "00110011")
}

///|
priv enum ResetEvidenceClass {
  CoordinatedIdle
  ExpectedResetFlushLoss
} derive(Debug, Eq)

///|
fn event_asserts(event : @sim.TimestampEvent, name : String) -> Bool raise {
  for item in event.drives() {
    if item.name() == name {
      return item.value() == logic(1, 1UL)
    }
  }
  false
}

///|
fn event_activates(
  event : @sim.TimestampEvent,
  domain : @ir.ClockDomainId,
) -> Bool {
  for active in event.active_domains() {
    if active == domain {
      return true
    }
  }
  false
}

///|
fn classify_reset_evidence(
  fixture : HandshakeFixture,
  reset_event : @sim.TimestampEvent,
  traffic_live : Bool,
) -> ResetEvidenceClass raise {
  let source_asserted = event_asserts(reset_event, "source_reset")
  let destination_asserted = event_asserts(reset_event, "destination_reset")
  if !traffic_live &&
    source_asserted &&
    destination_asserted &&
    event_activates(reset_event, fixture.source_domain) &&
    event_activates(reset_event, fixture.destination_domain) {
    CoordinatedIdle
  } else if traffic_live && source_asserted != destination_asserted {
    ExpectedResetFlushLoss
  } else {
    abort("reset event is outside the Phase 5 evidence classes")
  }
}

///|
test "unilateral mid-flight resets are classified only as expected flush loss" {
  let fixture = handshake_fixture(2)
  let source_flush = @sim.Simulator::prepare(fixture.hardware_module)
  coordinated_reset(source_flush, fixture)
  accept_source(source_flush, fixture, 3UL, logic(8, 119UL), logic(3, 6UL))
  destination_edge(source_flush, fixture, 4UL, logic(1, 0UL))
  let source_reset_event = event(5UL, [drive("source_reset", logic(1, 1UL))], [
    fixture.source_domain,
  ])
  source_flush.apply_event(source_reset_event)
  let source_class = classify_reset_evidence(fixture, source_reset_event, true)
  assert_eq(source_class, ExpectedResetFlushLoss)
  assert_eq(node_bits(source_flush, fixture.primitive.request_toggle()), "0")
  assert_eq(
    node_bits(source_flush, fixture.primitive.held_payload()[0]),
    "00000000",
  )

  let destination_flush = @sim.Simulator::prepare(fixture.hardware_module)
  coordinated_reset(destination_flush, fixture)
  accept_source(destination_flush, fixture, 3UL, logic(8, 68UL), logic(3, 2UL))
  destination_edge(destination_flush, fixture, 4UL, logic(1, 0UL))
  destination_edge(destination_flush, fixture, 5UL, logic(1, 0UL))
  destination_edge(destination_flush, fixture, 6UL, logic(1, 0UL))
  assert_eq(output_bits(destination_flush, "destination_valid"), "1")
  let destination_reset_event = event(
    7UL,
    [drive("destination_reset", logic(1, 1UL))],
    [fixture.destination_domain],
  )
  destination_flush.apply_event(destination_reset_event)
  let destination_class = classify_reset_evidence(
    fixture, destination_reset_event, true,
  )
  assert_eq(destination_class, ExpectedResetFlushLoss)
  assert_eq(output_bits(destination_flush, "destination_valid"), "0")
  assert_eq(output_bits(destination_flush, "destination_word"), "00000000")

  let coordinated = @sim.Simulator::prepare(fixture.hardware_module)
  let idle_event = event(1UL, reset_drives(1UL), [
    fixture.destination_domain,
    fixture.source_domain,
  ])
  coordinated.apply_event(idle_event)
  let idle_class = classify_reset_evidence(fixture, idle_event, false)
  assert_eq(idle_class, CoordinatedIdle)
  assert_eq(output_bits(coordinated, "source_ready"), "1")
  assert_eq(output_bits(coordinated, "destination_valid"), "0")
}
