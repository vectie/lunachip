///|
priv struct DemoRequest {
  write : UInt64
  address : UInt64
  bytes : UInt64
  mask : UInt64
  data : UInt64
  tag : UInt64
} derive(Eq)

///|
priv struct DemoResponse {
  mut delay : Int
  tag : UInt64
  data : UInt64
}

///|
// External byte memory only: no knowledge of matrix arithmetic or device SRAM.
priv struct DemoHost {
  memory : Array[Int]
  mut pending : DemoResponse?
  mut held : DemoRequest?
  mut cycles : Int
  mut requests : Int
  mut request_stalls : Int
  mut response_delays : Int
  mut read_bytes : Int
  mut write_bytes : Int
}

///|
fn DemoHost::new() -> DemoHost {
  {
    memory: Array::make(1024, 165),
    pending: None,
    held: None,
    cycles: 0,
    requests: 0,
    request_stalls: 0,
    response_delays: 0,
    read_bytes: 0,
    write_bytes: 0,
  }
}

///|
fn DemoHost::seed(
  self : DemoHost,
  base : Int,
  stride : Int,
  rows : Int,
  columns : Int,
  values : Array[Int],
) -> Unit {
  for row in 0..<rows {
    for column in 0..<columns {
      self.memory[base + row * stride + column] = values[row * columns + column] &
        255
    }
  }
}

///|
fn DemoHost::word(self : DemoHost, address : Int) -> Int {
  let mut bits = 0UL
  for byte in 0..<4 {
    bits = bits | (self.memory[address + byte].to_uint64() << (byte * 8))
  }
  if bits >= 0x80000000UL {
    (bits.reinterpret_as_int64() - 4294967296L).to_int()
  } else {
    bits.to_int()
  }
}

///|
fn portable_demo_put(
  simulator : @sim.Simulator,
  name : String,
  width : Int,
  value : UInt64,
) -> Unit raise {
  simulator.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
  simulator.settle()
}

///|
fn DemoHost::tick(self : DemoHost, simulator : @sim.Simulator) -> Unit raise {
  let request_ready = self.cycles % 4 == 3
  portable_demo_put(
    simulator,
    "memory_request_ready",
    1,
    if request_ready {
      1UL
    } else {
      0UL
    },
  )
  let response = match self.pending {
    Some(p) if p.delay == 0 => Some(p)
    _ => None
  }
  portable_demo_put(
    simulator,
    "memory_response_valid",
    1,
    if response is Some(_) {
      1UL
    } else {
      0UL
    },
  )
  if response is Some(p) {
    portable_demo_put(simulator, "memory_response_tag", 32, p.tag)
    portable_demo_put(simulator, "memory_response_fault", 2, 0UL)
    portable_demo_put(simulator, "memory_response_data", 32, p.data)
  }
  let request = if demo_read(simulator, "memory_request_valid") == 1UL {
    Some(DemoRequest::{
      write: demo_read(simulator, "memory_request_write"),
      address: demo_read(simulator, "memory_request_address"),
      bytes: demo_read(simulator, "memory_request_bytes"),
      mask: demo_read(simulator, "memory_request_mask"),
      data: demo_read(simulator, "memory_request_data"),
      tag: demo_read(simulator, "memory_request_tag"),
    })
  } else {
    None
  }
  if self.held is Some(previous) && request != Some(previous) {
    raise DemoError::Transport("request changed while backpressured")
  }
  self.held = if !request_ready { request } else { None }
  if request is Some(_) && !request_ready {
    self.request_stalls += 1
  }
  let response_accepted = response is Some(_) &&
    demo_read(simulator, "memory_response_ready") == 1UL
  simulator.rising_edge("clock")
  if response_accepted {
    self.pending = None
  } else if self.pending is Some(p) && p.delay > 0 {
    p.delay -= 1
    self.response_delays += 1
  }
  if request_ready && request is Some(r) {
    if self.pending is Some(_) {
      raise DemoError::Transport("more than one outstanding transaction")
    }
    let expected_bytes = if r.write == 1UL { 4UL } else { 1UL }
    let expected_mask = if r.write == 1UL { 15UL } else { 1UL }
    if r.tag != self.requests.to_uint64() ||
      r.bytes != expected_bytes ||
      r.mask != expected_mask ||
      r.address + r.bytes > 1024UL {
      raise DemoError::Transport(
        "unexpected transaction tag, size, mask, or address",
      )
    }
    let address = r.address.to_int()
    let data = if r.write == 0UL {
      if r.data != 0UL {
        raise DemoError::Transport("read request carried nonzero data")
      }
      self.read_bytes += 1
      self.memory[address].to_uint64()
    } else {
      for byte in 0..<4 {
        self.memory[address + byte] = ((r.data >> (byte * 8)) & 255UL).to_int()
      }
      self.write_bytes += 4
      0UL
    }
    self.pending = Some({ delay: 1 + self.requests % 3, tag: r.tag, data, })
    self.requests += 1
  }
  self.cycles += 1
}
