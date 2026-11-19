///|
fn begin_read_ahead(b : BridgeBench) -> Unit raise {
  set(b.sim, "request_wide", 1, 1UL)
  b.begin_line(0UL, burst=true, header=0x80000100UL)
  set(b.sim, "request_wide", 1, 0UL)
  set(b.sim, "request_data", 32, 0UL)
}

///|
fn read_ahead_pattern(b : BridgeBench) -> Unit {
  for line in 0..<b.memory.length() {
    for word in 0..<4 {
      b.memory[line][word] = 0xa0000000U +
        (line * 4 + word).reinterpret_as_uint()
    }
  }
}

///|
fn check_read_ahead_packet(
  b : BridgeBench,
  i : Int32,
  hold? : Int32,
) -> Unit raise {
  let packets_per_row = 32 / b.packet_words
  let base = (i / packets_per_row * 64 + i % packets_per_row * b.packet_words).to_uint64()
  assert_eq(
    wide_packet(b, hold.unwrap_or(i % 7)),
    [
      ..Array::makei(b.packet_words, word => {
        0xa0000000UL + base + word.to_uint64()
      }),
      0UL,
      if i == b.group_rows * packets_per_row - 1 {
        1UL
      } else {
        0UL
      },
    ],
  )
}

///|
fn read_ahead_bridge_replay(b : BridgeBench) -> Unit raise {
  let original = b.memory.map(a => a.copy())
  let packets = b.group_rows * 32 / b.packet_words
  if b.packet_words == 8 {
    rejected_wide_owner_replay(b)
  }
  read_ahead_pattern(b)
  // Every packet boundary, including each row transition, can be discarded
  // by coordinated reset without leaking an old response into the next owner.
  for prefix in 0..<=packets {
    begin_read_ahead(b)
    for i in 0..<prefix {
      check_read_ahead_packet(b, i) catch {
        e =>
          fail(
            "Reset prefix " +
            prefix.to_string() +
            " packet " +
            i.to_string() +
            ": " +
            Repr(e).to_string(),
          )
      }
    }
    b.reset()
    assert_eq(b.transaction(1020UL), (0xa00000ffUL, 0UL))
  }
  for
    (address, header) in [
      (0UL, 0x80000000UL),
      (0UL, 0x80000084UL),
      (0UL, 0x90000100UL),
      // Seven strides overflow the old 30-bit four-row extent geometry.
      (0UL, 0x89249280UL),
      (0xfffff80UL, 0x80000080UL),
    ] {
    let reads = b.reads.length()
    set(b.sim, "request_wide", 1, 1UL)
    b.begin_line(address, burst=true, header~)
    set(b.sim, "request_wide", 1, 0UL)
    for i in 0..<packets {
      let packet = wide_packet(b, 2) catch {
        e =>
          fail(
            "Rejected header " +
            header.to_string() +
            " packet " +
            i.to_string() +
            ": " +
            Repr(e).to_string(),
          )
      }
      assert_eq(
        packet,
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
    assert_eq(b.reads.length(), reads)
  }
  // Inject malformed returns while commands are actually outstanding. A
  // fully prefetched buffer need not have any native returns left after row0.
  b.reset()
  b.read_delay = 120
  begin_read_ahead(b)
  for _ in 0..<400 {
    if b.reads.length() >= 16 {
      break
    }
    b.step()
  }
  assert_true(b.reads.length() >= 16 && b.read_head == 0)
  b.environment(bad_end=true)
  let mut failed = false
  for i in 0..<packets {
    let packet = wide_packet(b, 2) catch {
      e =>
        fail(
          "Malformed native return packet " +
          i.to_string() +
          ": " +
          Repr(e).to_string(),
        )
    }
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
  b.read_delay = 3
  for i, words in original {
    for j, word in words {
      b.memory[i][j] = word
    }
  }
}

///|
fn rejected_wide_owner_replay(b : BridgeBench) -> Unit raise {
  for
    (address, header) in [
      (16UL, 0UL),
      (0UL, 0x80000000UL),
      (0xfffff80UL, 0x80000080UL),
    ] {
    b.reset()
    set(b.sim, "request_wide", 1, 1UL)
    b.begin_line(address, burst=true, header~)
    set(b.sim, "request_wide", 1, 0UL)
    let packets = (if (header & 0x80000000UL) != 0UL {
        b.group_rows * 32
      } else {
        32
      }) /
      b.packet_words
    for i in 0..<packets {
      assert_eq(
        wide_packet(b, i % 5),
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
    assert_eq(b.reads.length(), 0)
    set(b.sim, "request_burst", 1, 0UL)
    let first = [0x12345678UL, 0x89abcdefUL, 0x76543210UL, 0xfedcba98UL]
    b.write_line(64UL, first)
    b.write_line(80UL, [1UL, 2UL, 3UL, 4UL])
    assert_eq(b.memory[4], first.map(w => w.to_uint()))
    assert_eq(b.memory[5], [1U, 2U, 3U, 4U])
  }
}
