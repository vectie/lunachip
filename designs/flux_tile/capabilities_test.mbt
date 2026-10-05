///|
test "capability-driven elaboration preserves exact graph configuration and manifest values" {
  for
    (rows, columns, reduction, aperture, ring, queue) in [
      (1, 1, 1, 256UL, 2, 2),
      (2, 3, 5, 8192UL, 16, 3),
      (8, 8, 16, 4294967296UL, 4, 16),
    ] {
    let configuration = @capabilities.Capabilities::new(
      rows~,
      columns~,
      max_reduction=reduction,
      host_bytes=aperture,
      ring_depth=ring,
      queue_depth=queue,
    )
    let from_contract = @flux_tile.ring_concurrent_from_capabilities(
      configuration,
    )
    let existing = @flux_tile.ring_concurrent_tile(
      rows~,
      columns~,
      max_reduction=reduction,
      host_bytes=aperture,
      ring_depth=ring,
      queue_depth=queue,
    )
    assert_eq(
      @codec.serialize(@wire.single_design("Capabilities", from_contract)),
      @codec.serialize(@wire.single_design("Capabilities", existing)),
    )
    let parameters : Map[String, @ir.ParameterValue] = Map([])
    for parameter in from_contract.parameters() {
      parameters[parameter.name()] = parameter.value()
    }
    for
      (name, value) in [
        ("rows", rows),
        ("columns", columns),
        ("max_reduction", reduction),
        ("ring_depth", ring),
        ("queue_depth", queue),
        ("slot_count", 2),
      ] {
      assert_eq(parameters[name], Signed(value.to_int64()))
    }
    assert_eq(parameters["host_bytes"], Unsigned(aperture))
    let manifest = @json.parse(configuration.manifest())
    guard manifest is Object(fields) else {
      fail("capability manifest is not an object")
    }
    for
      (name, value) in [
        ("rows", rows),
        ("columns", columns),
        ("max_reduction", reduction),
        ("ring_depth", ring),
        ("queue_depth", queue),
        ("retirement_depth", queue),
      ] {
      assert_eq(fields[name], Json(value))
    }
    assert_eq(fields["host_bytes"], @json.parse("\{aperture}"))
  }
}

///|
test "Device ABI 1.0 binds the complete fetched concurrent signal names and exact types" {
  let configuration = @capabilities.Capabilities::new(
    rows=1,
    columns=1,
    max_reduction=1,
    host_bytes=1024UL,
    ring_depth=2,
    queue_depth=2,
  )
  let hardware = @flux_tile.ring_concurrent_from_capabilities(configuration)
  let inputs : Map[String, @ir.SignalType] = Map([])
  for node in hardware.nodes() {
    if node.kind() is Input(name) {
      inputs[name] = node.signal_type()
    }
  }
  let expected_inputs : Map[String, @ir.SignalType] = Map([
    ("clock", @wire.clock()),
    ("reset", @wire.reset()),
    ("config_valid", @wire.bits(1)),
    ("config_base", @wire.uint(32)),
    ("config_origin", @wire.uint(32)),
    ("publish_valid", @wire.bits(1)),
    ("publish_producer", @wire.uint(32)),
    ("completion_ready", @wire.bits(1)),
    ("memory_request_ready", @wire.bits(1)),
    ("memory_response_valid", @wire.bits(1)),
    ("memory_response_tag", @wire.uint(32)),
    ("memory_response_fault", @wire.uint(2)),
    ("memory_response_data", @wire.bits(32)),
  ])
  assert_eq(inputs, expected_inputs)
  let outputs : Map[String, @ir.SignalType] = Map([])
  for output in hardware.outputs() {
    outputs[output.name()] = output.signal_type()
  }
  let expected_outputs : Map[String, @ir.SignalType] = Map([])
  for
    name in [
      "config_ready", "publish_ready", "configured", "ring_fault_valid", "halted",
      "transport_halted", "completion_valid", "memory_request_valid", "memory_request_write",
      "memory_response_ready",
    ] {
    expected_outputs[name] = @wire.bits(1)
  }
  for
    name in [
      "producer_count", "consumer_count", "ring_fault_address", "transport_fault_address",
      "completion_id", "completion_bytes_completed", "completion_fault_address",
      "memory_request_address", "memory_request_tag",
    ] {
    expected_outputs[name] = @wire.uint(32)
  }
  for
    (name, width) in [
      ("ring_fault_code", 3),
      ("completion_fault", 4),
      ("queue_occupancy", 5),
      ("memory_request_bytes", 3),
      ("accepted_steps", 13),
      ("elapsed_cycles", 64),
      ("active_cycles", 64),
      ("stall_cycles", 64),
      ("capture_cycles", 7),
    ] {
    expected_outputs[name] = @wire.uint(width)
  }
  expected_outputs["memory_request_mask"] = @wire.bits(4)
  expected_outputs["memory_request_data"] = @wire.bits(32)
  assert_eq(outputs, expected_outputs)
}

///|
test "logical Device ABI version does not silently change descriptor encoding" {
  let host = PortableHost::new()
  let simulator = ring_concurrent_prepare(rows=1, columns=1, capacity=1)
  ring_concurrent_config(host, simulator)
  let correct = queued_concurrent_packet(Fence, 500)
  assert_eq(correct[0] & 65535UL, 512UL)
  let wrong_axis = correct.copy()
  wrong_axis[0] = (wrong_axis[0] & 18446744073709486080UL) | 1UL
  ring_concurrent_submit(host, simulator, 0UL, [wrong_axis, correct])
  queued_concurrent_drain(host, simulator, [
    [500UL, 12UL, 0UL, 0UL],
    [500UL, 0UL, 0UL, 0UL],
  ])
  assert_eq(execute_read(simulator, "consumer_count"), 2UL)
}
