///|
test "50/100MHz atomic FIFO bridge, native masks, byte units and held responses" {
  let b = bridge_bench()
  for lane in 0..<4 {
    assert_eq(
      b.transaction(
        lane.to_uint64() * 4UL,
        word=0x10203040UL + lane.to_uint64(),
        hold=9,
      ),
      (0UL, 0UL),
    )
  }
  for lane in 0..<4 {
    assert_eq(b.memory[0][lane], 0x10203040U + lane.reinterpret_as_uint())
    assert_eq(
      b.transaction(lane.to_uint64() * 4UL, hold=7),
      (0x10203040UL + lane.to_uint64(), 0UL),
    )
  }
  assert_eq(b.transaction(1020UL, word=0x89abcdefUL), (0UL, 0UL))
  assert_eq(b.transaction(1020UL), (0x89abcdefUL, 0UL))
  assert_eq(b.transaction(1UL, word=1UL), (0UL, 1UL))
  assert_eq(value(b.sim, "memory_healthy"), 1UL)
}

///|
test "malformed native read-end poisons bridge until coordinated physical reset" {
  let b = bridge_bench()
  assert_eq(b.transaction(0UL, word=123UL), (0UL, 0UL))
  b.environment(bad_end=true)
  assert_eq(b.transaction(0UL), (0UL, 3UL))
  for _ in 0..<12 {
    b.step()
  }
  assert_eq(value(b.sim, "memory_healthy"), 0UL)
  assert_eq(value(b.sim, "app_en"), 0UL)
  b.environment()
  b.reset()
  assert_eq(b.transaction(0UL), (123UL, 0UL))
}

///|
test "calibration loss cancels an owned native request without false success" {
  let b = bridge_bench()
  b.environment(paused=true)
  set(b.sim, "request_address", 28, 0UL)
  set(b.sim, "request_write", 1, 0UL)
  set(b.sim, "request_valid", 1, 1UL)
  set(b.sim, "response_ready", 1, 0UL)
  for _ in 0..<80 {
    b.step()
    if b.accepted {
      break
    }
  }
  assert_true(b.accepted)
  set(b.sim, "request_valid", 1, 0UL)
  for _ in 0..<80 {
    b.step()
    if value(b.sim, "app_en") == 1UL {
      break
    }
  }
  assert_eq(value(b.sim, "app_en"), 1UL)
  set(b.sim, "calibrated", 1, 0UL)
  for _ in 0..<80 {
    b.step()
    if value(b.sim, "response_valid") == 1UL {
      break
    }
  }
  assert_eq(value(b.sim, "response_valid"), 1UL)
  assert_eq(value(b.sim, "response_fault"), 2UL)
  assert_eq(value(b.sim, "app_en"), 0UL)
  assert_eq(value(b.sim, "app_wdf_wren"), 0UL)
  set(b.sim, "response_ready", 1, 1UL)
  for _ in 0..<4 {
    b.step()
  }
  b.environment()
  b.reset()
  assert_eq(b.transaction(0UL), (0UL, 0UL))
}

///|
test "one native read supplies four source lanes; all writes invalidate cached data" {
  let b = bridge_bench()
  for i in 0..<8 {
    assert_eq(
      b.transaction(i.to_uint64() * 4UL, word=0x89abc000UL + i.to_uint64()),
      (0UL, 0UL),
    )
  }
  let before = b.reads.length()
  for lane in [3, 0, 2, 1, 3, 0] {
    assert_eq(
      b.transaction(lane.to_uint64() * 4UL, hold=11),
      (0x89abc000UL + lane.to_uint64(), 0UL),
    )
  }
  assert_eq(b.reads.length(), before + 1)
  assert_eq(b.transaction(16UL), (0x89abc004UL, 0UL))
  assert_eq(b.reads.length(), before + 2)
  // Even an unrelated write conservatively invalidates the entire read line.
  assert_eq(b.transaction(0UL, word=0xdeadbeefUL), (0UL, 0UL))
  assert_eq(b.transaction(20UL), (0x89abc005UL, 0UL))
  assert_eq(b.reads.length(), before + 3)
  assert_eq(b.transaction(20UL, word=0x80000001UL), (0UL, 0UL))
  assert_eq(b.transaction(20UL), (0x80000001UL, 0UL))
  assert_eq(b.reads.length(), before + 4)
  assert_eq(b.transaction(16UL), (0x89abc004UL, 0UL))
  assert_eq(b.reads.length(), before + 4)
  // Physical reset drops a valid line and cannot return its old payload.
  b.reset()
  assert_eq(b.transaction(20UL), (0x80000001UL, 0UL))
  assert_eq(b.reads.length(), 1)
}

///|
test "cache hit response owns source until consumed and synchronized health invalidates line" {
  let b = bridge_bench()
  assert_eq(b.transaction(0UL, word=77UL), (0UL, 0UL))
  assert_eq(b.transaction(0UL), (77UL, 0UL))
  let before = b.reads.length()
  set(b.sim, "request_valid", 1, 1UL)
  set(b.sim, "request_address", 28, 0UL)
  set(b.sim, "request_write", 1, 0UL)
  set(b.sim, "response_ready", 1, 0UL)
  b.accepted = false
  for _ in 0..<4 {
    b.step()
    if b.accepted {
      break
    }
  }
  assert_true(b.accepted)
  set(b.sim, "request_address", 28, 16UL)
  for _ in 0..<16 {
    b.step()
    assert_eq(value(b.sim, "request_ready"), 0UL)
    assert_eq(value(b.sim, "response_valid"), 1UL)
    assert_eq(value(b.sim, "response_data"), 77UL)
  }
  set(b.sim, "request_valid", 1, 0UL)
  set(b.sim, "calibrated", 1, 0UL)
  for _ in 0..<12 {
    b.step()
  }
  assert_eq(value(b.sim, "memory_healthy"), 0UL)
  assert_eq(value(b.sim, "response_data"), 77UL) // held response is immutable
  set(b.sim, "response_ready", 1, 1UL)
  b.result = None
  for _ in 0..<4 {
    b.step()
    if b.result is Some(_) {
      break
    }
  }
  set(b.sim, "response_ready", 1, 0UL)
  assert_eq(b.reads.length(), before)
  assert_eq(b.transaction(0UL), (0UL, 2UL))
  assert_eq(b.reads.length(), before)
}

///|
test "coordinated reset during a partial line fill discards all stale response flits" {
  let b = bridge_bench()
  for lane in 0..<4 {
    assert_eq(
      b.transaction(lane.to_uint64() * 4UL, word=91UL + lane.to_uint64()),
      (0UL, 0UL),
    )
  }
  let (_, observations) = @projection.bridge_evidence()
  let lane_node = observations
    .iter()
    .find_first(o => o.name == "receive_lane")
    .unwrap().node
  b.accepted = false
  set(b.sim, "request_valid", 1, 1UL)
  set(b.sim, "request_address", 28, 0UL)
  set(b.sim, "request_write", 1, 0UL)
  set(b.sim, "response_ready", 1, 0UL)
  for _ in 0..<100 {
    b.step()
    if b.accepted {
      break
    }
  }
  assert_true(b.accepted)
  set(b.sim, "request_valid", 1, 0UL)
  for _ in 0..<100 {
    b.step()
    if b.sim.value(lane_node).value_bits() == 1UL {
      break
    }
  }
  assert_eq(b.sim.value(lane_node).value_bits(), 1UL)
  assert_eq(value(b.sim, "response_valid"), 0UL)
  b.reset()
  for lane in [3, 1, 0, 2] {
    assert_eq(
      b.transaction(lane.to_uint64() * 4UL, hold=3),
      (91UL + lane.to_uint64(), 0UL),
    )
  }
  assert_eq(b.reads.length(), 1)
}

///|
test "one UI-clock calibration-loss pulse while idle poisons an existing cache until reset" {
  let b = bridge_bench()
  assert_eq(b.transaction(0UL, word=119UL), (0UL, 0UL))
  assert_eq(b.transaction(0UL), (119UL, 0UL))
  // Deliberately place the entire loss pulse between slow-domain edges.
  if b.tick % 2 == 0 {
    b.step()
  }
  set(b.sim, "calibrated", 1, 0UL)
  b.step()
  set(b.sim, "calibrated", 1, 1UL)
  for _ in 0..<16 {
    b.step()
  }
  assert_eq(value(b.sim, "memory_healthy"), 0UL)
  assert_eq(value(b.sim, "bridge_poisoned"), 1UL)
  assert_eq(b.transaction(0UL), (0UL, 2UL))
  b.reset()
  assert_eq(b.transaction(0UL), (119UL, 0UL))
}
