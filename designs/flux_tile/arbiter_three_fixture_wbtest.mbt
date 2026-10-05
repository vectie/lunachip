///|
// This fixture is white-box because the transport is deliberately private.
// Tests observe only the fixture's handshakes and complete bus payloads.
fn arbiter_three_probe() -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("ArbiterThreeProbe")
  let clock = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock)
  let reset_signal = builder.input("reset", @wire.reset())
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let reset_inactive = builder.bit_not(builder.reset_asserted(reset_signal))
  let registers = arbiter_three_registers(builder, domain, reset)
  let bus : ArbiterBusInputs = {
    request_ready: builder.input("bus_request_ready", @wire.bits(1)),
    response_valid: builder.input("bus_response_valid", @wire.bits(1)),
    response_tag: builder.input("bus_response_tag", @wire.uint(32)),
    response_fault: builder.input("bus_response_fault", @wire.uint(2)),
    response_data: builder.input("bus_response_data", @wire.bits(32)),
  }
  let routes = arbiter_three_routes(builder, registers, reset_inactive, bus)
  let prefixes = ["reader", "loader", "storer"]
  let requests = prefixes.map(prefix => arbiter_probe_request(builder, prefix))
  let response_readies = prefixes.map(prefix =>
    builder.input(prefix + "_response_ready", @wire.bits(1)))
  let response_ready = arbiter_three_controller(
    builder, registers, reset_inactive, bus, routes, requests, response_readies,
  )
  for
    (name, signal) in [
      ("request_valid", routes.request_valid),
      ("request_write", routes.request_write),
      ("request_address", routes.address),
      ("request_bytes", routes.request_bytes),
      ("request_mask", routes.request_mask),
      ("request_data", routes.request_data),
      ("request_tag", routes.request_tag),
      ("response_ready", response_ready),
      ("poisoned", routes.poisoned),
    ] {
    execute_output(builder, name, signal)
  }
  for owner in 0..<3 {
    arbiter_probe_client_outputs(builder, prefixes[owner], routes.clients[owner])
  }
  builder.finish()
}

///|
fn arbiter_three_prepare() -> @sim.Simulator raise {
  let simulator = @sim.Simulator::prepare(arbiter_three_probe())
  for
    (name, width) in [
      ("reset", 1),
      ("bus_request_ready", 1),
      ("bus_response_valid", 1),
      ("bus_response_tag", 32),
      ("bus_response_fault", 2),
      ("bus_response_data", 32),
    ] {
    arbiter_probe_put(simulator, name, width, 0UL)
  }
  for owner, prefix in ["reader", "loader", "storer"] {
    arbiter_probe_put(simulator, prefix + "_response_ready", 1, 0UL)
    for
      (field, width, value) in [
        ("valid", 1, 0UL),
        ("write", 1, if owner == 2 { 1UL } else { 0UL }),
        ("address", 32, (16 * (owner + 1)).to_uint64()),
        ("bytes", 3, if owner == 2 { 4UL } else { 1UL }),
        ("mask", 4, if owner == 2 { 15UL } else { 1UL }),
        ("data", 32, (128 + owner).to_uint64()),
        ("tag", 32, 77UL),
      ] {
      arbiter_probe_put(simulator, prefix + "_" + field, width, value)
    }
  }
  arbiter_probe_put(simulator, "reset", 1, 1UL)
  simulator.rising_edge("clock")
  arbiter_probe_put(simulator, "reset", 1, 0UL)
  simulator
}

///|
fn arbiter_three_ready_owner(
  simulator : @sim.Simulator,
  field : String,
  owner : Int,
) -> Unit raise {
  for index, prefix in ["reader", "loader", "storer"] {
    assert_eq(
      arbiter_probe_read(simulator, prefix + "_" + field),
      if index == owner { 1UL } else { 0UL },
    )
  }
}

///|
fn arbiter_three_transaction(
  simulator : @sim.Simulator,
  owner : Int,
  tag : UInt64,
  fault : UInt64,
) -> Unit raise {
  assert_eq(arbiter_probe_read(simulator, "request_valid"), 0UL)
  simulator.rising_edge("clock")
  assert_eq(arbiter_probe_read(simulator, "request_valid"), 1UL)
  assert_eq(arbiter_probe_read(simulator, "request_tag"), tag)
  assert_eq(
    arbiter_probe_read(simulator, "request_address"),
    (16 * (owner + 1)).to_uint64(),
  )
  arbiter_three_ready_owner(simulator, "request_ready", owner)
  simulator.rising_edge("clock")
  arbiter_probe_put(simulator, "bus_response_tag", 32, tag)
  arbiter_probe_put(simulator, "bus_response_fault", 2, fault)
  arbiter_probe_put(simulator, "bus_response_data", 32, 0xdeadbeefUL)
  arbiter_probe_put(simulator, "bus_response_valid", 1, 1UL)
  arbiter_three_ready_owner(simulator, "response_valid", owner)
  let prefix = ["reader", "loader", "storer"][owner]
  assert_eq(arbiter_probe_read(simulator, prefix + "_response_tag"), 77UL)
  assert_eq(arbiter_probe_read(simulator, prefix + "_response_fault"), fault)
  assert_eq(
    arbiter_probe_read(simulator, prefix + "_response_data"),
    0xdeadbeefUL,
  )
  assert_eq(arbiter_probe_read(simulator, "response_ready"), 1UL)
  assert_eq(arbiter_probe_read(simulator, "request_valid"), 0UL)
  simulator.rising_edge("clock")
  arbiter_probe_put(simulator, "bus_response_valid", 1, 0UL)
  assert_eq(arbiter_probe_read(simulator, "poisoned"), 0UL)
  // No same-edge response retirement and next request acceptance.
  assert_eq(arbiter_probe_read(simulator, "request_valid"), 0UL)
}
