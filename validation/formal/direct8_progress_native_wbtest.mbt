///|
priv struct Direct8ProgressNative {
  mut owner : Array[UInt64]?
  mut held : Array[UInt64]?
  mut active : Bool
  mut age : Int
  mut reply_age : Int
  mut maximum_service : Int
  mut maximum_reply : Int
}

///|
fn Direct8ProgressNative::new() -> Direct8ProgressNative {
  {
    owner: None,
    held: None,
    active: false,
    age: 0,
    reply_age: 0,
    maximum_service: 0,
    maximum_reply: 0,
  }
}

///|
fn Direct8ProgressNative::step(
  self : Direct8ProgressNative,
  e : Direct8FairEdge,
) -> Unit raise {
  if e.reset {
    self.owner = None
    self.held = None
    self.active = false
    self.age = 0
    self.reply_age = 0
    return
  }
  let accept = e.request_valid && e.request_ready
  let ack = e.response_valid && e.response_ready
  direct8_fair_require(
    self.active == (self.owner is Some(_) || self.held is Some(_)),
    "d8p_owner_history",
  )
  direct8_fair_require(
    (if self.owner is Some(_) {
      self.reply_age >= 1 && self.reply_age <= 2
    } else {
      self.reply_age == 0
    }) &&
    (if self.active { self.age >= 1 && self.age <= 3 } else { self.age == 0 }),
    "d8p_age_history",
  )
  direct8_fair_require(self.held is None || accept, "d8p_offer_drain_r2")
  direct8_fair_require(
    self.owner is None || ack || self.reply_age < 2,
    "d8p_reply_drain_h2",
  )
  direct8_fair_require(!self.active || ack || self.age < 3, "d8p_service_drain")
  if self.held is Some(payload) {
    direct8_fair_require(
      e.request_valid && e.request == payload,
      "dc_request_stable",
    )
  }
  direct8_fair_require(
    (!accept || self.owner is None) &&
    (!e.response_ready || self.owner is Some(_)) &&
    !(accept && ack),
    "dc_transport_serial_owned",
  )
  direct8_fair_require(
    self.owner is None || e.response_ready,
    "dc_response_readiness",
  )
  if ack {
    guard self.owner is Some(request) else {
      fail("ACK without original owner")
    }
    assert_eq(e.response[0], request[5])
    assert_eq(e.response[1], 0UL)
    self.maximum_service = self.maximum_service.max(self.age)
    self.maximum_reply = self.maximum_reply.max(self.reply_age)
    self.owner = None
    self.reply_age = 0
  } else if accept {
    self.owner = Some(e.request.copy())
    self.reply_age = 1
  } else if self.owner is Some(_) && self.reply_age < 3 {
    self.reply_age += 1
  }
  if ack {
    self.active = false
    self.age = 0
  } else if !self.active && e.request_valid {
    self.active = true
    self.age = 1
  } else if self.active && self.age < 3 {
    self.age += 1
  }
  self.held = if e.request_valid && !e.request_ready {
    Some(e.request.copy())
  } else {
    None
  }
}

///|
test "direct8 progress accepts ACK at R2 plus H2 limit with full address and tag" {
  let model = Direct8ProgressNative::new()
  let request = [0UL, 0xffffffffUL, 1UL, 1UL, 0UL, 0x80000001UL]
  let offer = {
    ..direct8_fair_idle_edge(),
    request_valid: true,
    request_ready: false,
    request,
  }
  model.step(offer)
  let accepted = { ..offer, request_ready: true, }
  model.step(accepted)
  let wait = { ..direct8_fair_idle_edge(), response_ready: true, }
  model.step(wait)
  let ack = {
    ..wait,
    response_valid: true,
    response: [0x80000001UL, 0UL, 0xffffffffUL],
  }
  model.step(ack)
  assert_eq((model.maximum_service, model.maximum_reply), (3, 2))
  assert_true(!model.active && model.owner is None)
}

///|
test "direct8 progress does not freeze accepted age after a response offer" {
  let model = Direct8ProgressNative::new()
  model.owner = Some([0UL, 0UL, 1UL, 1UL, 0UL, 1UL])
  model.active = true
  model.age = 2
  model.reply_age = 2
  let offered = {
    ..direct8_fair_idle_edge(),
    response_valid: true,
    response: [1UL, 0UL, 0UL],
  }
  try model.step(offered) catch {
    BadFairEdge(label) => assert_eq(label, "d8p_reply_drain_h2")
    error => fail("unexpected progress failure: \{error}")
  } noraise {
    _ => fail("unaccepted offered response must not satisfy progress")
  }
}
