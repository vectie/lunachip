///|
fn array8_rectangle(
  address : Int32,
  base : Int32,
  rows : Int32,
  row_bytes : Int32,
  stride : Int32,
) -> Bool {
  address >= base &&
  (address - base) / stride < rows &&
  (address - base) % stride < row_bytes
}

///|
fn array8_read_allowed(address : Int32) -> Bool {
  (address >= 3072 && address < 3200) ||
  array8_rectangle(address, 512, 8, 16, 20) ||
  array8_rectangle(address, 768, 8, 16, 21) ||
  array8_rectangle(address, 1280, 16, 8, 12) ||
  array8_rectangle(address, 1536, 16, 8, 13)
}

///|
fn array8_write_allowed(address : Int32) -> Bool {
  (array8_rectangle(address, 2048, 8, 32, 40) && (address - 2048) % 4 == 0) ||
  (array8_rectangle(address, 2560, 8, 32, 44) && (address - 2560) % 4 == 0)
}

///|
fn array8_ready(cycle : Int32) -> UInt64 {
  if cycle % 13 == 0 || cycle % 7 < 2 {
    0UL
  } else {
    1UL
  }
}

///|
fn array8_host() -> Host raise {
  {
    kind: Array8,
    memory: array8_memory(),
    pending: None,
    held: None,
    next_tag: 0UL,
    requests: 0,
    reads: 0,
    writes: 0,
    stalls: 0,
  }
}

///|
priv struct Array8Measurement {
  reads : Array[Int32]
  writes : Array[Int32]
  write_acks : Array[Int32]
  delays : Array[Int32]
  mut acknowledgements : Int32
}

///|
fn array8_measurement() -> Array8Measurement {
  {
    reads: Array::make(5, 0),
    writes: Array::make(2, 0),
    write_acks: Array::make(2, 0),
    delays: Array::make(5, 0),
    acknowledgements: 0,
  }
}

///|
fn array8_read_class(address : Int32) -> Int32 raise {
  if address >= 3072 && address < 3200 {
    0
  } else if array8_rectangle(address, 512, 8, 16, 20) {
    1
  } else if array8_rectangle(address, 1280, 16, 8, 12) {
    2
  } else if array8_rectangle(address, 768, 8, 16, 21) {
    3
  } else if array8_rectangle(address, 1536, 16, 8, 13) {
    4
  } else {
    fail("8x8 request read an unowned byte \{address}")
  }
}

///|
fn array8_write_class(address : Int32) -> Int32 raise {
  if array8_rectangle(address, 2048, 8, 32, 40) && (address - 2048) % 4 == 0 {
    0
  } else if array8_rectangle(address, 2560, 8, 32, 44) &&
    (address - 2560) % 4 == 0 {
    1
  } else {
    fail("8x8 request wrote padding or an unowned word \{address}")
  }
}

///|
fn Array8Measurement::observe(
  self : Array8Measurement,
  events : HostEvents,
  host : Host,
) -> Unit raise {
  if events.accepted is Some(request) {
    if request.write == 0UL {
      self.reads[array8_read_class(request.address.to_int())] += 1
    } else {
      self.writes[array8_write_class(request.address.to_int())] += 1
    }
    let delay = (request.tag % 5UL).to_int()
    self.delays[delay] += 1
    match host.pending {
      Some(response) =>
        if response.request != request || response.delay != delay + 1 {
          fail(
            "8x8 host did not install the deterministic varied response delay",
          )
        }
      None => fail("accepted 8x8 request did not create an owned response")
    }
  }
  if events.acknowledged is Some(request) {
    self.acknowledgements += 1
    if request.write == 1UL {
      self.write_acks[array8_write_class(request.address.to_int())] += 1
    }
  }
}

///|
fn Array8Measurement::finish(
  self : Array8Measurement,
  host : Host,
) -> Unit raise {
  if self.reads != [320, 128, 128, 128, 128] ||
    self.writes != [64, 64] ||
    self.write_acks != [64, 64] ||
    self.acknowledgements != 960 ||
    host.requests != 960 ||
    host.reads != 832 ||
    host.writes != 512 ||
    host.next_tag != 960UL ||
    host.pending is Some(_) ||
    host.held is Some(_) ||
    host.stalls == 0 {
    fail(
      "8x8 actual transaction classes, acknowledgements or bytes did not match",
    )
  }
  for count in self.delays {
    if count == 0 {
      fail("8x8 replay did not exercise every response-delay class")
    }
  }
}

///|
fn array8_assert_compute(simulator : @sim.Simulator) -> Unit raise {
  for
    (name, expected) in [
      ("accepted_steps", 30UL),
      ("active_cycles", 30UL),
      ("elapsed_cycles", 31UL),
      ("stall_cycles", 0UL),
      ("capture_cycles", 64UL),
    ] {
    if output_value(simulator, name) != expected {
      fail("8x8 compute counter \{name} did not equal \{expected}")
    }
  }
}

///|
fn array8_assert_completion(
  actual : CompletionSnapshot,
  ordinal : Int32,
) -> Unit raise {
  let progress : Array[UInt64] = [
    128UL, 128UL, 0UL, 0UL, 128UL, 128UL, 0UL, 256UL, 256UL, 0UL,
  ]
  if ordinal >= progress.length() ||
    actual.id != (101 + ordinal).to_uint64() ||
    actual.fault != 0UL ||
    actual.bytes != progress[ordinal] ||
    actual.address != 0UL {
    fail("unexpected 8x8 completion at ordinal \{ordinal}")
  }
}
