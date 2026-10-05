///|
priv struct RemoteFaultMeasurement {
  requests : Array[Int]
  acknowledgements : Array[Int]
  mut failed_acks : Int
  mut store_ack_bytes : Int
  mut refills : Int
  mut partial_checked : Bool
  mut rejected_counters : Array[UInt64]?
  mut rejected_reads : Int
  mut rejected_operands : Int
  mut rejected_c0_writes : Int
  mut rejected_c1_writes : Int
  mut recovery_active_edges : Int
  mut recovery_capture_edges : Int
}

///|
fn remote_fault_measurement() -> RemoteFaultMeasurement {
  {
    requests: [0, 0, 0],
    acknowledgements: [0, 0, 0],
    failed_acks: 0,
    store_ack_bytes: 0,
    refills: 0,
    partial_checked: false,
    rejected_counters: None,
    rejected_reads: 0,
    rejected_operands: 0,
    rejected_c0_writes: 0,
    rejected_c1_writes: 0,
    recovery_active_edges: 0,
    recovery_capture_edges: 0,
  }
}

///|
fn remote_fault_counters(simulator : @sim.Simulator) -> Array[UInt64] raise {
  [
    for
      name in [
        "accepted_steps", "active_cycles", "elapsed_cycles", "stall_cycles", "capture_cycles",
      ] => output_value(simulator, name)
  ]
}

///|
fn remote_fault_assert_unpoisoned(simulator : @sim.Simulator) -> Unit raise {
  for
    name in [
      "ring_fault_valid", "ring_fault_code", "ring_fault_address", "transport_halted",
      "transport_fault_address", "halted",
    ] {
    if output_value(simulator, name) != 0UL {
      fail("matching remote failure changed reader/transport state: " + name)
    }
  }
}

///|
fn remote_fault_request_class(request : Request) -> Int raise {
  if request.write == 0UL {
    if request.address >= 3072UL && request.address < 3200UL {
      0
    } else if remote_fault_read_allowed(request.address.to_int()) {
      1
    } else {
      fail("remote-fault unexpected accepted operand address")
    }
  } else if request.write == 1UL &&
    remote_fault_write_allowed(request.address.to_int()) {
    2
  } else {
    fail("remote-fault unexpected accepted write")
  }
}

///|
fn RemoteFaultMeasurement::record(
  self : RemoteFaultMeasurement,
  state : RemoteFaultHostState,
  events : FaultEvents,
  bus : HostDrive,
  offered : Int,
) -> Unit raise {
  if events.memory.accepted is Some(request) {
    let class = remote_fault_request_class(request)
    self.requests[class] += 1
    if request.write == 1UL &&
      (request.address == 1792UL || request.address == 1796UL) {
      // Both stores must be correct individually: final memory alone would
      // let the second overwrite conceal an incorrect first C1 transfer.
      let words = remote_fault_expected_results()[1]
      let index = ((request.address - 1792UL) / 4UL).to_int()
      let bits = words[index].to_int64().reinterpret_as_uint64() & 0xffffffffUL
      if request.data != bits {
        fail("accepted C1 word differs from its independent matrix oracle")
      }
    }
    if offered == 12 {
      match class {
        0 => self.rejected_reads += 1
        1 => {
          self.rejected_operands += 1
          fail("failed B0 generation issued a dependent operand read")
        }
        _ =>
          if request.address == 1792UL || request.address == 1796UL {
            self.rejected_c1_writes += 1
          } else {
            self.rejected_c0_writes += 1
            fail("failed C0 generation issued a stale or premature store")
          }
      }
    }
    if offered == 9 && request.write == 0UL && request.address == 772UL {
      fail("failed B0 reload requested its fourth byte")
    }
  }
  if events.memory.acknowledged is Some(request) {
    self.acknowledgements[remote_fault_request_class(request)] += 1
    if bus.response_fault == 1UL {
      let owner = if request.write == 1UL {
        state.store_failure
      } else {
        state.load_failure
      }
      if owner != Some(request) ||
        bus.response_tag != request.tag ||
        request.address != (if request.write == 1UL { 1540UL } else { 771UL }) {
        fail("remote-fault ACK lost its actual selected accepted owner")
      }
      self.failed_acks += 1
    } else if bus.response_fault == 0UL {
      if request.write == 1UL {
        self.store_ack_bytes += 4
      }
    } else {
      fail("remote-fault replay accepted an unintended protocol status")
    }
  }
}

///|
fn RemoteFaultMeasurement::check_final(
  self : RemoteFaultMeasurement,
  context : FaultContext,
  state : RemoteFaultHostState,
  published : Int,
  retired : Int,
) -> Unit raise {
  let host = context.host
  if retired != 16 ||
    published != 16 ||
    self.refills != 5 ||
    !self.partial_checked ||
    self.requests != [512, 15, 10] ||
    self.acknowledgements != self.requests ||
    self.failed_acks != 2 ||
    self.store_ack_bytes != 36 ||
    state.store_ack_bytes != 36 ||
    state.write_effect_bytes != 38 ||
    state.store_words != 10 ||
    state.store_failure is None ||
    state.load_failure is None ||
    state.replacement_reads != 3 ||
    state.replacement_ack_bytes != 2 ||
    host.requests != 537 ||
    host.reads != 527 ||
    host.writes != 40 ||
    host.next_tag != 537UL ||
    host.pending is Some(_) ||
    host.held is Some(_) ||
    host.stalls == 0 ||
    self.rejected_reads != 96 ||
    self.rejected_operands != 0 ||
    self.rejected_c0_writes != 0 ||
    self.rejected_c1_writes != 2 ||
    self.recovery_active_edges != 3 ||
    self.recovery_capture_edges != 2 ||
    output_value(context.trace.simulator, "producer_count") != 16UL ||
    output_value(context.trace.simulator, "consumer_count") != 16UL ||
    remote_fault_counters(context.trace.simulator) != [3UL, 3UL, 4UL, 0UL, 2UL] {
    fail("remote-fault replay did not finish its exact accepted obligations")
  }
}
