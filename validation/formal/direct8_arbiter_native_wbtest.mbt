///|
priv struct Direct8ArbiterWatch {
  mut active : Bool
  mut accepted : Bool
  mut granted : Bool
  mut age : Int
  mut maximum : Int
}

///|
priv struct Direct8ArbiterNative {
  watches : Array[Direct8ArbiterWatch]
  mut active : Bool
  mut accepted : Bool
  mut owner : Int
  mut payload : Array[UInt64]
  mut global_tag : UInt64
  mut preference : UInt64
  mut age : Int
  mut maximum : Int
  previous_head : Array[Bool]
  previous_done : Array[Bool]
  previous_collect : Array[Bool]
  head_events : Array[Int]
  done_events : Array[Int]
  collector_events : Array[Int]
  grants : Array[Int]
  acks : Array[Int]
  mut tied_grants : Int
  mut contended_edges : Int
}

///|
fn Direct8ArbiterNative::new() -> Direct8ArbiterNative {
  {
    watches: Array::makei(2, _ => {
      active: false,
      accepted: false,
      granted: false,
      age: 0,
      maximum: 0,
    }),
    active: false,
    accepted: false,
    owner: 0,
    payload: [],
    global_tag: 0UL,
    preference: 0UL,
    age: 0,
    maximum: 0,
    previous_head: Array::make(4, false),
    previous_done: Array::make(3, false),
    previous_collect: Array::make(3, false),
    head_events: Array::make(4, 0),
    done_events: Array::make(3, 0),
    collector_events: Array::make(3, 0),
    grants: [0, 0],
    acks: [0, 0],
    tied_grants: 0,
    contended_edges: 0,
  }
}

///|
// Read original PRE state lazily. Uninitialized SRAM/FIFO data is not sampled
// merely because an unused alias exists. Selected payloads keep every bit.
fn Direct8ArbiterNative::step(
  self : Direct8ArbiterNative,
  read : (String) -> UInt64 raise,
) -> Unit raise {
  if read("i_reset") == 1UL {
    return
  }
  let yes = name => read(name) == 1UL
  let state = read("r_state")
  let owner = read("r_owner").to_int()
  let grant = yes("e_grant")
  let selected = read("e_choose_engine").to_int()
  let request = yes("e_request_accept")
  let ack = yes("e_response_accept")
  direct8_fair_require(state != 3UL, "d8g_no_poison")
  direct8_fair_require(
    self.active == (state == 1UL || state == 2UL) &&
    self.accepted == (state == 2UL),
    "d8g_owner_history",
  )
  direct8_fair_require(
    read("r_preference") == self.preference,
    "d8g_preference",
  )
  let valid = [yes("i_reader_valid"), yes("i_engine_valid")]
  if (state == 1UL || state == 2UL) && valid[1 - owner] {
    self.contended_edges += 1
  }
  let expected = if valid[1] && (!valid[0] || self.preference == 1UL) {
    1
  } else {
    0
  }
  direct8_fair_require(
    grant == (state == 0UL && (valid[0] || valid[1])) && selected == expected,
    "d8g_grant_policy",
  )
  if self.active {
    let payload = ["write", "address", "bytes", "mask", "data", "local_tag"].map(field => {
        read("r_" + field)
      },
    )
    direct8_fair_require(
      payload == self.payload && owner == self.owner,
      "d8g_snapshot_hold",
    )
    direct8_fair_require(ack || self.age < 6, "d8g_local_service_t6")
    self.maximum = if self.age > self.maximum { self.age } else { self.maximum }
  }
  let local_ack = [
    yes("e_reader_response_valid") && yes("i_reader_response_ready"),
    yes("e_engine_response_valid") && yes("i_engine_response_ready"),
  ]
  direct8_fair_require(
    ack == (local_ack[0] || local_ack[1]) && !(local_ack[0] && local_ack[1]),
    "d8g_routes",
  )
  if ack {
    direct8_fair_require(
      self.accepted &&
      read("i_response_tag") == self.global_tag &&
      read("e_route_response_fault") == 0UL,
      "d8g_routes",
    )
  }
  for (index, prefix) in [(0, "reader"), (1, "engine")] {
    let watch = self.watches[index]
    let own_grant = grant && selected == index
    let own_request = valid[index] && yes("e_" + prefix + "_request_ready")
    let cancel = watch.active && !watch.accepted && !valid[index]
    direct8_fair_require(
      !own_request || (watch.active && watch.granted),
      "d8g_watcher_history",
    )
    direct8_fair_require(
      !local_ack[index] || (watch.active && watch.accepted && watch.granted),
      "d8g_watcher_history",
    )
    if watch.active && !cancel {
      direct8_fair_require(
        local_ack[index] || watch.age < 12,
        "d8g_client_service_2t",
      )
      direct8_fair_require(
        watch.granted || own_grant || watch.age < 6,
        "d8g_regrant_t6",
      )
      watch.maximum = if watch.age > watch.maximum {
        watch.age
      } else {
        watch.maximum
      }
    }
    direct8_fair_require(
      !watch.accepted || (watch.granted && state == 2UL && owner == index),
      "d8g_watcher_history",
    )
    if local_ack[index] || cancel {
      watch.active = false
      watch.accepted = false
      watch.granted = false
      watch.age = 0
    } else if !watch.active && valid[index] {
      watch.active = true
      watch.age = 1
      watch.granted = own_grant || own_request
      watch.accepted = own_request
    } else if watch.active {
      watch.granted = watch.granted || own_grant
      watch.accepted = watch.accepted || own_request
      if watch.age < 15 {
        watch.age += 1
      }
    }
    if local_ack[index] {
      self.acks[index] += 1
    }
  }
  for
    (index, event, next) in [
      (0, "pop", 1UL),
      (1, "capture", 2UL),
      (2, "reserve", 3UL),
      (3, "finish", 0UL),
    ] {
    direct8_fair_require(
      !self.previous_head[index] || read("q_head_state") == next,
      "d8g_head_progress",
    )
    self.previous_head[index] = yes("q_head_" + event)
    if self.previous_head[index] {
      self.head_events[index] += 1
    }
  }
  for engine in 0..<3 {
    direct8_fair_require(
      !self.previous_done[engine] || read("q_engine_state_\{engine}") == 0UL,
      "d8g_engine_done_release",
    )
    self.previous_done[engine] = yes("q_engine_terminal_\{engine}")
    if self.previous_done[engine] {
      self.done_events[engine] += 1
    }
  }
  for entry in 0..<3 {
    direct8_fair_require(
      !self.previous_collect[entry] || yes("q_entry_terminal_\{entry}"),
      "d8g_collector_commit",
    )
    let mut collected = false
    for engine in 0..<3 {
      if yes("q_entry_collector_\{entry}_\{engine}") {
        collected = true
        self.collector_events[engine] += 1
      }
    }
    self.previous_collect[entry] = collected &&
      !yes("q_entry_allocate_\{entry}")
  }
  if grant {
    let prefix = if selected == 1 { "engine" } else { "reader" }
    self.payload = ["write", "address", "bytes", "mask", "data", "tag"].map(field => {
      read("i_" + prefix + "_" + field)
    })
    self.owner = selected
    self.global_tag = read("r_next_tag")
    self.active = true
    self.age = 1
    self.grants[selected] += 1
    if valid[0] && valid[1] {
      self.tied_grants += 1
    }
  } else if ack {
    self.active = false
    self.age = 0
  } else if self.active && self.age < 7 {
    self.age += 1
  }
  if request {
    self.accepted = true
    self.preference = 1UL - owner.to_uint64()
  } else if ack {
    self.accepted = false
  }
}

///|
fn direct8_arbiter_native_nodes(
  source : @ir.Module,
) -> Map[String, @ir.NodeId] raise {
  let fixture = direct8_arbiter_fixture()
  assert_eq(source, fixture.hardware())
  let nodes : Map[String, @ir.NodeId] = Map([])
  for
    binding in direct8_arbiter_aliases(fixture, direct8_arbiter_probe(fixture)) {
    nodes[binding.name] = binding.node
  }
  nodes
}

///|
test "direct8 native arbiter snapshot checks high address data and local tag bits" {
  for
    (root, client) in [
      ("address", "address"),
      ("data", "data"),
      ("local_tag", "tag"),
    ] {
    let observer = Direct8ArbiterNative::new()
    let frame : Map[String, UInt64] = {
      "i_reader_valid": 1UL,
      "e_grant": 1UL,
      "i_reader_address": 0xffffffffUL,
      "i_reader_data": 0x80000001UL,
      "i_reader_tag": 0x80000073UL,
    }
    let read : (String) -> UInt64 raise = name => frame.get(name).unwrap_or(0UL)
    observer.step(read)
    frame["e_grant"] = 0UL
    frame["r_state"] = 1UL
    for
      (target, original) in [
        ("address", "address"),
        ("data", "data"),
        ("local_tag", "tag"),
      ] {
      frame["r_" + target] = read("i_reader_" + original)
    }
    frame["r_" + root] = read("i_reader_" + client) ^ 0x80000000UL
    try observer.step(read) catch {
      BadFairEdge(label) => assert_eq(label, "d8g_snapshot_hold")
      error => fail("unexpected observer failure: \{error}")
    } noraise {
      _ => fail("high payload bit change must fail")
    }
  }
}

///|
test "direct8 native grant timer accepts inclusive ACK and does not freeze after response offer" {
  let observer = Direct8ArbiterNative::new()
  observer.active = true
  observer.accepted = true
  observer.age = 6
  observer.watches[0].active = true
  observer.watches[0].accepted = true
  observer.watches[0].granted = true
  observer.watches[0].age = 12
  observer.payload = [0UL, 0UL, 0UL, 0UL, 0UL, 0UL]
  let frame : Map[String, UInt64] = {
    "r_state": 2UL,
    "i_response_valid": 1UL,
    "i_reader_response_ready": 1UL,
    "e_reader_response_valid": 1UL,
    "e_response_accept": 1UL,
  }
  observer.step(name => frame.get(name).unwrap_or(0UL))
  assert_false(observer.active)
  observer.active = true
  observer.accepted = true
  observer.age = 6
  frame["i_reader_response_ready"] = 0UL
  frame["e_response_accept"] = 0UL
  try observer.step(name => frame.get(name).unwrap_or(0UL)) catch {
    BadFairEdge(label) => assert_eq(label, "d8g_local_service_t6")
    error => fail("unexpected observer failure: \{error}")
  } noraise {
    _ => fail("offered but unaccepted response cannot stop service time")
  }
}

///|
test "direct8 actual competing loader and Store requests preserve regrant and queue progress" {
  let packets = Array::makei(8, index => direct8_completion_packet(index % 4))
  for (index, selectors) in [(4, 1UL), (5, 256UL), (6, 65793UL), (7, 65536UL)] {
    packets[index][3] = selectors
  }
  let result = direct8_fair_native_run(
    packets,
    Array::make(8, 0UL),
    3,
    512,
    128,
    require_competing=true,
  )
  assert_eq((result.admitted, result.retired), (8, 8))
}
