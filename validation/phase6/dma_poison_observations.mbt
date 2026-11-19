///|
priv enum DmaPoisonOwner {
  Loader
  Storer
} derive(Eq)

///|
priv struct DmaPoisonMeasurement {
  owner : DmaPoisonOwner
  request : Request
  loader_bytes : Int32
  storer_bytes : Int32
  injection_cycle : Int32
  active_before : UInt64
  admitted : Int32
  held_edges : Int32
  held_active_edges : Int32
  held_capture_edges : Int32
  quiet_edges : Int32
  epoch_requests : Int32
  accepted_writes : Int32
}

///|
fn dma_poison_owner_request(owner : DmaPoisonOwner, request : Request) -> Bool {
  match owner {
    Loader => request.write == 0UL && request.address < 8192UL
    Storer => request.write == 1UL
  }
}

///|
fn dma_poison_assert_halted(
  context : FaultContext,
  address : UInt64,
  admitted : Int32,
) -> Unit raise {
  for
    (name, expected) in [
      ("configured", 1UL),
      ("transport_halted", 1UL),
      ("halted", 1UL),
      ("transport_fault_address", address),
      ("ring_fault_valid", 0UL),
      ("ring_fault_code", 0UL),
      ("ring_fault_address", 0UL),
      ("publish_ready", 0UL),
      ("producer_count", 11UL),
      ("consumer_count", admitted.to_uint64()),
    ] {
    if output_value(context.trace.simulator, name) != expected {
      fail("DMA-owned poison did not retain public \{name}")
    }
  }
}

///|
fn dma_poison_assert_drained(context : FaultContext) -> Unit raise {
  for
    (name, expected) in [
      ("accepted_steps", 78UL),
      ("active_cycles", 78UL),
      ("elapsed_cycles", 79UL),
      ("stall_cycles", 0UL),
      ("capture_cycles", 64UL),
    ] {
    if output_value(context.trace.simulator, name) != expected {
      fail("DMA-poison accepted compute did not drain \{name}")
    }
  }
}

///|
fn dma_poison_assert_completion(
  actual : CompletionSnapshot,
  ordinal : Int32,
  owner : DmaPoisonOwner,
  request : Request,
  loader_bytes : Int32,
  storer_bytes : Int32,
) -> Unit raise {
  let expected : CompletionSnapshot = match ordinal {
    0 => { id: 200UL, fault: 0UL, bytes: 0UL, address: 0UL, }
    1 =>
      {
        id: 201UL,
        fault: if owner == Loader {
          10UL
        } else {
          15UL
        },
        bytes: loader_bytes.to_uint64(),
        address: if owner == Loader {
          request.address
        } else {
          0UL
        },
      }
    2 =>
      {
        id: 202UL,
        fault: if owner == Storer {
          10UL
        } else {
          15UL
        },
        bytes: storer_bytes.to_uint64(),
        address: if owner == Storer {
          request.address
        } else {
          0UL
        },
      }
    3 => { id: 203UL, fault: 0UL, bytes: 0UL, address: 0UL, }
    4 | 5 =>
      {
        id: (200 + ordinal).to_uint64(),
        fault: 15UL,
        bytes: 0UL,
        address: 0UL,
      }
    _ => fail("DMA-poison completion exceeded the admitted fault prefix")
  }
  if actual != expected {
    fail("DMA-poison unexpected ordered completion ordinal \{ordinal}")
  }
}

///|
fn dma_poison_audit(measured : DmaPoisonMeasurement) -> String {
  let prefix = match measured.owner {
    Loader => "LOADER"
    Storer => "STORER"
  }
  let summary = StringBuilder()
  for
    (name, value) in [
      ("REQUEST-TAG", measured.request.tag),
      ("FAULT-ADDRESS", measured.request.address),
      ("LOADER-ACK-BYTES", measured.loader_bytes.to_uint64()),
      ("STORER-ACK-BYTES", measured.storer_bytes.to_uint64()),
      ("DISCOVERY-CYCLE", measured.injection_cycle.to_uint64()),
      ("DISCOVERY-ACTIVE", measured.active_before),
      ("ADMITTED-PREFIX", measured.admitted.to_uint64()),
      ("COMPLETIONS", (measured.admitted - 5).to_uint64()),
      ("HELD-FENCE-EDGES", measured.held_edges.to_uint64()),
      ("HELD-ACTIVE-EDGES", measured.held_active_edges.to_uint64()),
      ("HELD-CAPTURE-EDGES", measured.held_capture_edges.to_uint64()),
      ("QUIET-EDGES", measured.quiet_edges.to_uint64()),
      ("EPOCH-REQUESTS", measured.epoch_requests.to_uint64()),
      ("ACCEPTED-WRITES", measured.accepted_writes.to_uint64()),
    ] {
    summary.write_string("\{prefix}-\{name} \{value}\n")
  }
  for
    (name, value) in [
      ("DISCOVERY-ACTIVE-ADVANCE", "1"),
      ("MALFORMED-ACKS", "1"),
      ("OWNER-FAULT", "10"),
      ("SIBLING-FAULT", "15"),
      ("READER-RING-FAULT", "0"),
      ("NO-AFTER-POISON-ISSUE", "true"),
      ("HELD-TERMINAL-STABLE", "true"),
      ("DRAIN-ACCEPTED-STEPS", "78"),
      ("DRAIN-ACTIVE-CYCLES", "78"),
      ("DRAIN-ELAPSED-CYCLES", "79"),
      ("DRAIN-STALL-CYCLES", "0"),
      ("DRAIN-CAPTURE-CYCLES", "64"),
      ("ORACLE", "match"),
      ("HOST-BYTES", "16384 match"),
      ("RESETS", "2"),
      ("RECOVERY-COMPLETIONS", "2"),
      ("RECOVERY-TAG", "0"),
      ("RECOVERY-STALE-SLOT-FAULT", "4"),
      ("RECOVERY-FENCE-FAULT", "0"),
      ("RESPONSE-DELAY", "1"),
    ] {
    summary.write_string("\{prefix}-\{name} \{value}\n")
  }
  summary.to_string()
}
