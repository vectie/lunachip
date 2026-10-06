///|
priv struct Request {
  write : UInt64
  address : UInt64
  bytes : UInt64
  mask : UInt64
  data : UInt64
  tag : UInt64
} derive(Eq)

///|
priv struct Response {
  mut delay : Int
  tag : UInt64
  fault : UInt64
  data : UInt64
  request : Request
}

///|
priv struct HostDrive {
  request_ready : UInt64
  response_valid : UInt64
  response_tag : UInt64
  response_fault : UInt64
  response_data : UInt64
}

///|
// Only host bytes and the documented memory channel are modeled here. This
// environment neither executes matrix commands nor sees internal SRAM.
priv enum HostKind {
  Pipeline
  Concurrent
  FaultReset
  Array8
  ShapeReload
  Seeded(ReadOnlyArray[UInt64], ReadOnlyArray[Int])
  WriterFault
  DmaPoison
  RemoteFault(RemoteFaultHostState)
  CapacityWrap
}

///|
priv struct HostEvents {
  accepted : Request?
  acknowledged : Request?
}

///|
priv struct Host {
  kind : HostKind
  memory : Array[Int]
  mut pending : Response?
  mut held : Request?
  mut next_tag : UInt64
  mut requests : Int
  mut reads : Int
  mut writes : Int
  mut stalls : Int
}

///|
fn host() -> Host raise {
  {
    kind: Pipeline,
    memory: workload_memory(false),
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
fn concurrent_host() -> Host raise {
  {
    kind: Concurrent,
    memory: concurrent_memory(),
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
fn fault_reset_host() -> Host raise {
  {
    kind: FaultReset,
    memory: fault_reset_memory(),
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
fn writer_fault_host() -> Host raise {
  {
    kind: WriterFault,
    memory: writer_fault_memory(),
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
fn dma_poison_host() -> Host raise {
  {
    kind: DmaPoison,
    memory: dma_poison_memory(),
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
// A joint transport reset flushes obligations, not host bytes or lifetime totals.
fn Host::flush(self : Host) -> Unit {
  self.pending = None
  self.held = None
  self.next_tag = 0UL
}

///|
fn Host::read_allowed(self : Host, address : Int) -> Bool {
  match self.kind {
    Pipeline =>
      (address >= 512 && address < 640) ||
      address == 32 ||
      address == 33 ||
      address == 64 ||
      address == 67
    Concurrent =>
      (address >= 3072 && address < 3200) ||
      address == 32 ||
      address == 64 ||
      (address >= 512 && address < 1024) ||
      (address >= 1280 && address < 1792) ||
      (address >= 2048 && address < 2560)
    FaultReset =>
      (address >= 3072 && address < 3200) ||
      (address >= 512 && address < 528) ||
      (address >= 1280 && address < 1296) ||
      (address >= 2048 && address < 2112)
    Array8 | Seeded(_, _) => array8_read_allowed(address)
    ShapeReload => shape_reload_read_allowed(address)
    WriterFault =>
      (address >= 3072 && address < 3200) ||
      address == 512 ||
      address == 640 ||
      address == 768 ||
      address == 896 ||
      address == 1024
    DmaPoison =>
      (address >= 8192 && address < 8704) ||
      (address >= 32 && address < 672) ||
      (address >= 256 && address < 336) ||
      (address >= 512 && address < 1152) ||
      (address >= 1280 && address < 2304)
    RemoteFault(_) => remote_fault_read_allowed(address)
    CapacityWrap => address >= 3072 && address < 3136
  }
}

///|
fn Host::write_allowed(self : Host, address : Int) -> Bool {
  match self.kind {
    Pipeline => address == 128
    Concurrent => address == 2800 || address == 2816
    FaultReset => false
    Array8 | Seeded(_, _) => array8_write_allowed(address)
    ShapeReload => shape_reload_write_allowed(address)
    WriterFault => address == 1536 || address == 1792 || address == 2048
    DmaPoison =>
      (
        (address >= 4096 && address < 4416) &&
        (address - 4096) % 40 < 32 &&
        (address - 4096) % 4 == 0
      ) ||
      (
        (address >= 5120 && address < 5440) &&
        (address - 5120) % 40 < 32 &&
        (address - 5120) % 4 == 0
      )
    RemoteFault(_) => remote_fault_write_allowed(address)
    CapacityWrap => false
  }
}

///|
fn output_value(simulator : @sim.Simulator, name : String) -> UInt64 raise {
  let value = simulator.output(name)
  if !value.is_fully_known() {
    fail("unknown public output: \{name}")
  }
  value.to_uint64()
}

///|
fn Host::drive(self : Host, cycle : Int) -> HostDrive raise {
  let ready = match self.kind {
    Pipeline => if cycle % 4 == 0 { 1UL } else { 0UL }
    Concurrent | FaultReset => if cycle % 32 == 0 { 0UL } else { 1UL }
    Array8 | ShapeReload => array8_ready(cycle)
    WriterFault | RemoteFault(_) | CapacityWrap =>
      if cycle % 5 < 2 {
        0UL
      } else {
        1UL
      }
    DmaPoison => if cycle % 4 == 3 { 1UL } else { 0UL }
    Seeded(readiness, _) => {
      if cycle < 0 || cycle >= readiness.length() {
        fail("seeded readiness budget exhausted at cycle \{cycle}")
      }
      readiness[cycle]
    }
  }
  match self.pending {
    Some(response) if response.delay == 0 =>
      {
        request_ready: ready,
        response_valid: 1UL,
        response_tag: response.tag,
        response_fault: response.fault,
        response_data: response.data,
      }
    _ =>
      {
        request_ready: ready,
        response_valid: 0UL,
        response_tag: 0UL,
        response_fault: 0UL,
        response_data: 0UL,
      }
  }
}

///|
// Process only pre-edge handshakes after all inputs have settled. The caller
// commits the hardware edge immediately afterward; recorded inputs are fixed.
fn Host::accept(
  self : Host,
  simulator : @sim.Simulator,
  drive : HostDrive,
) -> HostEvents raise {
  let request = if output_value(simulator, "memory_request_valid") == 1UL {
    Some(Request::{
      write: output_value(simulator, "memory_request_write"),
      address: output_value(simulator, "memory_request_address"),
      bytes: output_value(simulator, "memory_request_bytes"),
      mask: output_value(simulator, "memory_request_mask"),
      data: output_value(simulator, "memory_request_data"),
      tag: output_value(simulator, "memory_request_tag"),
    })
  } else {
    None
  }
  if self.held is Some(previous) && request != Some(previous) {
    fail("memory request changed while backpressured")
  }
  self.held = if drive.request_ready == 0UL { request } else { None }
  if request is Some(_) && drive.request_ready == 0UL {
    self.stalls += 1
  }
  let response_accept = drive.response_valid == 1UL &&
    output_value(simulator, "memory_response_ready") == 1UL
  let acknowledged = if response_accept {
    match self.pending {
      Some(response) => {
        match self.kind {
          RemoteFault(state) => state.acknowledge(response, drive)
          _ => ()
        }
        Some(response.request)
      }
      None => fail("response acknowledged without a captured host request")
    }
  } else {
    None
  }
  let accepted = if drive.request_ready == 1UL { request } else { None }
  if accepted is Some(r) {
    if self.pending is Some(_) || response_accept {
      fail("multiple outstanding transactions or response-edge request")
    }
    if r.tag != self.next_tag ||
      r.address + r.bytes > self.memory.length().to_uint64() {
      fail("unexpected global tag or out-of-aperture request")
    }
    let address = r.address.to_int()
    let mut fault = 0UL
    let data = if r.write == 0UL {
      if r.bytes != 1UL || r.mask != 1UL || r.data != 0UL {
        fail("invalid byte read payload")
      }
      if !self.read_allowed(address) {
        fail("unexpected read address \{address}")
      }
      match self.kind {
        RemoteFault(state) => fault = state.accept_read(r)
        _ => ()
      }
      self.reads += 1
      self.memory[address].to_uint64()
    } else {
      if r.write != 1UL ||
        r.bytes != 4UL ||
        r.mask != 15UL ||
        !self.write_allowed(address) {
        fail("invalid result write payload")
      }
      let write_bytes = match self.kind {
        RemoteFault(state) => {
          let (status, count) = state.accept_write(r)
          fault = status
          count
        }
        _ => 4
      }
      for byte in 0..<write_bytes {
        self.memory[address + byte] = ((r.data >> (byte * 8)) & 255UL).to_int()
      }
      self.writes += 4
      0UL
    }
    let delay = match self.kind {
      Pipeline => 1 + self.requests % 3
      Concurrent | FaultReset => 1
      Array8 | ShapeReload => 1 + self.requests % 5
      WriterFault | RemoteFault(_) | CapacityWrap => 1 + self.requests % 3
      DmaPoison => 1
      Seeded(_, latencies) => {
        if self.requests >= latencies.length() {
          fail("seeded response latency budget exhausted")
        }
        latencies[self.requests]
      }
    }
    self.pending = Some({ delay, tag: r.tag, fault, data, request: r, })
    self.next_tag += 1UL
    self.requests += 1
  } else if response_accept {
    self.pending = None
  } else if self.pending is Some(response) && response.delay > 0 {
    response.delay -= 1
  }
  { accepted, acknowledged, }
}
