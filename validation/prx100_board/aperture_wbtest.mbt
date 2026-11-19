///|
fn mock_shell() -> @sim.Simulator raise {
  let hardware = @prx100.byte_shell(Smoke)
  let sim = @sim.Simulator::prepare(hardware)
  for node in hardware.nodes() {
    if node.kind() is Input(name) {
      drive(sim, name, node.signal_type().width().bits(), 0UL)
    }
  }
  drive(sim, "reset", 1, 1UL)
  sim.rising_edge("clock")
  drive(sim, "reset", 1, 0UL)
  sim.rising_edge("clock")
  sim
}

///|
fn dma_request(
  sim : @sim.Simulator,
  address : UInt64,
  write : Bool,
  data : UInt64,
  tag : UInt64,
) -> Unit raise {
  drive(sim, "c_memory_request_valid", 1, 1UL)
  drive(sim, "c_memory_request_write", 1, if write { 1UL } else { 0UL })
  drive(sim, "c_memory_request_address", 32, address)
  drive(sim, "c_memory_request_data", 32, data)
  drive(sim, "c_memory_request_tag", 32, tag)
  drive(sim, "c_memory_request_mask", 4, if write { 15UL } else { 1UL })
  drive(sim, "c_memory_request_bytes", 3, if write { 4UL } else { 1UL })
  sim.settle()
  assert_eq(read(sim, "memory_request_ready"), 1UL)
  sim.rising_edge("clock")
  drive(sim, "c_memory_request_valid", 1, 0UL)
  sim.settle()
}

///|
test "local memory retains tag/data under backpressure and flushes pending response on reset" {
  let sim = mock_shell()
  dma_request(sim, 4092UL, true, 0xaabbccddUL, 99UL)
  assert_eq(read(sim, "memory_response_valid"), 1UL)
  for _ in 0..<10 {
    assert_eq(read(sim, "memory_request_ready"), 0UL)
    assert_eq(read(sim, "memory_response_tag"), 99UL)
    assert_eq(read(sim, "memory_response_fault"), 0UL)
    sim.rising_edge("clock")
  }
  drive(sim, "c_memory_response_ready", 1, 1UL)
  sim.rising_edge("clock")
  drive(sim, "c_memory_response_ready", 1, 0UL)
  dma_request(sim, 4093UL, false, 0UL, 100UL)
  assert_eq(read(sim, "memory_response_data"), 0xccUL)
  for _ in 0..<10 {
    sim.rising_edge("clock")
    assert_eq(read(sim, "memory_response_data"), 0xccUL)
  }
  drive(sim, "reset", 1, 1UL)
  sim.settle()
  assert_eq(read(sim, "memory_response_valid"), 0UL)
  assert_eq(read(sim, "memory_request_ready"), 0UL)
  sim.rising_edge("clock")
  drive(sim, "reset", 1, 0UL)
  dma_request(sim, 4092UL, false, 0UL, 0UL)
  assert_eq(read(sim, "memory_response_data"), 0xddUL)
  drive(sim, "c_memory_response_ready", 1, 1UL)
  sim.rising_edge("clock")
  drive(sim, "c_memory_response_ready", 1, 0UL)
  dma_request(sim, 0xfffffffcUL, true, 0UL, 1UL)
  assert_eq(read(sim, "memory_response_fault"), 1UL)
  drive(sim, "c_memory_response_ready", 1, 1UL)
  sim.rising_edge("clock")
  drive(sim, "c_memory_response_ready", 1, 0UL)
  dma_request(sim, 4092UL, false, 0UL, 2UL)
  assert_eq(read(sim, "memory_response_data"), 0xddUL)
}

///|
test "serial framing error discards partial write without side effects" {
  let sim = mock_shell()
  let frame = @prx100.request(1, 1, 0U, 99U)
  drive(sim, "rx_valid", 1, 1UL)
  for byte in frame[:10] {
    drive(sim, "rx_data", 8, byte.to_uint64())
    sim.rising_edge("clock")
  }
  drive(sim, "rx_error", 1, 1UL)
  sim.rising_edge("clock")
  drive(sim, "rx_error", 1, 0UL)
  for byte in frame[10:] {
    drive(sim, "rx_data", 8, byte.to_uint64())
    sim.rising_edge("clock")
  }
  drive(sim, "rx_valid", 1, 0UL)
  for _ in 0..<20 {
    sim.rising_edge("clock")
    assert_eq(read(sim, "tx_valid"), 0UL)
  }
  assert_true(sim.memory_cell("host_aperture", 0).is_fully_unknown())
}

///|
test "typed replay rejects a value mutation with original identity intact" {
  let bundle = generate_byte_bundle()
  let expected = bundle.filter(a => a.path == "expected.tsv")[0].content
  let altered = expected.replace(old="\n1\ta5\t0\n", new="\n1\ta4\t0\n")
  assert_true(altered != expected)
  let cycles = expected.split("\n").count() - 3
  let wanted = @verilator.parse_actual_tsv(
    expected,
    ports(),
    cycles,
    protocol(),
  )
  let observed = @verilator.parse_actual_tsv(
    altered,
    ports(),
    cycles,
    protocol(),
  )
  match @differential.compare(wanted, observed) {
    Mismatch(mismatch) => {
      guard mismatch.kind() is ValueMismatch(..) else {
        fail("expected value mismatch")
      }
    }
    Equal => fail("mutation escaped comparator")
  }
}
