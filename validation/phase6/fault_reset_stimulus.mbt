///|
priv struct PoisonMeasurement {
  loader_bytes : Int
  request_tag : UInt64
  injection_cycle : Int
  active_before : UInt64
  response_hold_edges : Int
  held_edges : Int
  held_advances : Int
  held_capture_edges : Int
  quiet_edges : Int
  epoch_requests : Int
}

///|
fn run_reader_poison(context : FaultContext) -> PoisonMeasurement raise {
  let simulator = context.trace.simulator
  let host = context.host
  let mut published = 0
  let mut offered = 2
  let mut retired = 0
  let mut loader_bytes = 0
  let mut owned_request : Request? = None
  let mut target_hold_edges = 0
  let mut injection_cycle = 0
  let mut injection_active = 0UL
  let mut hold_until = 0
  let mut held : CompletionSnapshot? = None
  let mut held_edges = 0
  let mut held_advances = 0
  let mut held_capture_edges = 0
  let mut quiet_edges = 0
  for _ in 0..<8192 {
    if offered == 2 && published == 2 && retired == 2 {
      if output_value(simulator, "consumer_count") != 2UL {
        fail("setup retirement did not permit Fence slot reuse")
      }
      for position in 2..<5 {
        fault_reset_install(host.memory, position, position)
      }
      offered = 5
    }
    if retired == 2 &&
      output_value(simulator, "completion_valid") == 1UL &&
      held is None {
      held = Some(completion_snapshot(simulator))
      hold_until = context.cycle + 1 + 32
    }
    let holding = retired == 2 && context.cycle + 1 < hold_until
    if holding {
      if output_value(simulator, "completion_valid") != 1UL ||
        held != Some(completion_snapshot(simulator)) {
        fail("oldest cancellation was not valid and immutable while held")
      }
      held_edges += 1
    }
    let active_before = output_value(simulator, "active_cycles")
    let capture_before = output_value(simulator, "capture_cycles")
    let consumer_before = output_value(simulator, "consumer_count")
    let base_bus = host.drive(context.cycle + 1)
    // Only the saved accepted first Fence byte is eligible for corruption.
    let target = match host.pending {
      Some(response) if owned_request == Some(response.request) =>
        Some(response)
      _ => None
    }
    let inject = target is Some(response) &&
      response.delay == 0 &&
      target_hold_edges > 0 &&
      active_before > 0UL &&
      active_before < 16UL
    let bus : HostDrive = match target {
      Some(response) =>
        {
          request_ready: base_bus.request_ready,
          response_valid: if inject {
            1UL
          } else {
            0UL
          },
          response_tag: if inject {
            response.tag + 1UL
          } else {
            response.tag
          },
          response_data: response.data,
          response_fault: 0UL,
        }
      None => base_bus
    }
    if target is Some(_) && !inject {
      target_hold_edges += 1
      if active_before >= 16UL {
        fail("owned Fence response missed the required advancing Run window")
      }
    }
    let publish = output_value(simulator, "configured") == 1UL &&
      published != offered
    let was_poisoned = injection_cycle != 0
    let events = context.tick(
      bus,
      config_valid=if output_value(simulator, "configured") == 0UL {
        1UL
      } else {
        0UL
      },
      publish_valid=if publish { 1UL } else { 0UL },
      publish_producer=offered.to_uint64(),
      completion_ready=if holding { 0UL } else { 1UL },
    )
    if events.publication_accepted {
      published = offered
    }
    if events.memory.accepted is Some(request) {
      if was_poisoned {
        fail("new memory transaction was accepted after poison")
      }
      if request.write == 0UL &&
        request.address == 3072UL &&
        consumer_before == 4UL {
        if owned_request is Some(_) {
          fail("Fence first byte request was accepted more than once")
        }
        owned_request = Some(request)
      }
    }
    if events.memory.acknowledged is Some(request) {
      if request.write == 0UL &&
        request.address >= 2048UL &&
        request.address < 2112UL {
        if was_poisoned || inject {
          fail("operand response retired after poison")
        }
        loader_bytes += 1
      }
      if owned_request == Some(request) {
        if !inject ||
          injection_cycle != 0 ||
          request.tag != (160 + loader_bytes).to_uint64() ||
          output_value(simulator, "active_cycles") != active_before + 1UL {
          fail(
            "reader corruption was not an owned response on an advancing Run edge",
          )
        }
        injection_cycle = context.cycle
        injection_active = active_before
      }
    }
    if inject && injection_cycle != context.cycle {
      fail("offered wrong-tag response did not actually handshake")
    }
    if holding {
      if output_value(simulator, "completion_valid") != 1UL ||
        held != Some(completion_snapshot(simulator)) {
        fail("held cancellation changed on a compute drainage edge")
      }
      if output_value(simulator, "active_cycles") > active_before {
        held_advances += 1
      }
      if output_value(simulator, "capture_cycles") > capture_before {
        held_capture_edges += 1
      }
    }
    if events.completion is Some(actual) {
      match retired {
        0 => assert_fault_completion(actual, 81UL, 0UL, 16UL)
        1 => assert_fault_completion(actual, 82UL, 0UL, 16UL)
        2 =>
          assert_fault_completion(actual, 83UL, 15UL, loader_bytes.to_uint64())
        3 => assert_fault_completion(actual, 84UL, 0UL, 0UL)
        _ => fail("Fence or duplicate completion escaped poisoned fetch")
      }
      retired += 1
    }
    if retired == 4 {
      context.assert_poison()
      context.assert_compute_drained()
      if output_value(simulator, "completion_valid") != 0UL ||
        events.memory.accepted is Some(_) ||
        host.pending is Some(_) {
        fail("poison quiet window exposed another packet or transaction")
      }
      quiet_edges += 1
      if quiet_edges == 8 {
        break
      }
    }
  }
  let request = match owned_request {
    Some(request) => request
    None => fail("first Fence byte was never actually accepted")
  }
  if injection_cycle == 0 ||
    injection_active == 0UL ||
    injection_active >= 16UL ||
    loader_bytes <= 0 ||
    loader_bytes >= 64 ||
    held_edges != 32 ||
    held_advances == 0 ||
    held_capture_edges != 1 ||
    quiet_edges != 8 ||
    published != 5 ||
    retired != 4 ||
    target_hold_edges == 0 ||
    host.requests != 161 + loader_bytes ||
    host.reads != 161 + loader_bytes ||
    host.writes != 0 {
    fail(
      "reader poison obligations missing: L=\{loader_bytes}, injection=\{injection_cycle}, active=\{injection_active}, held=\{held_edges}, advances=\{held_advances}, capture=\{held_capture_edges}, quiet=\{quiet_edges}, requests=\{host.requests}",
    )
  }
  {
    loader_bytes,
    request_tag: request.tag,
    injection_cycle,
    active_before: injection_active,
    response_hold_edges: target_hold_edges,
    held_edges,
    held_advances,
    held_capture_edges,
    quiet_edges,
    epoch_requests: host.requests,
  }
}

///|
fn run_pending_reset(context : FaultContext) -> Int raise {
  context.joint_reset()
  fault_reset_install(context.host.memory, 0, 5)
  let requests_before = context.host.requests
  let mut published = false
  let mut pending_cycle = 0
  for _ in 0..<8192 {
    let simulator = context.trace.simulator
    let events = context.tick(
      context.host.drive(context.cycle + 1),
      config_valid=if output_value(simulator, "configured") == 0UL {
        1UL
      } else {
        0UL
      },
      publish_valid=if output_value(simulator, "configured") == 1UL &&
        !published {
        1UL
      } else {
        0UL
      },
      publish_producer=1UL,
    )
    if events.publication_accepted {
      published = true
    }
    if events.completion is Some(_) ||
      output_value(simulator, "completion_valid") != 0UL {
      fail(
        "interrupted Load91 completed before its pending first operand response",
      )
    }
    if events.memory.accepted is Some(request) {
      if context.host.requests == requests_before + 1 && request.tag != 0UL {
        fail("first post-poison reset request did not restart its tag epoch")
      }
      if request.address == 2048UL {
        if request.write != 0UL ||
          request.tag != 32UL ||
          context.host.requests - requests_before != 33 ||
          context.host.pending is None {
          fail("pending reset did not target the owned operand tag32")
        }
        pending_cycle = context.cycle
        break
      }
    }
  }
  if !published || pending_cycle == 0 {
    fail("pending operand reset checkpoint was not reached")
  }
  match context.host.pending {
    Some(response) =>
      if response.request.address != 2048UL || response.tag != 32UL {
        fail("reset target response lost saved ownership")
      }
    None => fail("pending operand response was prematurely consumed")
  }
  context.joint_reset()
  pending_cycle
}

///|
fn run_stale_slot_recovery(context : FaultContext) -> Unit raise {
  fault_reset_install(context.host.memory, 0, 6)
  fault_reset_install(context.host.memory, 1, 7)
  let requests_before = context.host.requests
  let mut published = false
  let mut retired = 0
  for _ in 0..<8192 {
    let simulator = context.trace.simulator
    let events = context.tick(
      context.host.drive(context.cycle + 1),
      config_valid=if output_value(simulator, "configured") == 0UL {
        1UL
      } else {
        0UL
      },
      publish_valid=if output_value(simulator, "configured") == 1UL &&
        !published {
        1UL
      } else {
        0UL
      },
      publish_producer=2UL,
    )
    if events.publication_accepted {
      published = true
    }
    if events.memory.accepted is Some(request) &&
      context.host.requests == requests_before + 1 &&
      request.tag != 0UL {
      fail("second reset failed to restart global tags")
    }
    if events.completion is Some(actual) {
      match retired {
        0 => assert_fault_completion(actual, 92UL, 4UL, 0UL)
        1 => assert_fault_completion(actual, 93UL, 0UL, 0UL)
        _ =>
          fail("reset recovery produced an interrupted or duplicate completion")
      }
      retired += 1
    }
    if output_value(simulator, "ring_fault_valid") != 0UL ||
      output_value(simulator, "transport_halted") != 0UL ||
      output_value(simulator, "halted") != 0UL {
      fail("joint reset did not release poisoned ownership")
    }
    if retired == 2 && context.host.pending is None {
      break
    }
  }
  if !published ||
    retired != 2 ||
    context.host.requests - requests_before != 64 ||
    context.host.next_tag != 64UL ||
    output_value(context.trace.simulator, "producer_count") != 2UL ||
    output_value(context.trace.simulator, "consumer_count") != 2UL {
    fail("reset recovery did not finish exact two descriptor obligations")
  }
  for
    name in [
      "accepted_steps", "active_cycles", "elapsed_cycles", "stall_cycles", "capture_cycles",
      "ring_fault_code", "ring_fault_address", "transport_fault_address",
    ] {
    if output_value(context.trace.simulator, name) != 0UL {
      fail("stale-slot MatMul improperly used pre-reset state: \{name}")
    }
  }
}

///|
fn generate_fault_reset_run(
  design : @ir.Design,
  hardware : @ir.Module,
  ports : ReadOnlyArray[@verilator.HarnessPort],
) -> FixtureRun raise {
  let context = fault_context(hardware, ports)
  let poison = run_reader_poison(context)
  let pending_cycle = run_pending_reset(context)
  run_stale_slot_recovery(context)
  if context.host.requests != 258 + poison.loader_bytes ||
    context.host.reads != context.host.requests ||
    context.host.writes != 0 ||
    context.host.stalls == 0 {
    fail("fault/reset lifetime request counts did not match measured progress")
  }
  verify_fault_reset_memory(context.host.memory)
  context.trace.finish(
    design,
    context.cycle,
    "LUNACHIP-PHASE6-FIXTURE 1\nPROFILE flux-tile-0/fetched-concurrent\nDEVICE-ABI 1.0\nDESCRIPTOR 0.2\nCYCLES \{context.cycle}\nCOMPLETIONS 6\nREQUESTS \{context.host.requests}\nREAD-BYTES \{context.host.reads}\nWRITE-BYTES 0\nREADER-FAULT 5\nTRANSPORT-FAULT-ADDRESS 3072\nLOADER-CANCEL-FAULT 15\nLOADER-COMMITTED-BYTES \{poison.loader_bytes}\nOWNED-READER-TAG \{poison.request_tag}\nOWNED-RESPONSE-HOLD-CYCLES \{poison.response_hold_edges}\nPOISON-EPOCH-REQUESTS \{poison.epoch_requests}\nPOISON-CYCLE \{poison.injection_cycle}\nPOISON-ACTIVE-BEFORE \{poison.active_before}\nPOISON-ACTIVE-ADVANCE 1\nCOMPLETION-HOLD-CYCLES \{poison.held_edges}\nHELD-COMPUTE-ADVANCES \{poison.held_advances}\nHELD-CAPTURE-EDGES \{poison.held_capture_edges}\nPOISON-QUIET-CYCLES \{poison.quiet_edges}\nPOISON-PRODUCER 5\nPOISON-CONSUMER 4\nDRAIN-ACCEPTED-STEPS 16\nDRAIN-ACTIVE-CYCLES 16\nDRAIN-ELAPSED-CYCLES 17\nDRAIN-STALL-CYCLES 0\nDRAIN-CAPTURE-CYCLES 1\nJOINT-RESETS 2\nPENDING-RESET-CYCLE \{pending_cycle}\nPENDING-RESET-REQUESTS 33\nPENDING-RESET-TAG 32\nSTALE-SLOT-FAULT 4\nRECOVERY-FENCE-FAULT 0\nRECOVERY-REQUESTS 64\nRECOVERY-NEXT-TAG 64\nHOST-BYTES match\nCLAIM generated-reference-only\nEND\n",
  )
}
