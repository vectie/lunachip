///|
fn word_loader_prepare() -> @sim.Simulator raise {
  let hardware = word_loader_verification_fixture()
  let sim = @sim.Simulator::prepare(hardware)
  for node in hardware.nodes() {
    if node.kind() is Input(name) && name != "clock" {
      arbiter_probe_put(sim, name, node.signal_type().width().bits(), 0UL)
    }
  }
  arbiter_probe_put(sim, "reset", 1, 1UL)
  sim.rising_edge("clock")
  arbiter_probe_put(sim, "reset", 1, 0UL)
  sim
}

///|
fn word_loader_begin(
  sim : @sim.Simulator,
  columns~ : UInt64 = 4UL,
) -> Unit raise {
  for
    (name, width, value) in [
      ("load_command_valid", 1, 1UL),
      ("load_command_rows", 13, 1UL),
      ("load_command_columns", 13, columns),
      ("load_command_base", 32, 256UL),
      ("load_command_stride", 32, columns),
      ("load_command_id", 32, 19UL),
    ] {
    arbiter_probe_put(sim, name, width, value)
  }
  sim.rising_edge("clock")
  arbiter_probe_put(sim, "load_command_valid", 1, 0UL)
  assert_eq(arbiter_probe_read(sim, "request_valid"), 1UL)
  assert_eq(arbiter_probe_read(sim, "request_bytes"), 4UL)
  arbiter_probe_put(sim, "request_ready", 1, 1UL)
  sim.rising_edge("clock")
  assert_eq(arbiter_probe_read(sim, "response_ready"), 1UL)
}

///|
test "later word failure retains the committed prefix and poison cancels buffered bytes" {
  let sim = word_loader_prepare()
  word_loader_begin(sim, columns=8UL)
  arbiter_probe_put(sim, "response_valid", 1, 1UL)
  arbiter_probe_put(sim, "response_data", 32, 0x807fff01UL)
  sim.rising_edge("clock")
  arbiter_probe_put(sim, "response_valid", 1, 0UL)
  arbiter_probe_put(sim, "a_ready", 1, 1UL)
  for _ in 0..<4 {
    sim.rising_edge("clock")
  }
  assert_eq(arbiter_probe_read(sim, "progress"), 4UL)
  assert_eq(arbiter_probe_read(sim, "request_address"), 260UL)
  sim.rising_edge("clock")
  arbiter_probe_put(sim, "response_tag", 32, 1UL)
  arbiter_probe_put(sim, "response_fault", 2, 1UL)
  arbiter_probe_put(sim, "response_valid", 1, 1UL)
  sim.rising_edge("clock")
  assert_eq(arbiter_probe_read(sim, "state"), 4UL)
  assert_eq(arbiter_probe_read(sim, "progress"), 4UL)
  assert_eq(arbiter_probe_read(sim, "fault"), 9UL)
  assert_eq(arbiter_probe_read(sim, "fault_address"), 260UL)
  let sim = word_loader_prepare()
  word_loader_begin(sim)
  arbiter_probe_put(sim, "response_valid", 1, 1UL)
  arbiter_probe_put(sim, "response_data", 32, 0x807fff01UL)
  sim.rising_edge("clock")
  arbiter_probe_put(sim, "response_valid", 1, 0UL)
  arbiter_probe_put(sim, "a_ready", 1, 1UL)
  sim.rising_edge("clock")
  arbiter_probe_put(sim, "poison", 1, 1UL)
  assert_eq(arbiter_probe_read(sim, "a_valid"), 0UL)
  sim.rising_edge("clock")
  assert_eq(arbiter_probe_read(sim, "state"), 4UL)
  assert_eq(arbiter_probe_read(sim, "progress"), 1UL)
  assert_eq(arbiter_probe_read(sim, "fault"), 15UL)
}

///|
test "production word loader holds each buffered signed lane until the bank accepts" {
  let sim = word_loader_prepare()
  word_loader_begin(sim)
  arbiter_probe_put(sim, "response_data", 32, 0x807fff01UL)
  arbiter_probe_put(sim, "response_valid", 1, 1UL)
  sim.rising_edge("clock")
  arbiter_probe_put(sim, "response_valid", 1, 0UL)
  for i, byte in [1UL, 255UL, 127UL, 128UL] {
    arbiter_probe_put(sim, "a_ready", 1, 0UL)
    for _ in 0..<4 {
      assert_eq(arbiter_probe_read(sim, "a_valid"), 1UL)
      assert_eq(arbiter_probe_read(sim, "data"), byte)
      assert_eq(arbiter_probe_read(sim, "column"), i.to_uint64())
      assert_eq(arbiter_probe_read(sim, "progress"), i.to_uint64())
      assert_eq(arbiter_probe_read(sim, "remaining"), (3 - i).to_uint64())
      assert_eq(arbiter_probe_read(sim, "request_valid"), 0UL)
      sim.rising_edge("clock")
    }
    arbiter_probe_put(sim, "a_ready", 1, 1UL)
    sim.rising_edge("clock")
  }
  assert_eq(arbiter_probe_read(sim, "state"), 4UL)
  assert_eq(arbiter_probe_read(sim, "progress"), 4UL)
  assert_eq(arbiter_probe_read(sim, "fault"), 0UL)
  assert_eq(arbiter_probe_read(sim, "completion_id"), 19UL)
}

///|
test "word response failure commits no bytes and reset discards a partial buffer" {
  for fault in [1UL, 2UL, 3UL] {
    let sim = word_loader_prepare()
    word_loader_begin(sim)
    arbiter_probe_put(sim, "response_valid", 1, 1UL)
    arbiter_probe_put(sim, "response_fault", 2, fault)
    arbiter_probe_put(sim, "response_data", 32, 0xffffffffUL)
    sim.rising_edge("clock")
    assert_eq(arbiter_probe_read(sim, "state"), 4UL)
    assert_eq(arbiter_probe_read(sim, "progress"), 0UL)
    assert_eq(arbiter_probe_read(sim, "a_valid"), 0UL)
    assert_eq(
      arbiter_probe_read(sim, "fault"),
      if fault == 1UL {
        9UL
      } else {
        10UL
      },
    )
    assert_eq(arbiter_probe_read(sim, "fault_address"), 256UL)
  }
  let sim = word_loader_prepare()
  word_loader_begin(sim)
  arbiter_probe_put(sim, "response_valid", 1, 1UL)
  arbiter_probe_put(sim, "response_data", 32, 0xdeadbeefUL)
  sim.rising_edge("clock")
  arbiter_probe_put(sim, "response_valid", 1, 0UL)
  arbiter_probe_put(sim, "a_ready", 1, 1UL)
  sim.rising_edge("clock")
  assert_eq(arbiter_probe_read(sim, "remaining"), 2UL)
  arbiter_probe_put(sim, "reset", 1, 1UL)
  assert_eq(arbiter_probe_read(sim, "a_valid"), 0UL)
  sim.rising_edge("clock")
  arbiter_probe_put(sim, "reset", 1, 0UL)
  assert_eq(arbiter_probe_read(sim, "remaining"), 0UL)
  assert_eq(arbiter_probe_read(sim, "word"), 0UL)
  assert_eq(arbiter_probe_read(sim, "progress"), 0UL)
  word_loader_begin(sim)
  assert_eq(arbiter_probe_read(sim, "request_tag"), 1UL)
}
