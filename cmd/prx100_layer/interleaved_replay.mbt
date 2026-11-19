///|
// Actual-core stimuli include tails, aliases, exact partial-write faults,
// ignored busy host traffic, and interruption of every new controller state.
fn interleaved_replay(r : Replay) -> Unit raise {
  fn reset() -> Unit raise {
    r.set("reset", 1, 1UL)
    r.step()
    r.set("reset", 1, 0UL)
    r.set("memory_healthy", 1, 1UL)
    r.set("start", 1, 0UL)
    r.set("scratch_read", 1, 0UL)
    r.set("scratch_write", 1, 0UL)
    r.set("program_write", 1, 0UL)
    r.set("ddr_response_valid", 1, 0UL)
  }
  fn prepare(
    op : UInt32,
    dst : Int32,
    n : Int32,
    bad : Int32,
  ) -> Array[UInt32] raise {
    reset()
    let data = Array::makei(64, i => {
      if bad >= 0 && i == bad + 8 {
        0x7fc00000U
      } else {
        Float::from_double(0.5 + i.to_double() / 32.0).reinterpret_as_uint()
      }
    })
    r.set("scratch_write", 1, 1UL)
    for i, value in data {
      r.set("scratch_address", 15, i.to_uint64())
      r.set("scratch_data", 32, value.to_uint64())
      r.step()
    }
    r.set("scratch_write", 1, 0UL)
    let words = [
      op,
      dst.reinterpret_as_uint(),
      8U,
      0U,
      n.reinterpret_as_uint(),
      0U,
      1U,
      0U,
      0U,
      0U,
      0U,
      0U,
      0U,
      0U,
      0U,
      0U,
      ..Array::make(16, 0U),
    ]
    r.set("program_write", 1, 1UL)
    for i, word in words {
      r.set("program_address", 15, i.to_uint64())
      r.set("program_data", 32, word.to_uint64())
      r.step()
    }
    r.set("program_write", 1, 0UL)
    r.set("program_count", 12, 2UL)
    r.set("start", 1, 1UL)
    r.step()
    r.set("start", 1, 0UL)
    data
  }
  fn check(data : Array[UInt32]) -> Unit raise {
    r.set("scratch_write", 1, 0UL)
    r.set("program_write", 1, 0UL)
    reset()
    r.set("scratch_read", 1, 1UL)
    for i, value in data {
      r.set("scratch_read_address", 15, i.to_uint64())
      r.step()
      assert_eq(r.get("scratch_read_valid"), 1UL)
      assert_eq(r.get("scratch_read_data"), value.to_uint64())
    }
    r.set("scratch_read", 1, 0UL)
  }
  for op in [9U, 10U, 11U] {
    for
      (dst, n, bad) in [
        (32, 1, -1),
        (32, 3, -1),
        (32, 4, -1),
        (32, 9, -1),
        (8, 9, -1),
        (7, 9, -1),
        (9, 9, -1),
        (32, 9, 0),
        (32, 9, 3),
        (32, 9, 4),
        (32, 9, 8),
        (8, 9, 6),
      ] {
      let data = prepare(op, dst, n, bad)
      let mut expected_error = 0UL
      for i in 0..<n {
        let bits = data[8 + i]
        let magnitude = bits & 0x7fffffffU
        let valid = if op == 11U {
          magnitude <= 0x7f800000U
        } else {
          bits >> 31 == 0U &&
          magnitude >= 0x1f800000U &&
          magnitude <= 0x5f800000U
        }
        if !valid {
          expected_error = 3UL
          break
        }
        data[dst + i] = approximate_unary(
          op,
          Float::reinterpret_from_uint(bits),
        ).reinterpret_as_uint()
      }
      r.set("scratch_write", 1, 1UL)
      r.set("scratch_address", 15, 63UL)
      r.set("scratch_data", 32, 0xdeadbeefUL)
      r.set("program_write", 1, 1UL)
      r.set("program_data", 32, 0xffffffffUL)
      r.set("start", 1, 1UL)
      let mut cycles = 0
      while r.get("busy") == 1UL && cycles < 2000 {
        r.step()
        cycles += 1
      }
      r.set("scratch_write", 1, 0UL)
      r.set("program_write", 1, 0UL)
      r.set("start", 1, 0UL)
      assert_true(cycles < 2000)
      assert_eq(r.get("error"), expected_error)
      for _ in 0..<100 {
        r.step()
        assert_eq(r.get("error"), expected_error)
      }
      check(data)
    }
  }
  for state in 24UL..<29UL {
    for health in [false, true] {
      let data = prepare(11U, 32, 9, -1)
      let mut cycles = 0
      while r.get("state") != state && cycles < 300 {
        r.step()
        cycles += 1
      }
      assert_true(cycles < 300)
      r.set(
        if health {
          "memory_healthy"
        } else {
          "reset"
        },
        1,
        if health {
          0UL
        } else {
          1UL
        },
      )
      r.step()
      r.set("reset", 1, 0UL)
      for _ in 0..<100 {
        assert_eq(r.get("busy"), 0UL)
        assert_eq(r.get("ddr_request_valid"), 0UL)
        assert_eq(r.get("fault"), if health { 1UL } else { 0UL })
        assert_eq(r.get("error"), if health { 8UL } else { 0UL })
        r.step()
      }
      check(data)
    }
  }
}
