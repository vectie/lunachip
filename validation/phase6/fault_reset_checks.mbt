///|
priv struct FaultEvents {
  memory : HostEvents
  publication_accepted : Bool
  completion : CompletionSnapshot?
}

///|
priv struct FaultContext {
  trace : FixtureTrace
  host : Host
  config_base : UInt64
  cycle_limit : Int
  mut cycle : Int
}

///|
fn fault_context(
  hardware : @ir.Module,
  ports : ReadOnlyArray[@verilator.HarnessPort],
  host? : Host,
  config_base? : UInt64 = 3072UL,
  cycle_limit? : Int = 8192,
) -> FaultContext raise {
  let host = match host {
    Some(host) => host
    None => fault_reset_host()
  }
  let trace = fixture_trace(hardware, ports)
  trace.drive(
    {
      reset: 1UL,
      config_valid: 0UL,
      config_base,
      publish_valid: 0UL,
      publish_producer: 0UL,
      completion_ready: 0UL,
      bus: {
        request_ready: 0UL,
        response_valid: 0UL,
        response_tag: 0UL,
        response_fault: 0UL,
        response_data: 0UL,
      },
    },
    0UL,
  )
  trace.edge(0UL, observe=false)
  { trace, host, config_base, cycle_limit, cycle: 0, }
}

///|
fn FaultContext::tick(
  self : FaultContext,
  bus : HostDrive,
  reset? : UInt64 = 0UL,
  config_valid? : UInt64 = 0UL,
  publish_valid? : UInt64 = 0UL,
  publish_producer? : UInt64 = 0UL,
  completion_ready? : UInt64 = 1UL,
) -> FaultEvents raise {
  if self.cycle >= self.cycle_limit {
    fail("fault/reset fixture exceeded its finite cycle bound")
  }
  self.cycle += 1
  self.trace.drive(
    {
      reset,
      config_valid,
      config_base: self.config_base,
      publish_valid,
      publish_producer,
      completion_ready,
      bus,
    },
    self.cycle.to_uint64(),
  )
  let simulator = self.trace.simulator
  if reset == 1UL {
    for
      name in [
        "config_ready", "publish_ready", "completion_valid", "memory_request_valid",
        "memory_response_ready", "ring_fault_valid", "transport_halted", "halted",
      ] {
      if output_value(simulator, name) != 0UL {
        fail("reset did not suppress pre-edge \{name}")
      }
    }
  }
  let publication_accepted = publish_valid == 1UL &&
    output_value(simulator, "publish_ready") == 1UL
  let completion = if completion_ready == 1UL &&
    output_value(simulator, "completion_valid") == 1UL {
    Some(completion_snapshot(simulator))
  } else {
    None
  }
  // Reset legitimately withdraws a stalled request and suppresses a saved
  // response. It is a joint flush, not a normal channel handshake.
  let memory : HostEvents = if reset == 1UL {
    { accepted: None, acknowledged: None, }
  } else {
    self.host.accept(simulator, bus)
  }
  self.trace.edge(self.cycle.to_uint64(), observe=true)
  { memory, publication_accepted, completion, }
}

///|
fn FaultContext::joint_reset(self : FaultContext) -> Unit raise {
  let requests = self.host.requests
  let reads = self.host.reads
  // Preserve the old accepted obligation across the reset assertion/edge.
  // Present it even if its modeled delay has not elapsed; reset must mask it.
  let bus : HostDrive = match self.host.pending {
    Some(response) =>
      {
        request_ready: 1UL,
        response_valid: 1UL,
        response_tag: response.tag,
        response_fault: 0UL,
        response_data: response.data,
      }
    None =>
      {
        request_ready: 1UL,
        response_valid: 0UL,
        response_tag: 0UL,
        response_fault: 0UL,
        response_data: 0UL,
      }
  }
  let events = self.tick(
    bus,
    reset=1UL,
    config_valid=1UL,
    publish_valid=1UL,
    publish_producer=4UL,
  )
  self.host.flush()
  if events.publication_accepted ||
    events.completion is Some(_) ||
    events.memory.accepted is Some(_) ||
    events.memory.acknowledged is Some(_) ||
    self.host.requests != requests ||
    self.host.reads != reads ||
    self.host.next_tag != 0UL ||
    self.host.pending is Some(_) ||
    self.host.held is Some(_) {
    fail("joint reset did not flush only transport obligations")
  }
  for
    name in [
      "configured", "producer_count", "consumer_count", "queue_occupancy", "ring_fault_valid",
      "ring_fault_code", "ring_fault_address", "transport_halted", "transport_fault_address",
      "halted", "completion_valid", "accepted_steps", "active_cycles", "elapsed_cycles",
      "stall_cycles", "capture_cycles",
    ] {
    if output_value(self.trace.simulator, name) != 0UL {
      fail("joint reset did not clear \{name}")
    }
  }
}

///|
fn FaultContext::assert_poison(self : FaultContext) -> Unit raise {
  let simulator = self.trace.simulator
  for
    (name, expected) in [
      ("configured", 1UL),
      ("transport_halted", 1UL),
      ("halted", 1UL),
      ("ring_fault_valid", 1UL),
      ("ring_fault_code", 5UL),
      ("ring_fault_address", 3072UL),
      ("transport_fault_address", 3072UL),
      ("producer_count", 5UL),
      ("consumer_count", 4UL),
    ] {
    if output_value(simulator, name) != expected {
      fail("owned reader poison \{name} did not equal \{expected}")
    }
  }
}

///|
fn FaultContext::assert_compute_drained(self : FaultContext) -> Unit raise {
  for
    (name, expected) in [
      ("accepted_steps", 16UL),
      ("active_cycles", 16UL),
      ("elapsed_cycles", 17UL),
      ("stall_cycles", 0UL),
      ("capture_cycles", 1UL),
    ] {
    if output_value(self.trace.simulator, name) != expected {
      fail("accepted compute did not drain: \{name}")
    }
  }
}

///|
fn assert_fault_completion(
  actual : CompletionSnapshot,
  id : UInt64,
  fault : UInt64,
  bytes : UInt64,
) -> Unit raise {
  if actual != { id, fault, bytes, address: 0UL, } {
    fail(
      "unexpected fault/reset completion: \{Repr(actual.id)}, fault \{actual.fault}, bytes \{actual.bytes}",
    )
  }
}
