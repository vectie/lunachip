///|
fn logic(width : Int, value : UInt64) -> @wave.LogicValue raise {
  @wave.LogicValue::from_uint64(width~, value~)
}

///|
fn mixed(width : Int, value : UInt64, known : UInt64) -> @wave.LogicValue raise {
  @wave.LogicValue::from_masks(width~, value_bits=value, known_mask=known)
}

///|
fn drive(name : String, value : @wave.LogicValue) -> @sim.InputDrive raise {
  @sim.InputDrive::checked(name, value)
}

///|
fn event(
  time : UInt64,
  drives : ArrayView[@sim.InputDrive],
  domains : ArrayView[@ir.ClockDomainId],
) -> @sim.TimestampEvent raise {
  @sim.TimestampEvent::checked(
    @sim.SimulationTime::from_uint64(time),
    drives,
    domains,
  )
}

///|
fn reset_drives(asserted : UInt64) -> Array[@sim.InputDrive] raise {
  [
    drive("source_reset", logic(1, asserted)),
    drive("destination_reset", logic(1, asserted)),
    drive("source_valid", logic(1, 0UL)),
    drive("source_word", logic(8, 0UL)),
    drive("source_tag", logic(3, 0UL)),
    drive("destination_ready", logic(1, 0UL)),
  ]
}

///|
fn coordinated_reset(
  simulator : @sim.Simulator,
  fixture : HandshakeFixture,
) -> Unit raise {
  simulator.apply_event(
    event(1UL, reset_drives(1UL), [
      fixture.source_domain,
      fixture.destination_domain,
    ]),
  )
  simulator.apply_event(
    event(
      2UL,
      [
        drive("source_reset", logic(1, 0UL)),
        drive("destination_reset", logic(1, 0UL)),
      ],
      [fixture.source_domain, fixture.destination_domain],
    ),
  )
}

///|
fn output_bits(simulator : @sim.Simulator, name : String) -> String raise {
  simulator.output(name).to_bit_string()
}

///|
fn node_bits(simulator : @sim.Simulator, node : @ir.NodeId) -> String raise {
  simulator.value(node).to_bit_string()
}

///|
fn accept_source(
  simulator : @sim.Simulator,
  fixture : HandshakeFixture,
  time : UInt64,
  word : @wave.LogicValue,
  tag : @wave.LogicValue,
) -> Unit raise {
  simulator.apply_event(
    event(
      time,
      [
        drive("source_valid", logic(1, 1UL)),
        drive("source_word", word),
        drive("source_tag", tag),
      ],
      [fixture.source_domain],
    ),
  )
}

///|
fn destination_edge(
  simulator : @sim.Simulator,
  fixture : HandshakeFixture,
  time : UInt64,
  ready : @wave.LogicValue,
) -> Unit raise {
  simulator.apply_event(
    event(time, [drive("destination_ready", ready)], [
      fixture.destination_domain,
    ]),
  )
}

///|
fn source_edge(
  simulator : @sim.Simulator,
  fixture : HandshakeFixture,
  time : UInt64,
) -> Unit raise {
  simulator.apply_event(event(time, [], [fixture.source_domain]))
}

///|
fn propagate_request(
  simulator : @sim.Simulator,
  fixture : HandshakeFixture,
  stages : Int,
  first_time : UInt64,
  ready : @wave.LogicValue,
) -> UInt64 raise {
  let mut time = first_time
  for _ in 0..<stages {
    destination_edge(simulator, fixture, time, ready)
    time += 1UL
  }
  time
}

///|
fn capture_destination(
  simulator : @sim.Simulator,
  fixture : HandshakeFixture,
  time : UInt64,
  ready : @wave.LogicValue,
) -> Unit raise {
  destination_edge(simulator, fixture, time, ready)
}

///|
fn propagate_acknowledgement(
  simulator : @sim.Simulator,
  fixture : HandshakeFixture,
  stages : Int,
  first_time : UInt64,
) -> UInt64 raise {
  let mut time = first_time
  for _ in 0..<stages {
    source_edge(simulator, fixture, time)
    time += 1UL
  }
  time
}
