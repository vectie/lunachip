///|
fn wide_packet(b : BridgeBench, hold : Int32) -> Array[UInt64] raise {
  set(b.sim, "response_ready", 1, 0UL)
  for _ in 0..<400 {
    if value(b.sim, "response_valid") == 1UL {
      break
    }
    b.step()
  }
  assert_eq(value(b.sim, "response_valid"), 1UL)
  let words = Array::makei(b.packet_words, i => {
    value(
      b.sim,
      if i == 0 {
        "response_data"
      } else {
        "response_data" + i.to_string()
      },
    )
  })
  for _ in 0..<hold {
    b.step()
    for i in 0..<b.packet_words {
      assert_eq(
        value(
          b.sim,
          if i == 0 {
            "response_data"
          } else {
            "response_data" + i.to_string()
          },
        ),
        words[i],
      )
    }
  }
  let (data, fault, last) = b.line_beat(hold)
  assert_eq(data, words[0])
  [..words, fault, last]
}

///|
fn wide_bridge_replay(b : BridgeBench) -> Unit raise {
  let original = b.memory.map(words => words.copy())
  for line in 0..<8 {
    for word in 0..<4 {
      b.memory[line][word] = 0x80000000U +
        (line * 4 + word).reinterpret_as_uint()
    }
  }
  let packets = 32 / b.packet_words
  for prefix in [0, 1, packets - 1, packets] {
    set(b.sim, "request_wide", 1, 1UL)
    b.read_delay = 60
    b.begin_line(0UL, burst=true)
    set(b.sim, "request_wide", 1, 0UL)
    for _ in 0..<200 {
      b.step()
    }
    assert_eq(b.max_outstanding.val, 8)
    for line in 0..<prefix {
      assert_eq(
        wide_packet(b, line % 7),
        [
          ..Array::makei(b.packet_words, word => {
            0x80000000UL + (line * b.packet_words + word).to_uint64()
          }),
          0UL,
          if line == packets - 1 {
            1UL
          } else {
            0UL
          },
        ],
      )
    }
    b.reset()
    assert_eq(b.transaction(124UL), (0x8000001fUL, 0UL))
  }
  for address in [16UL, 112UL] {
    set(b.sim, "request_wide", 1, 1UL)
    b.begin_line(address, burst=true)
    set(b.sim, "request_wide", 1, 0UL)
    for i in 0..<packets {
      assert_eq(
        wide_packet(b, 2),
        [
          ..Array::make(b.packet_words, 0UL),
          1UL,
          if i == packets - 1 {
            1UL
          } else {
            0UL
          },
        ],
      )
    }
  }
  set(b.sim, "request_wide", 1, 1UL)
  b.begin_line(0UL, burst=true)
  set(b.sim, "request_wide", 1, 0UL)
  b.environment(bad_end=true)
  let mut failed = false
  for i in 0..<packets {
    let packet = wide_packet(b, 2)
    if packet[b.packet_words] != 0UL {
      failed = true
    }
    assert_eq(
      packet[b.packet_words + 1],
      if i == packets - 1 {
        1UL
      } else {
        0UL
      },
    )
  }
  assert_true(failed)
  b.environment()
  b.reset()
  for i, words in original {
    for j, word in words {
      b.memory[i][j] = word
    }
  }
}
