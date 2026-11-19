///|
fn arbiter_probe_request(
  builder : @wire.ModuleBuilder,
  prefix : String,
) -> ArbiterRequest raise {
  {
    valid: builder.input(prefix + "_valid", @wire.bits(1)),
    write: builder.input(prefix + "_write", @wire.bits(1)),
    address: builder.input(prefix + "_address", @wire.uint(32)),
    bytes: builder.input(prefix + "_bytes", @wire.uint(3)),
    mask: builder.input(prefix + "_mask", @wire.bits(4)),
    data: builder.input(prefix + "_data", @wire.bits(32)),
    tag: builder.input(prefix + "_tag", @wire.uint(32)),
  }
}

///|
fn arbiter_probe_client_outputs(
  builder : @wire.ModuleBuilder,
  prefix : String,
  route : ArbiterClientRoute,
) -> Unit raise {
  for
    (name, signal) in [
      ("request_ready", route.request_ready),
      ("response_valid", route.response_valid),
      ("response_tag", route.response_tag),
      ("response_fault", route.response_fault),
      ("response_data", route.response_data),
    ] {
    execute_output(builder, prefix + "_" + name, signal)
  }
}

///|
fn arbiter_probe() -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("ArbiterProbe")
  let clock = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock)
  let reset_signal = builder.input("reset", @wire.reset())
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let reset_inactive = builder.bit_not(builder.reset_asserted(reset_signal))
  let registers = arbiter_registers(builder, domain, reset)
  let bus : ArbiterBusInputs = {
    request_ready: builder.input("bus_request_ready", @wire.bits(1)),
    response_valid: builder.input("bus_response_valid", @wire.bits(1)),
    response_tag: builder.input("bus_response_tag", @wire.uint(32)),
    response_fault: builder.input("bus_response_fault", @wire.uint(2)),
    response_data: builder.input("bus_response_data", @wire.bits(32)),
  }
  let routes = arbiter_routes(builder, registers, reset_inactive, bus)
  let reader = arbiter_probe_request(builder, "reader")
  let engine = arbiter_probe_request(builder, "engine")
  let reader_ready = builder.input("reader_response_ready", @wire.bits(1))
  let engine_ready = builder.input("engine_response_ready", @wire.bits(1))
  let response_ready = arbiter_controller(
    builder, registers, reset_inactive, bus, routes, reader, reader_ready, engine,
    engine_ready,
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
  arbiter_probe_client_outputs(builder, "reader", routes.reader)
  arbiter_probe_client_outputs(builder, "engine", routes.engine)
  builder.finish()
}

///|
fn arbiter_probe_put(
  simulator : @sim.Simulator,
  name : String,
  width : Int32,
  value : UInt64,
) -> Unit raise {
  simulator.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
  simulator.settle()
}

///|
fn arbiter_probe_read(
  simulator : @sim.Simulator,
  name : String,
) -> UInt64 raise {
  simulator.output(name).to_uint64()
}

///|
fn arbiter_probe_prepare() -> @sim.Simulator raise {
  let simulator = @sim.Simulator::prepare(arbiter_probe())
  for
    (name, width) in [
      ("reset", 1),
      ("bus_request_ready", 1),
      ("bus_response_valid", 1),
      ("bus_response_tag", 32),
      ("bus_response_fault", 2),
      ("bus_response_data", 32),
      ("reader_response_ready", 1),
      ("engine_response_ready", 1),
    ] {
    arbiter_probe_put(simulator, name, width, 0UL)
  }
  for prefix in ["reader", "engine"] {
    for
      (field, width, value) in [
        ("valid", 1, 0UL),
        ("write", 1, 0UL),
        ("address", 32, 0UL),
        ("bytes", 3, 1UL),
        ("mask", 4, 1UL),
        ("data", 32, 0UL),
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
fn arbiter_probe_payload(simulator : @sim.Simulator) -> Array[UInt64] raise {
  ["write", "address", "bytes", "mask", "data", "tag"].map(field => {
    arbiter_probe_read(simulator, "request_" + field)
  })
}
