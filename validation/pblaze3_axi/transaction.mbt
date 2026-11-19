///|
fn Bench::begin(
  self : Bench,
  address : UInt64,
  write~ : Bool = false,
  line~ : Bool = false,
  burst~ : Bool = false,
  wide~ : Bool = false,
  data~ : Array[UInt64] = [0UL, 0UL, 0UL, 0UL],
) -> Unit raise {
  self.accepted = false
  self.responses.clear()
  set(self.sim, "request_valid", 1, 1UL)
  set(self.sim, "request_address", 32, address)
  set(self.sim, "request_write", 1, if write { 1UL } else { 0UL })
  set(self.sim, "request_line", 1, if line { 1UL } else { 0UL })
  set(self.sim, "request_burst", 1, if burst { 1UL } else { 0UL })
  set(self.sim, "request_wide", 1, if wide { 1UL } else { 0UL })
  set(self.sim, "response_ready", 1, 0UL)
  for i in 0..<4 {
    set(
      self.sim,
      if i == 0 {
        "request_data"
      } else {
        "request_data" + i.to_string()
      },
      32,
      data[i],
    )
  }
  for _ in 0..<100 {
    self.step()
    if self.accepted {
      break
    }
  }
  assert_true(self.accepted)
  set(self.sim, "request_valid", 1, 0UL)
  // Accepted payload must remain independent of subsequent source changes.
  set(self.sim, "request_address", 32, 0xfffffff0UL)
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
}

///|
fn Bench::finish(
  self : Bench,
  hold~ : Int32 = 3,
) -> Array[(Array[UInt64], UInt64, UInt64)] raise {
  let mut waiting = 0
  for _ in 0..<30000 {
    let v = value(self.sim, "response_valid") == 1UL
    if v {
      waiting += 1
    }
    set(self.sim, "response_ready", 1, if waiting > hold { 1UL } else { 0UL })
    let before = self.responses.length()
    self.step()
    if self.responses.length() != before {
      waiting = 0
      if self.responses[self.responses.length() - 1].2 == 1UL {
        break
      }
    }
  }
  assert_true(!self.responses.is_empty())
  assert_eq(self.responses[self.responses.length() - 1].2, 1UL)
  set(self.sim, "response_ready", 1, 0UL)
  self.responses.copy()
}

///|
fn exercise(b : Bench) -> Unit raise {
  let packet_words = if b.lanes == 16 { 16 } else { 8 }
  for address in [0UL, 4UL, 8UL, 12UL, 4092UL, 0x10000000UL, 0x7ffffffcUL] {
    b.begin(address, write=true, data=[address ^ 0x9213c7UL, 0UL, 0UL, 0UL])
    assert_eq(b.finish()[0].0[0], 0UL)
    b.begin(address)
    let result = b.finish()
    assert_eq(result.length(), 1)
    assert_eq(result[0].0[0], address ^ 0x9213c7UL)
    assert_eq(result[0].1, 0UL)
  }
  let words = [0x12345678UL, 0xffffffffUL, 0x80000000UL, 0xdeadbeefUL]
  b.begin(0x10000010UL, write=true, line=true, data=words)
  assert_eq(b.finish()[0].1, 0UL)
  b.begin(0x10000010UL, line=true)
  let result = b.finish()
  assert_eq(result.length(), 4)
  for i in 0..<4 {
    assert_eq(result[i].0[0], words[i])
  }
  for wide in [false, true] {
    b.begin(3968UL, line=true, burst=true, wide~)
    let result = b.finish()
    assert_eq(result.length(), if wide { 32 / packet_words } else { 32 })
    for i, (data, fault, last) in result {
      assert_eq(fault, 0UL)
      assert_eq(last, if i + 1 == result.length() { 1UL } else { 0UL })
      for lane in 0..<(if wide { packet_words } else { 1 }) {
        assert_eq(
          data[lane],
          b.word(
            3968UL +
            (i * (if wide { packet_words } else { 1 }) + lane).to_uint64() * 4UL,
          ),
        )
      }
    }
  }
  for
    (address, stride) in [
      (0x10000000UL, 256UL),
      (0x7ffff800UL, 128UL),
      (0UL, 0x08000000UL),
    ] {
    b.begin(address, line=true, burst=true, wide=true, data=[
      0x80000000UL | stride,
      0UL,
      0UL,
      0UL,
    ])
    let result = b.finish(hold=1)
    assert_eq(result.length(), 512 / packet_words)
    for i, (words, fault, last) in result {
      assert_eq(fault, 0UL)
      assert_eq(last, if i + 1 == result.length() { 1UL } else { 0UL })
      for lane in 0..<packet_words {
        assert_eq(
          words[lane],
          b.word(
            address +
            (i / (32 / packet_words)).to_uint64() * stride +
            (i % (32 / packet_words) * packet_words * 4 + lane * 4).to_uint64(),
          ),
        )
      }
    }
  }
}
