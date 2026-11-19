///|
fn BridgeBench::begin_write_line(
  self : BridgeBench,
  address : UInt64,
  words : ArrayView[UInt64],
) -> Unit raise {
  assert_eq(words.length(), 4)
  self.accepted = false
  self.result = None
  self.results.clear()
  set(self.sim, "request_line", 1, 1UL)
  set(self.sim, "request_write", 1, 1UL)
  set(self.sim, "request_address", 28, address)
  for i, word in words {
    set(
      self.sim,
      if i == 0 {
        "request_data"
      } else {
        "request_data" + i.to_string()
      },
      32,
      word,
    )
  }
  set(self.sim, "request_valid", 1, 1UL)
  set(self.sim, "response_ready", 1, 0UL)
  for _ in 0..<300 {
    self.step()
    if self.accepted {
      break
    }
  }
  assert_true(self.accepted)
  set(self.sim, "request_valid", 1, 0UL)
  // Payload belongs to the accepted transaction; subsequent inputs may change.
  for i in 0..<4 {
    set(
      self.sim,
      if i == 0 {
        "request_data"
      } else {
        "request_data" + i.to_string()
      },
      32,
      0xdeadbeefUL,
    )
  }
  set(self.sim, "request_address", 28, 1020UL)
  set(self.sim, "request_line", 1, 0UL)
  set(self.sim, "request_write", 1, 0UL)
}

///|
fn BridgeBench::write_line(
  self : BridgeBench,
  address : UInt64,
  words : ArrayView[UInt64],
  fault~ : UInt64 = 0UL,
) -> Unit raise {
  let commands = self.commands.length()
  let data = self.data.length()
  self.begin_write_line(address, words)
  assert_eq(self.line_beat(11), (0UL, fault, 1UL))
  assert_eq(self.results.length(), 1)
  assert_eq(self.commands.length() - commands, if fault == 0UL { 1 } else { 0 })
  assert_eq(self.data.length() - data, if fault == 0UL { 1 } else { 0 })
  if fault == 0UL {
    assert_eq(self.data[data].1, 0UL)
    assert_eq(self.data[data].0, words.map(w => w.to_uint()))
  }
}

///|
fn write_line_replay(b : BridgeBench) -> Unit raise {
  let edge = [0x80000000UL, 0x7fffffffUL, 0xffffffffUL, 0UL]
  b.write_line(16UL, edge)
  for i, word in edge {
    assert_eq(b.transaction(16UL + i.to_uint64() * 4UL), (word, 0UL))
  }
  for address in [4UL, 8UL, 12UL, 1UL, 1020UL] {
    b.write_line(address, [1UL, 2UL, 3UL, 4UL], fault=1UL)
  }
  b.write_line(1008UL, [1UL, 0x12345678UL, 0xfedcba98UL, 4UL])
  assert_eq(b.transaction(1020UL), (4UL, 0UL))
  // A reset while the extra words are still crossing discards the request.
  b.begin_write_line(32UL, edge)
  b.reset()
  assert_eq(b.memory[2], [0U, 0U, 0U, 0U])
  b.write_line(32UL, edge)
  for command_first in [false, true] {
    b.command_paused = !command_first
    b.data_paused = command_first
    let commands = b.commands.length()
    let data = b.data.length()
    b.begin_write_line(48UL, edge)
    for _ in 0..<300 {
      b.step()
      if b.commands.length() > commands || b.data.length() > data {
        break
      }
    }
    for _ in 0..<13 {
      b.step()
    }
    assert_eq(b.commands.length() - commands, if command_first { 1 } else { 0 })
    assert_eq(b.data.length() - data, if command_first { 0 } else { 1 })
    assert_eq(value(b.sim, "response_valid"), 0UL)
    b.command_paused = false
    b.data_paused = false
    assert_eq(b.line_beat(9), (0UL, 0UL, 1UL))
    assert_eq(b.commands.length() - commands, 1)
    assert_eq(b.data.length() - data, 1)
    assert_eq(b.memory[3], edge.map(w => w.to_uint()))
  }
}
