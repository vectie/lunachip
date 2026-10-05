///|
fn run_dma_poison_epoch(
  context : FaultContext,
  owner : DmaPoisonOwner,
) -> DmaPoisonMeasurement raise {
  let simulator = context.trace.simulator
  let host = context.host
  if output_value(simulator, "consumer_count") != 5UL || host.pending is Some(_) {
    fail("DMA-poison replacement preceded complete signed setup")
  }
  dma_poison_replacement(host.memory)
  for position in 5..<11 {
    dma_poison_install(host.memory, position)
  }
  let requests_before = host.requests
  let accepted_writes : Array[Request] = []
  let mut published = false
  let mut retired = 0
  let mut loader_bytes = 0
  let mut storer_bytes = 0
  let mut owned : Request? = None
  let mut injection_cycle = 0
  let mut injection_active = 0UL
  let mut admitted = 0
  let mut held : CompletionSnapshot? = None
  let mut held_edges = 0
  let mut held_active_edges = 0
  let mut held_capture_edges = 0
  let mut quiet_edges = 0
  for _ in 0..<65536 {
    let active_before = output_value(simulator, "active_cycles")
    let capture_before = output_value(simulator, "capture_cycles")
    let consumer_before = output_value(simulator, "consumer_count")
    let was_poisoned = injection_cycle != 0
    let base_bus = host.drive(context.cycle + 1)
    // Packet admission precedes inner compute issue. Old setup counters may
    // remain visible in that gap; only the complete Run predicate arms an
    // injection. The finite bound rejects a genuinely missed owner window.
    let target = match host.pending {
      Some(response) if !was_poisoned &&
        response.delay == 0 &&
        dma_poison_owner_request(owner, response.request) &&
        loader_bytes > 0 &&
        storer_bytes > 0 &&
        consumer_before >= 9UL &&
        active_before > 0UL &&
        active_before < 78UL &&
        capture_before == 0UL => Some(response)
      _ => None
    }
    let injecting = target is Some(_)
    let bus : HostDrive = match target {
      Some(response) =>
        {
          ..base_bus,
          response_valid: 1UL,
          response_tag: response.tag,
          response_fault: 2UL,
          response_data: response.data,
        }
      None => base_bus
    }
    // Never ACK Fence200 until the already admitted MatMul physically drains.
    // Its hold is observation-driven, not an arbitrary fixed timeout.
    let holding = retired == 0 && (!was_poisoned || capture_before < 64UL)
    if holding && output_value(simulator, "completion_valid") == 1UL {
      let actual = completion_snapshot(simulator)
      if actual != { id: 200UL, fault: 0UL, bytes: 0UL, address: 0UL, } {
        fail("DMA-poison oldest Fence did not become a successful terminal")
      }
      match held {
        None => held = Some(actual)
        Some(previous) =>
          if actual != previous {
            fail("held successful Fence changed before a physical edge")
          }
      }
      held_edges += 1
    } else if holding && held is Some(_) {
      fail("held successful Fence lost valid before a physical edge")
    }
    if was_poisoned {
      let request = match owned {
        Some(request) => request
        None => fail("DMA-poison lost its accepted response owner")
      }
      dma_poison_assert_halted(context, request.address, admitted)
    }
    let events = context.tick(
      bus,
      publish_valid=if was_poisoned || !published { 1UL } else { 0UL },
      publish_producer=if was_poisoned { 12UL } else { 11UL },
      completion_ready=if holding { 0UL } else { 1UL },
    )
    if events.publication_accepted {
      if was_poisoned {
        fail("DMA-poison accepted a publication after halt")
      }
      published = true
    }
    if events.memory.accepted is Some(request) {
      if was_poisoned || injecting {
        fail("DMA-poison accepted another memory request at or after discovery")
      }
      if request.write == 1UL {
        accepted_writes.push(request)
      }
    }
    if events.memory.acknowledged is Some(request) {
      if injecting {
        let response = match target {
          Some(response) => response
          None =>
            fail("DMA-poison malformed ACK had no selected saved response")
        }
        if request != response.request ||
          bus.response_tag != request.tag ||
          bus.response_data != response.data ||
          bus.response_fault != 2UL ||
          output_value(simulator, "active_cycles") != active_before + 1UL {
          fail(
            "DMA-poison corruption was not owned on an advancing compute edge",
          )
        }
        owned = Some(request)
        injection_cycle = context.cycle
        injection_active = active_before
        admitted = output_value(simulator, "consumer_count").to_int()
        if admitted < 9 || admitted > 11 {
          fail(
            "DMA-poison discovery omitted accepted MatMul or invented a packet",
          )
        }
        dma_poison_assert_halted(context, request.address, admitted)
      } else {
        if was_poisoned {
          fail(
            "DMA-poison acknowledged a later response after bus ownership ended",
          )
        }
        if request.write == 1UL {
          storer_bytes += 4
        } else if request.address < 8192UL {
          loader_bytes += 1
        }
      }
    }
    if injecting && injection_cycle != context.cycle {
      fail("DMA-poison offered malformed response did not actually handshake")
    }
    if was_poisoned &&
      output_value(simulator, "consumer_count") != consumer_before {
      fail("DMA-poison atomically admitted another packet after discovery")
    }
    if holding && held is Some(previous) {
      if output_value(simulator, "completion_valid") != 1UL ||
        completion_snapshot(simulator) != previous {
        fail("held successful Fence changed across compute drainage")
      }
      let active_after = output_value(simulator, "active_cycles")
      let capture_after = output_value(simulator, "capture_cycles")
      if active_after > active_before {
        if active_after != active_before + 1UL {
          fail("DMA-poison held compute did not advance one active edge")
        }
        held_active_edges += 1
      }
      if capture_after > capture_before {
        if capture_after != capture_before + 1UL {
          fail("DMA-poison held capture did not advance one physical edge")
        }
        held_capture_edges += 1
      }
    }
    if events.completion is Some(actual) {
      let request = match owned {
        Some(request) => request
        None =>
          fail("DMA-poison retired Fence before discovery and compute drainage")
      }
      if retired >= admitted - 5 {
        fail("DMA-poison fabricated a completion for an unadmitted packet")
      }
      dma_poison_assert_drained(context)
      dma_poison_assert_completion(
        actual, retired, owner, request, loader_bytes, storer_bytes,
      )
      retired += 1
    }
    if injection_cycle != 0 &&
      retired == admitted - 5 &&
      events.completion is None {
      let request = match owned {
        Some(request) => request
        None => fail("DMA-poison quiet interval lost its owner")
      }
      dma_poison_assert_halted(context, request.address, admitted)
      dma_poison_assert_drained(context)
      if output_value(simulator, "completion_valid") != 0UL ||
        output_value(simulator, "memory_request_valid") != 0UL ||
        events.memory.accepted is Some(_) ||
        host.pending is Some(_) {
        fail("DMA-poison quiet interval exposed another obligation")
      }
      quiet_edges += 1
      if quiet_edges == 8 {
        break
      }
    }
  }
  let request = match owned {
    Some(request) => request
    None =>
      fail("DMA-poison selected owner never had an eligible actual response")
  }
  if !published ||
    injection_cycle == 0 ||
    injection_active == 0UL ||
    injection_active >= 78UL ||
    loader_bytes <= 0 ||
    loader_bytes >= 512 ||
    storer_bytes <= 0 ||
    storer_bytes >= 256 ||
    storer_bytes % 4 != 0 ||
    retired != admitted - 5 ||
    held_edges == 0 ||
    held_active_edges == 0 ||
    held_capture_edges != 64 ||
    quiet_edges != 8 ||
    host.pending is Some(_) ||
    host.held is Some(_) ||
    accepted_writes.length() !=
    storer_bytes / 4 + (if owner == Storer { 1 } else { 0 }) {
    fail("DMA-poison bounded owner/progress/drain obligations were incomplete")
  }
  verify_dma_poison_memory(host.memory, accepted_writes)
  {
    owner,
    request,
    loader_bytes,
    storer_bytes,
    injection_cycle,
    active_before: injection_active,
    admitted,
    held_edges,
    held_active_edges,
    held_capture_edges,
    quiet_edges,
    epoch_requests: host.requests - requests_before,
    accepted_writes: accepted_writes.length(),
  }
}
