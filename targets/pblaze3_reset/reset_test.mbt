///|
priv struct Harness {
  simulator : @sim.Simulator
  domain : @ir.ClockDomainId
  mut time : UInt64
}

///|
fn Harness::new() -> Harness raise {
  let hw = @pblaze3_reset.hardware_module()
  {
    simulator: @sim.Simulator::prepare(hw),
    domain: hw.domains()[0].id(),
    time: 0UL,
  }
}

///|
fn Harness::event(
  self : Harness,
  edge~ : Bool = false,
  reset? : UInt64,
  elapsed~ : UInt64 = 10UL,
) -> Unit raise {
  self.time += elapsed
  let drives = match reset {
    Some(value) =>
      [
        @sim.InputDrive::checked(
          "reset",
          @wave.LogicValue::from_uint64(width=1, value~),
        ),
      ]
    None => []
  }
  self.simulator.apply_event(
    @sim.TimestampEvent::checked(
      @sim.SimulationTime::from_uint64(self.time),
      drives,
      if edge {
        [self.domain]
      } else {
        []
      },
    ),
  )
}

///|
fn Harness::released(self : Harness) -> UInt64 raise {
  self.simulator.output("release_n").to_uint64()
}

///|
fn Harness::release_after_128(self : Harness) -> Unit raise {
  self.event(reset=0UL)
  for _ in 0..<127 {
    self.event(edge=true, elapsed=20UL)
    assert_eq(self.released(), 0UL)
  }
  self.event(edge=true, elapsed=20UL)
  assert_eq(self.released(), 1UL)
}

///|
test "PBlaze3 reset counts exactly128 healthy edges and saturates" {
  let h = Harness::new()
  assert_false(h.simulator.output("release_n").is_fully_known())
  h.event(reset=1UL)
  assert_eq(h.released(), 0UL)
  for _ in 0..<256 {
    h.event(edge=true)
    assert_eq(h.released(), 0UL)
  }
  h.release_after_128()
  for _ in 0..<1024 {
    h.event(edge=true)
    assert_eq(h.released(), 1UL)
  }
}

///|
test "PBlaze3 fault just before release restarts the full interval" {
  let h = Harness::new()
  h.event(reset=1UL)
  h.event(reset=0UL)
  for _ in 0..<127 {
    h.event(edge=true)
  }
  assert_eq(h.released(), 0UL)
  // A fault coincident with the otherwise releasing edge has reset priority.
  h.event(edge=true, reset=1UL)
  assert_eq(h.released(), 0UL)
  h.release_after_128()
  // A new assertion is effective between clock edges, even after saturation.
  let edges = h.simulator.domain_edge_count(h.domain)
  h.event(reset=1UL, elapsed=1UL)
  assert_eq(h.released(), 0UL)
  assert_eq(h.simulator.domain_edge_count(h.domain), edges)
  h.release_after_128()
}

///|
test "PBlaze3 halted clock cannot release and asynchronous faults still assert" {
  let h = Harness::new()
  h.event(reset=1UL)
  h.event(reset=0UL)
  for _ in 0..<127 {
    h.event(edge=true)
  }
  // Elapsed simulation time is not counted as healthy clock edges.
  h.event(reset=0UL, elapsed=1000000000UL)
  assert_eq(h.released(), 0UL)
  h.event(edge=true)
  assert_eq(h.released(), 1UL)
  let edges = h.simulator.domain_edge_count(h.domain)
  h.event(reset=1UL, elapsed=1000000000UL)
  assert_eq(h.released(), 0UL)
  h.event(reset=0UL)
  h.event(reset=0UL, elapsed=1000000000UL)
  assert_eq(h.released(), 0UL)
  assert_eq(h.simulator.domain_edge_count(h.domain), edges)
  h.release_after_128()
}

///|
test "PBlaze3 reset generator is deterministic and explicitly asynchronous" {
  let first = @pblaze3_reset.hardware_module()
  assert_eq(first, @pblaze3_reset.hardware_module())
  let registers = first.nodes().filter(node => node.kind() is Register(_))
  assert_eq(registers.length(), 1)
  guard registers[0].kind() is Register(spec) else { fail("register expected") }
  guard spec.reset() is Some(reset) else { fail("explicit reset expected") }
  assert_eq(reset.mode(), Asynchronous)
  assert_eq(reset.polarity(), ActiveHigh)
  assert_eq(reset.value(), 0UL)
  assert_eq(registers[0].signal_type().width().bits(), 8)
}
