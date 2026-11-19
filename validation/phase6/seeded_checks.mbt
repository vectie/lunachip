///|
priv struct SeededPolicy {
  readiness : ReadOnlyArray[UInt64]
  delays : ReadOnlyArray[Int32]
}

///|
fn seeded_policy() -> SeededPolicy {
  let ready_random = @verilator.DeterministicPrng::new(
    seeded_master() ^ 0x5245414459UL,
  )
  let delay_random = @verilator.DeterministicPrng::new(
    seeded_master() ^ 0x4c4154454e4359UL,
  )
  let readiness = Array::make(32769, 0UL)
  for cycle in 0..<readiness.length() {
    readiness[cycle] = if ready_random.next() % 4UL == 0UL { 0UL } else { 1UL }
  }
  let delays = Array::make(960, 0)
  for request in 0..<delays.length() {
    delays[request] = 1 + (delay_random.next() % 7UL).to_int()
  }
  {
    readiness: ReadOnlyArray::from_array(readiness),
    delays: ReadOnlyArray::from_array(delays),
  }
}

///|
fn seeded_host(policy : SeededPolicy) -> Host raise {
  {
    kind: Seeded(policy.readiness, policy.delays),
    memory: seeded_memory(),
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
priv struct SeededMeasurement {
  reads : Array[Int32]
  writes : Array[Int32]
  write_acks : Array[Int32]
  delays : Array[Int32]
  readiness : Array[Int32]
  mut acknowledgements : Int32
}

///|
fn seeded_measurement() -> SeededMeasurement {
  {
    reads: Array::make(5, 0),
    writes: Array::make(2, 0),
    write_acks: Array::make(2, 0),
    delays: Array::make(7, 0),
    readiness: Array::make(2, 0),
    acknowledgements: 0,
  }
}

///|
fn SeededMeasurement::observe(
  self : SeededMeasurement,
  events : HostEvents,
  host : Host,
  policy : SeededPolicy,
  drive : HostDrive,
  cycle : Int32,
) -> Unit raise {
  if drive.request_ready != policy.readiness[cycle] {
    fail("seeded host did not drive the fixed readiness stream")
  }
  self.readiness[drive.request_ready.to_int()] += 1
  if events.accepted is Some(request) {
    if request.tag >= 960UL {
      fail("seeded request exceeded its finite latency stream")
    }
    if request.write == 0UL {
      self.reads[array8_read_class(request.address.to_int())] += 1
    } else {
      self.writes[array8_write_class(request.address.to_int())] += 1
    }
    let delay = policy.delays[request.tag.to_int()]
    self.delays[delay - 1] += 1
    match host.pending {
      Some(response) =>
        if response.request != request || response.delay != delay {
          fail("seeded accepted request did not install its sampled latency")
        }
      None => fail("seeded accepted request has no owned response")
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
fn SeededMeasurement::finish(
  self : SeededMeasurement,
  host : Host,
  cycles : Int32,
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
    host.stalls == 0 ||
    self.readiness[0] == 0 ||
    self.readiness[1] == 0 ||
    self.readiness[0] + self.readiness[1] != cycles {
    fail("seeded replay actual transaction/latency/backpressure totals differ")
  }
  for count in self.delays {
    if count == 0 {
      fail("seeded replay did not exercise all seven response-latency classes")
    }
  }
}
