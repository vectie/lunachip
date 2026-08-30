///|
fn event_data_type(width : Int) -> @ir.SignalType raise {
  UInt(@ir.Width::new(width))
}

///|
fn cross_coupled_domains() -> @ir.Module raise {
  let clock_a = @ir.NodeId::new(0)
  let clock_b = @ir.NodeId::new(1)
  let state_a = @ir.NodeId::new(2)
  let state_b = @ir.NodeId::new(3)
  let eight = event_data_type(8)
  @ir.Module::checked(
    "CrossCoupledDomains",
    [
      @ir.Node::new(clock_a, Clock, Input("clock_a")),
      @ir.Node::new(clock_b, Clock, Input("clock_b")),
      @ir.Node::new(
        state_a,
        eight,
        Register(
          @ir.RegisterSpec::new(
            @ir.ClockDomain::rising(clock_a),
            state_b,
            initial=1UL,
          ),
        ),
      ),
      @ir.Node::new(
        state_b,
        eight,
        Register(
          @ir.RegisterSpec::new(
            @ir.ClockDomain::rising(clock_b),
            state_a,
            initial=2UL,
          ),
        ),
      ),
    ],
    [
      @ir.OutputPort::new("state_a", eight, state_a),
      @ir.OutputPort::new("state_b", eight, state_b),
    ],
  )
}

///|
fn timestamp_event(
  time : UInt64,
  domains : ArrayView[@ir.ClockDomainId],
) -> @sim.TimestampEvent raise {
  @sim.TimestampEvent::checked(
    @sim.SimulationTime::from_uint64(time),
    [],
    domains,
  )
}

///|
test "timestamp events canonicalize drives and domains and reject duplicates" {
  let drive_z = @sim.InputDrive::checked("z", @wave.LogicValue::zero(width=1))
  let drive_a = @sim.InputDrive::checked("a", @wave.LogicValue::one(width=1))
  let domain_4 = @ir.ClockDomainId::new(4)
  let domain_1 = @ir.ClockDomainId::new(1)
  let event = @sim.TimestampEvent::checked(
    @sim.SimulationTime::from_uint64(9UL),
    [drive_z, drive_a],
    [domain_4, domain_1],
  )
  assert_eq(event.drives()[0].name(), "a")
  assert_eq(event.drives()[1].name(), "z")
  assert_eq(event.active_domains()[0].ordinal(), 1)
  assert_eq(event.active_domains()[1].ordinal(), 4)
  try
    @sim.TimestampEvent::checked(
      @sim.SimulationTime::from_uint64(10UL),
      [drive_a, drive_a],
      [],
    )
  catch {
    DuplicateInputDrive(name) => assert_eq(name, "a")
    error => fail("unexpected duplicate-drive error: \{Repr(error)}")
  } noraise {
    _ => fail("expected duplicate input drive rejection")
  }
  try
    @sim.TimestampEvent::checked(@sim.SimulationTime::from_uint64(10UL), [], [
      domain_1, domain_1,
    ])
  catch {
    DuplicateActiveDomain(domain) => assert_eq(domain, 1)
    error => fail("unexpected duplicate-domain error: \{Repr(error)}")
  } noraise {
    _ => fail("expected duplicate active domain rejection")
  }
}

///|
test "coincident domains sample one pre-commit snapshot independent of order" {
  let domain_a = @ir.ClockDomainId::new(0)
  let domain_b = @ir.ClockDomainId::new(1)
  let first = @sim.Simulator::prepare(cross_coupled_domains())
  let second = @sim.Simulator::prepare(cross_coupled_domains())
  first.apply_event(timestamp_event(1UL, [domain_b, domain_a]))
  second.apply_event(timestamp_event(1UL, [domain_a, domain_b]))
  assert_eq(first.output("state_a"), second.output("state_a"))
  assert_eq(first.output("state_b"), second.output("state_b"))
  inspect(first.output("state_a").to_uint64(), content="2")
  inspect(first.output("state_b").to_uint64(), content="1")
  inspect(first.time().value(), content="1")
  inspect(first.event_ordinal(), content="1")
  inspect(first.domain_edge_count(domain_a), content="1")
  inspect(first.domain_edge_count(domain_b), content="1")
}

///|
test "separate timestamp events observe prior committed domain state" {
  let domain_a = @ir.ClockDomainId::new(0)
  let domain_b = @ir.ClockDomainId::new(1)
  let simulator = @sim.Simulator::prepare(cross_coupled_domains())
  simulator.apply_event(timestamp_event(1UL, [domain_a]))
  simulator.apply_event(timestamp_event(2UL, [domain_b]))
  inspect(simulator.output("state_a").to_uint64(), content="2")
  inspect(simulator.output("state_b").to_uint64(), content="2")
  inspect(simulator.event_ordinal(), content="2")
  inspect(simulator.domain_edge_count(domain_a), content="1")
  inspect(simulator.domain_edge_count(domain_b), content="1")
}

///|
test "invalid timestamp events fail before mutating simulator state" {
  let domain_a = @ir.ClockDomainId::new(0)
  let simulator = @sim.Simulator::prepare(cross_coupled_domains())
  simulator.apply_event(timestamp_event(2UL, [domain_a]))
  try simulator.apply_event(timestamp_event(2UL, [domain_a])) catch {
    @sim.SimulatorError::NonMonotonicTimestamp(previous~, actual~) => {
      assert_eq(previous, 2UL)
      assert_eq(actual, 2UL)
    }
    error => fail("unexpected timestamp error: \{Repr(error)}")
  } noraise {
    _ => fail("expected non-monotonic timestamp rejection")
  }
  try
    simulator.apply_event(timestamp_event(3UL, [@ir.ClockDomainId::new(99)]))
  catch {
    @sim.SimulatorError::UnknownClockDomainId(domain) => assert_eq(domain, 99)
    error => fail("unexpected unknown-domain error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unknown domain rejection")
  }
  inspect(simulator.time().value(), content="2")
  inspect(simulator.event_ordinal(), content="1")
  inspect(simulator.output("state_a").to_uint64(), content="2")
}

///|
fn coincident_memory_module() -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("CoincidentMemory")
  let clock_a = builder.input("clock_a", @wire.clock())
  let clock_b = builder.input("clock_b", @wire.clock())
  let domain_a = builder.rising_edge(clock_a)
  let domain_b = builder.rising_edge(clock_b)
  let address = builder.input("address", @wire.uint(1))
  let data = builder.input("data", @wire.uint(8))
  let write_enable = builder.input("write_enable", @wire.bits(1))
  let memory = builder.synchronous_memory(
    "storage",
    @wire.uint(8),
    2,
    domain_a,
    read_write_policy=ReadNew,
  )
  builder.memory_write(memory, "write", address, data, enable=write_enable)
  let read = builder.memory_read(memory, "read", address)
  let captured = builder.register_in(domain_b, read, initial=0UL)
  let read_output = builder.output("read", @wire.uint(8))
  let captured_output = builder.output("captured", @wire.uint(8))
  builder.connect(read_output, read)
  builder.connect(captured_output, captured)
  builder.finish()
}

///|
fn input_drive(
  name : String,
  width : Int,
  value : UInt64,
) -> @sim.InputDrive raise {
  @sim.InputDrive::checked(name, @wave.LogicValue::from_uint64(width~, value~))
}

///|
test "coincident memory and register updates share the pre-edge read state" {
  let simulator = @sim.Simulator::prepare(coincident_memory_module())
  let domain_a = @ir.ClockDomainId::new(0)
  let domain_b = @ir.ClockDomainId::new(1)
  simulator.apply_event(
    @sim.TimestampEvent::checked(
      @sim.SimulationTime::from_uint64(1UL),
      [
        input_drive("address", 1, 0UL),
        input_drive("data", 8, 5UL),
        input_drive("write_enable", 1, 1UL),
      ],
      [domain_a],
    ),
  )
  inspect(simulator.output("read").to_uint64(), content="5")
  simulator.apply_event(
    @sim.TimestampEvent::checked(
      @sim.SimulationTime::from_uint64(2UL),
      [input_drive("data", 8, 9UL)],
      [domain_b, domain_a],
    ),
  )
  inspect(simulator.output("read").to_uint64(), content="9")
  inspect(simulator.output("captured").to_uint64(), content="5")
}

///|
fn transactional_memory_module() -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("TransactionalMemory")
  let clock_a = builder.input("clock_a", @wire.clock())
  let clock_b = builder.input("clock_b", @wire.clock())
  let domain_a = builder.rising_edge(clock_a)
  let domain_b = builder.rising_edge(clock_b)
  let address = builder.input("address", @wire.uint(1))
  let data = builder.input("data", @wire.uint(8))
  let write_enable = builder.input("write_enable", @wire.bits(1))
  let memory = builder.synchronous_memory(
    "storage",
    @wire.uint(8),
    1,
    domain_b,
    read_write_policy=ReadNew,
    bounds_policy=Fault,
  )
  builder.memory_write(memory, "write", address, data, enable=write_enable)
  let read = builder.memory_read(memory, "read", address)
  let captured = builder.register_in(domain_a, read, initial=0UL)
  let read_output = builder.output("read", @wire.uint(8))
  let captured_output = builder.output("captured", @wire.uint(8))
  let address_output = builder.output("address_monitor", @wire.uint(1))
  let data_output = builder.output("data_monitor", @wire.uint(8))
  builder.connect(read_output, read)
  builder.connect(captured_output, captured)
  builder.connect(address_output, address)
  builder.connect(data_output, data)
  builder.finish()
}

///|
test "failing atomic memory event rolls back every mutable simulator field" {
  let simulator = @sim.Simulator::prepare(transactional_memory_module())
  let domain_a = @ir.ClockDomainId::new(0)
  let domain_b = @ir.ClockDomainId::new(1)
  simulator.apply_event(
    @sim.TimestampEvent::checked(
      @sim.SimulationTime::from_uint64(1UL),
      [
        input_drive("address", 1, 0UL),
        input_drive("data", 8, 5UL),
        input_drive("write_enable", 1, 1UL),
      ],
      [domain_b],
    ),
  )
  try
    simulator.apply_event(
      @sim.TimestampEvent::checked(
        @sim.SimulationTime::from_uint64(2UL),
        [input_drive("address", 1, 1UL), input_drive("data", 8, 9UL)],
        [domain_a, domain_b],
      ),
    )
  catch {
    @sim.SimulatorError::MemoryAddressOutOfRange(
      memory~,
      role=_,
      port=_,
      address~,
      depth~
    ) => {
      assert_eq(memory, "storage")
      assert_eq(address, 1UL)
      assert_eq(depth, 1)
    }
    error => fail("unexpected transactional failure: \{Repr(error)}")
  } noraise {
    _ => fail("expected out-of-range memory event rejection")
  }
  inspect(simulator.output("address_monitor").to_uint64(), content="0")
  inspect(simulator.output("data_monitor").to_uint64(), content="5")
  inspect(simulator.output("read").to_uint64(), content="5")
  inspect(simulator.output("captured").to_uint64(), content="0")
  inspect(simulator.memory_cell("storage", 0).to_uint64(), content="5")
  inspect(simulator.time().value(), content="1")
  inspect(simulator.event_ordinal(), content="1")
  inspect(simulator.cycle().value(), content="1")
  inspect(simulator.domain_edge_count(domain_a), content="0")
  inspect(simulator.domain_edge_count(domain_b), content="1")

  simulator.apply_event(
    @sim.TimestampEvent::checked(
      @sim.SimulationTime::from_uint64(2UL),
      [input_drive("address", 1, 0UL), input_drive("data", 8, 9UL)],
      [domain_b, domain_a],
    ),
  )
  inspect(simulator.output("read").to_uint64(), content="9")
  inspect(simulator.output("captured").to_uint64(), content="5")
  inspect(simulator.memory_cell("storage", 0).to_uint64(), content="9")
  inspect(simulator.time().value(), content="2")
  inspect(simulator.event_ordinal(), content="2")
  inspect(simulator.cycle().value(), content="2")
  inspect(simulator.domain_edge_count(domain_a), content="1")
  inspect(simulator.domain_edge_count(domain_b), content="2")
}
