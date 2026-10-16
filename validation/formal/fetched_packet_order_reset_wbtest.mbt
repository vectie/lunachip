///|
test "fetched packet response reset suppresses capture without initializing storage" {
  let sequential = fetched_transport_sequential()
  let source = sequential.probe.source
  let simulator = @sim.Simulator::prepare(source)
  let history = FetchedPacketNative::new(source)
  for node in source.nodes() {
    if node.kind() is Input(name) && name != "clock" {
      records_put(simulator, name, node.signal_type().width().bits(), 0UL)
    }
  }
  let packet = fetched_useful_packet(0)
  let mut configured = false
  let mut published = false
  let mut pending : FetchedUsefulNativeRequest? = None
  let mut interrupted = false
  for edge in 0..<800 {
    let reset = edge == 0
    let response = pending
      .map(request => {
        let offset = request.address.to_int()
        (packet[offset / 8] >> (offset % 8 * 8)) & 255UL
      })
      .unwrap_or(0UL)
    for
      (name, width, value) in [
        ("reset", 1, if reset { 1UL } else { 0UL }),
        ("config_valid", 1, if !reset && !configured { 1UL } else { 0UL }),
        (
          "publish_valid",
          1,
          if !reset && configured && !published {
            1UL
          } else {
            0UL
          },
        ),
        ("publish_producer", 32, 1UL),
        ("memory_request_ready", 1, 1UL),
        ("memory_response_valid", 1, if pending is Some(_) { 1UL } else { 0UL }),
        (
          "memory_response_tag",
          32,
          pending.map(request => request.tag).unwrap_or(0UL),
        ),
        ("memory_response_data", 32, response),
      ] {
      records_put(simulator, name, width, value)
    }
    simulator.settle()
    if !reset && history.role(simulator, HeadState) == 1UL {
      assert_eq(history.role(simulator, HeadCapture), 1UL)
      let cells = []
      let reads = []
      for memory in source.memories() {
        for slot in 0..<memory.depth().elements() {
          cells.push(simulator.memory_cell(memory.name(), slot))
        }
        for read in memory.read_ports() {
          reads.push(simulator.value(read.result()))
        }
      }
      records_put(simulator, "reset", 1, 1UL)
      simulator.settle()
      assert_eq(history.role(simulator, HeadCapture), 0UL)
      assert_eq(history.role(simulator, HeadPop), 0UL)
      history.step(simulator, true)
      simulator.rising_edge("clock")
      simulator.settle()
      history.check(simulator)
      let mut cell_index = 0
      let mut read_index = 0
      for memory in source.memories() {
        for slot in 0..<memory.depth().elements() {
          assert_eq(
            simulator.memory_cell(memory.name(), slot),
            cells[cell_index],
          )
          cell_index += 1
        }
        for read in memory.read_ports() {
          assert_eq(simulator.value(read.result()), reads[read_index])
          read_index += 1
        }
      }
      interrupted = true
      break
    }
    if !reset {
      if !configured && records_output(simulator, "config_ready") == 1UL {
        configured = true
      } else if configured &&
        !published &&
        records_output(simulator, "publish_ready") == 1UL {
        published = true
      }
      if pending is Some(_) {
        assert_eq(records_output(simulator, "memory_response_ready"), 1UL)
        pending = None
      } else if records_output(simulator, "memory_request_valid") == 1UL {
        let address = records_output(simulator, "memory_request_address")
        assert_true(address < 32UL)
        pending = Some({
          tag: records_output(simulator, "memory_request_tag"),
          address,
          write: false,
          bytes: 1UL,
          mask: 1UL,
          data: 0UL,
        })
      }
    }
    history.step(simulator, reset)
    simulator.rising_edge("clock")
    simulator.settle()
    history.check(simulator)
  }
  assert_true(interrupted)
}
