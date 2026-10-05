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
  data : UInt64
}

///|
priv struct HostDrive {
  request_ready : UInt64
  response_valid : UInt64
  response_tag : UInt64
  response_data : UInt64
}

///|
// Only host bytes and the documented memory channel are modeled here. This
// environment neither executes matrix commands nor sees internal SRAM.
priv struct Host {
  memory : Array[Int]
  mut pending : Response?
  mut held : Request?
  mut requests : Int
  mut reads : Int
  mut writes : Int
  mut stalls : Int
}

///|
fn host() -> Host raise {
  {
    memory: workload_memory(false),
    pending: None,
    held: None,
    requests: 0,
    reads: 0,
    writes: 0,
    stalls: 0,
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
fn Host::drive(self : Host, cycle : Int) -> HostDrive {
  let ready = if cycle % 4 == 0 { 1UL } else { 0UL }
  match self.pending {
    Some(response) if response.delay == 0 =>
      {
        request_ready: ready,
        response_valid: 1UL,
        response_tag: response.tag,
        response_data: response.data,
      }
    _ =>
      {
        request_ready: ready,
        response_valid: 0UL,
        response_tag: 0UL,
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
) -> Unit raise {
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
  if request is Some(r) && drive.request_ready == 1UL {
    if self.pending is Some(_) || response_accept {
      fail("multiple outstanding transactions or response-edge request")
    }
    if r.tag != self.requests.to_uint64() || r.address + r.bytes > 1024UL {
      fail("unexpected global tag or out-of-aperture request")
    }
    let address = r.address.to_int()
    let data = if r.write == 0UL {
      if r.bytes != 1UL || r.mask != 1UL || r.data != 0UL {
        fail("invalid byte read payload")
      }
      if !(address >= 512 && address < 640) &&
        address != 32 &&
        address != 33 &&
        address != 64 &&
        address != 67 {
        fail("unexpected read address \{address}")
      }
      self.reads += 1
      self.memory[address].to_uint64()
    } else {
      if r.write != 1UL || r.bytes != 4UL || r.mask != 15UL || address != 128 {
        fail("invalid result write payload")
      }
      for byte in 0..<4 {
        self.memory[address + byte] = ((r.data >> (byte * 8)) & 255UL).to_int()
      }
      self.writes += 4
      0UL
    }
    self.pending = Some({ delay: 1 + self.requests % 3, tag: r.tag, data, })
    self.requests += 1
  } else if response_accept {
    self.pending = None
  } else if self.pending is Some(response) && response.delay > 0 {
    response.delay -= 1
  }
}
