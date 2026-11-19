///|
// Public PRE samples only. Invalid DUT payloads may be unknown and are not read.
priv struct Direct8FairEdge {
  reset : Bool
  descriptor_valid : Bool
  descriptor_ready : Bool
  packet : Array[UInt64]
  request_valid : Bool
  mut request_ready : Bool
  request : Array[UInt64]
  mut response_valid : Bool
  mut response_ready : Bool
  response : Array[UInt64]
  completion_valid : Bool
  mut completion_ready : Bool
  completion : Array[UInt64]
}

///|
suberror Direct8FairViolation {
  BadFairEdge(String)
}

///|
fn direct8_fair_require(value : Bool, label : String) -> Unit raise {
  if !value {
    raise BadFairEdge(label)
  }
}

///|
priv struct Direct8FairNative {
  mut seen : Bool
  mut descriptor_hold : Array[UInt64]?
  mut response_hold : Array[UInt64]?
  mut request_hold : Array[UInt64]?
  mut completion_hold : Array[UInt64]?
  mut owner : Array[UInt64]?
  mut response_age : Int32
  mut response_offered : Bool
  mut outstanding : Int32
  mut post_reset_edges : Int32
  mut taken : Bool
  mut active : Bool
  mut older : Int32
  mut age : Int32
  mut saved_packet : Array[UInt64]
  mut admitted : Int32
  mut retired : Int32
  mut watch_retire_age : Int32?
  mut negative_seen : Bool
  mut older_seen : Bool
  mut request_stall_seen : Bool
  mut completion_stall_seen : Bool
}

///|
fn Direct8FairNative::new() -> Direct8FairNative {
  {
    seen: false,
    descriptor_hold: None,
    response_hold: None,
    request_hold: None,
    completion_hold: None,
    owner: None,
    response_age: 0,
    response_offered: false,
    outstanding: 0,
    post_reset_edges: 0,
    taken: false,
    active: false,
    older: 0,
    age: 0,
    saved_packet: [],
    admitted: 0,
    retired: 0,
    watch_retire_age: None,
    negative_seen: false,
    older_seen: false,
    request_stall_seen: false,
    completion_stall_seen: false,
  }
}

///|
// Same seven host predicates as the registered source. Availability never
// depends on response_ready or assumes that a DUT state machine advances.
fn Direct8FairNative::host(
  self : Direct8FairNative,
  e : Direct8FairEdge,
) -> Unit raise {
  direct8_fair_require(e.reset == !self.seen, "dc_initial_only_reset")
  if e.reset {
    direct8_fair_require(!e.response_valid, "dc_host_owned_success_response")
    return
  }
  if self.descriptor_hold is Some(packet) {
    direct8_fair_require(
      e.descriptor_valid && e.packet == packet,
      "dc_host_descriptor_stable",
    )
  }
  if e.response_valid {
    direct8_fair_require(
      self.owner is Some(request) &&
      e.response[0] == request[5] &&
      e.response[1] == 0UL,
      "dc_host_owned_success_response",
    )
  }
  if self.response_hold is Some(payload) {
    direct8_fair_require(
      e.response_valid && e.response == payload,
      "dc_host_response_stable",
    )
  }
  direct8_fair_require(
    self.request_hold is None || e.request_ready,
    "dc_host_request_ready_r2",
  )
  direct8_fair_require(
    self.completion_hold is None || e.completion_ready,
    "dc_host_completion_ready_c2",
  )
  direct8_fair_require(
    self.owner is None ||
    self.response_offered ||
    self.response_age < 2 ||
    e.response_valid,
    "dc_host_response_offer_h2",
  )
}

///|
fn Direct8FairNative::check(
  self : Direct8FairNative,
  e : Direct8FairEdge,
) -> Unit raise {
  self.host(e)
  if e.reset {
    return
  }
  let admit = e.descriptor_valid && e.descriptor_ready
  let retire = e.completion_valid && e.completion_ready
  let request_accept = e.request_valid && e.request_ready
  let response_accept = e.response_valid && e.response_ready
  if self.request_hold is Some(payload) {
    direct8_fair_require(
      e.request_valid && e.request == payload,
      "dc_request_stable",
    )
  }
  if self.completion_hold is Some(payload) {
    direct8_fair_require(
      e.completion_valid && e.completion == payload,
      "dc_completion_stable",
    )
  }
  direct8_fair_require(
    (!request_accept || self.owner is None) &&
    (!e.response_ready || self.owner is Some(_)) &&
    !(request_accept && response_accept),
    "dc_transport_serial_owned",
  )
  direct8_fair_require(
    self.owner is None || e.response_ready,
    "dc_response_readiness",
  )
  direct8_fair_require(
    self.outstanding >= 0 &&
    self.outstanding <= 7 &&
    (!retire || self.outstanding != 0) &&
    (!admit || retire || self.outstanding < 7) &&
    (!self.active || self.older < self.outstanding) &&
    (
      !self.active ||
      self.older != 0 ||
      !e.completion_valid ||
      e.completion[0] == self.saved_packet[0] >> 32
    ),
    "dc_ordinal_history",
  )
  direct8_fair_require(
    !self.active ||
    (self.older == 0 && retire) ||
    self.age < direct8_completion_budget().deadline,
    "dc_watched_retirement_deadline",
  )
}

///|
fn Direct8FairNative::step(
  self : Direct8FairNative,
  e : Direct8FairEdge,
  select : Bool,
) -> Unit raise {
  self.check(e)
  self.seen = true
  if e.reset {
    return
  }
  let admit = e.descriptor_valid && e.descriptor_ready
  let retire = e.completion_valid && e.completion_ready
  let watch = !self.taken && select && self.post_reset_edges < 32 && admit
  let was_active = self.active
  if watch {
    self.taken = true
    self.active = true
    self.saved_packet = e.packet.copy()
    self.age = 1
    self.older = self.outstanding - (if retire { 1 } else { 0 })
    self.older_seen = self.older != 0
  }
  if was_active {
    if self.age >= 1 &&
      self.saved_packet == direct8_completion_packet(0) &&
      !(self.older == 0 && retire) {
      self.negative_seen = true
    }
    if retire {
      if self.older == 0 {
        self.active = false
        self.watch_retire_age = Some(self.age)
      } else {
        self.older -= 1
      }
    }
    if self.age < 16383 {
      self.age += 1
    }
  }
  if admit {
    self.admitted += 1
    self.outstanding += 1
  }
  if retire {
    self.retired += 1
    self.outstanding -= 1
  }
  if self.post_reset_edges < 33 {
    self.post_reset_edges += 1
  }
  let request_accept = e.request_valid && e.request_ready
  let response_accept = e.response_valid && e.response_ready
  if request_accept && self.owner is None {
    self.owner = Some(e.request.copy())
    self.response_age = 1
    self.response_offered = false
  } else if self.owner is Some(_) {
    if !self.response_offered && self.response_age < 2 {
      self.response_age += 1
    }
    if e.response_valid {
      self.response_offered = true
    }
    if response_accept {
      self.owner = None
      self.response_age = 0
      self.response_offered = false
    }
  }
  self.descriptor_hold = if e.descriptor_valid && !e.descriptor_ready {
    Some(e.packet.copy())
  } else {
    None
  }
  self.response_hold = if e.response_valid && !e.response_ready {
    Some(e.response.copy())
  } else {
    None
  }
  self.request_hold = if e.request_valid && !e.request_ready {
    Some(e.request.copy())
  } else {
    None
  }
  self.completion_hold = if e.completion_valid && !e.completion_ready {
    Some(e.completion.copy())
  } else {
    None
  }
  self.request_stall_seen = self.request_stall_seen ||
    self.request_hold is Some(_)
  self.completion_stall_seen = self.completion_stall_seen ||
    self.completion_hold is Some(_)
}
