///|
// Independent public accepted-address and ACK sets, not a host-memory model.
priv struct Direct8UsefulNative {
  read_accept : Array[Bool]
  read_ack : Array[Bool]
  write_accept : Array[Bool]
  write_ack : Array[Bool]
  mut owner : (Bool, Int, UInt64)?
  mut admitted : Int
  mut retired : Int
  mut qualified : Bool
}

///|
fn Direct8UsefulNative::new() -> Direct8UsefulNative {
  {
    read_accept: Array::make(256, false),
    read_ack: Array::make(256, false),
    write_accept: Array::make(64, false),
    write_ack: Array::make(64, false),
    owner: None,
    admitted: 0,
    retired: 0,
    qualified: false,
  }
}

///|
fn Direct8UsefulNative::step(
  self : Direct8UsefulNative,
  e : Direct8FairEdge,
) -> Unit raise {
  if e.reset {
    return
  }
  if e.descriptor_valid && e.descriptor_ready {
    assert_true(self.admitted < 4)
    let canonical = direct8_completion_packet(self.admitted)
    // Slot selections may vary; all other 192 bits retain the exact sequence.
    assert_eq(e.packet[0:3].to_owned(), canonical[0:3].to_owned())
    self.admitted += 1
  }
  if e.request_valid && e.request_ready {
    assert_true(self.owner is None)
    let write = e.request[0] == 1UL
    let address = e.request[1]
    let index = if write {
      assert_true(address >= 1024UL && address < 1280UL && address % 4UL == 0UL)
      assert_eq((e.request[2], e.request[3]), (4UL, 15UL))
      ((address - 1024UL) / 4UL).to_int()
    } else {
      assert_eq((e.request[2], e.request[3], e.request[4]), (1UL, 1UL, 0UL))
      if address >= 256UL && address < 384UL {
        (address - 256UL).to_int()
      } else {
        assert_true(address >= 512UL && address < 640UL)
        (address - 384UL).to_int()
      }
    }
    let accepted = if write { self.write_accept } else { self.read_accept }
    assert_false(accepted[index])
    accepted[index] = true
    self.owner = Some((write, index, e.request[5]))
  }
  if e.response_valid && e.response_ready {
    guard self.owner is Some((write, index, tag)) else {
      fail("useful ACK without actual request")
    }
    assert_eq(e.response[0], tag)
    assert_eq(e.response[1], 0UL)
    let acknowledgments = if write { self.write_ack } else { self.read_ack }
    assert_false(acknowledgments[index])
    acknowledgments[index] = true
    self.owner = None
  }
  if e.completion_valid && e.completion_ready {
    assert_true(self.retired < 4 && self.retired < self.admitted)
    assert_eq(
      (e.completion[0], e.completion[1], e.completion[3]),
      (73UL, 0UL, 0UL),
    )
    assert_eq(
      e.completion[2],
      if self.retired < 2 {
        128UL
      } else if self.retired == 2 {
        0UL
      } else {
        256UL
      },
    )
    if self.retired == 3 {
      assert_true(self.admitted == 4 && self.owner is None)
      for
        bitmap in [
          self.read_accept,
          self.read_ack,
          self.write_accept,
          self.write_ack,
        ] {
        assert_true(bitmap.all(value => value))
      }
      self.qualified = true
    }
    self.retired += 1
  }
}

///|
test "direct8 useful monitor rejects duplicate addresses and wrong high ACK tag bits" {
  let model = Direct8UsefulNative::new()
  let request = {
    ..direct8_fair_idle_edge(),
    request_valid: true,
    request: [0UL, 256UL, 1UL, 1UL, 0UL, 0x80000001UL],
  }
  model.step(request)
  let wrong = {
    ..direct8_fair_idle_edge(),
    response_valid: true,
    response_ready: true,
    response: [1UL, 0UL, 0UL],
  }
  try model.step(wrong) catch {
    _ => ()
  } noraise {
    _ => fail("high ACK tag bits must be preserved")
  }
  let ack = { ..wrong, response: [0x80000001UL, 0UL, 0UL], }
  model.step(ack)
  try model.step(request) catch {
    _ => ()
  } noraise {
    _ => fail("duplicate byte address must not advance useful work")
  }
}
