///|
priv struct CompletionSnapshot {
  id : UInt64
  fault : UInt64
  bytes : UInt64
  address : UInt64
} derive(Eq)

///|
fn completion_snapshot(simulator : @sim.Simulator) -> CompletionSnapshot raise {
  {
    id: output_value(simulator, "completion_id"),
    fault: output_value(simulator, "completion_fault"),
    bytes: output_value(simulator, "completion_bytes_completed"),
    address: output_value(simulator, "completion_fault_address"),
  }
}

///|
fn generate_concurrent_run(
  design : @ir.Design,
  hardware : @ir.Module,
  ports : ReadOnlyArray[@verilator.HarnessPort],
) -> FixtureRun raise {
  let trace = fixture_trace(hardware, ports)
  let simulator = trace.simulator
  let host = concurrent_host()
  trace.drive(
    {
      reset: 1UL,
      config_valid: 0UL,
      config_base: 3072UL,
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
  let mut configured = false
  let mut offered = 3
  let mut published = 0
  let mut retired = 0
  let mut cycles = 0
  let mut hold_until = 0
  let mut held_completion : CompletionSnapshot? = None
  let mut held_progress = 0
  let mut held_edges = 0
  let mut descriptor_overlap = 0
  let mut operand_overlap = 0
  let mut store_overlap = 0
  let mut advancing_edges = 0
  let mut store_ack_cycle = 0
  let mut mat_visible_cycle = 0
  let ids : Array[UInt64] = [
    61UL, 62UL, 63UL, 64UL, 65UL, 77UL, 77UL, 77UL, 78UL, 79UL,
  ]
  let progress : Array[UInt64] = [
    1UL, 1UL, 0UL, 512UL, 512UL, 0UL, 4UL, 512UL, 0UL, 4UL,
  ]
  for cycle in 1..<=32768 {
    // Setup is drained before the measured four-packet group is published.
    // Reuse only consumed host slots; never overwrite a published live packet.
    let next = if published == 3 && retired == 3 {
      5
    } else if published == 5 && retired == 5 {
      9
    } else if published == 9 && retired == 9 {
      10
    } else {
      offered
    }
    if next != offered {
      if output_value(simulator, "consumer_count") < published.to_uint64() {
        fail("attempted ring reuse before prior packets were consumed")
      }
      for position in offered..<next {
        concurrent_install(host.memory, position)
      }
      offered = next
    }
    if retired == 5 && output_value(simulator, "completion_valid") == 1UL {
      let snapshot = completion_snapshot(simulator)
      match held_completion {
        None => {
          held_completion = Some(snapshot)
          hold_until = cycle + 64
        }
        Some(previous) =>
          if snapshot != previous {
            fail("oldest MatMul completion changed while held")
          }
      }
      if mat_visible_cycle == 0 {
        mat_visible_cycle = cycle - 1
      }
    }
    let row : InputRow = {
      reset: 0UL,
      config_valid: if configured {
        0UL
      } else {
        1UL
      },
      config_base: 3072UL,
      publish_valid: if output_value(simulator, "configured") == 1UL &&
        offered != published {
        1UL
      } else {
        0UL
      },
      publish_producer: offered.to_uint64(),
      completion_ready: if cycle < hold_until {
        0UL
      } else {
        1UL
      },
      bus: host.drive(cycle),
    }
    let cycle_u64 = cycle.to_uint64()
    trace.drive(row, cycle_u64)
    if row.config_valid == 1UL && output_value(simulator, "config_ready") == 1UL {
      configured = true
    }
    if row.publish_valid == 1UL &&
      output_value(simulator, "publish_ready") == 1UL {
      published = offered
    }
    let holding = retired == 5 &&
      row.completion_ready == 0UL &&
      output_value(simulator, "completion_valid") == 1UL
    if holding {
      held_edges += 1
      if held_completion != Some(completion_snapshot(simulator)) {
        fail("held completion lost its identity or progress")
      }
    }
    if row.completion_ready == 1UL &&
      output_value(simulator, "completion_valid") == 1UL {
      let snapshot = completion_snapshot(simulator)
      if retired >= ids.length() ||
        snapshot.id != ids[retired] ||
        snapshot.fault != 0UL ||
        snapshot.bytes != progress[retired] ||
        snapshot.address != 0UL {
        fail("unexpected concurrent ordered completion ordinal \{retired}")
      }
      retired += 1
    }
    let active_before = output_value(simulator, "active_cycles")
    let events = host.accept(simulator, row.bus)
    trace.edge(cycle_u64, observe=true)
    let active_after = output_value(simulator, "active_cycles")
    // Old K1 counters remain held during setup. Only positive changes after
    // publication of the measured group can belong to the new K512 Run.
    if published >= 9 && active_after > active_before {
      if active_after != active_before + 1UL {
        fail("unexpected active counter advance")
      }
      advancing_edges += 1
      if events.accepted is Some(request) {
        if request.write == 1UL && request.address == 2800UL {
          store_overlap += 1
        } else if request.write == 0UL &&
          request.address >= 3072UL &&
          request.address < 3200UL {
          descriptor_overlap += 1
        } else if request.write == 0UL &&
          request.address >= 2048UL &&
          request.address < 2560UL {
          operand_overlap += 1
        }
      }
    }
    // Response identity comes from the host's saved accepted request, not
    // request outputs after the arbiter has moved to another client.
    if events.acknowledged is Some(request) &&
      request.write == 1UL &&
      request.address == 2800UL {
      if store_ack_cycle != 0 {
        fail("old result store acknowledged twice")
      }
      store_ack_cycle = cycle
    }
    if holding &&
      events.accepted is Some(request) &&
      request.write == 0UL &&
      request.address >= 2048UL &&
      request.address < 2560UL {
      held_progress += 1
    }
    if mat_visible_cycle == 0 &&
      retired == 5 &&
      output_value(simulator, "completion_valid") == 1UL {
      mat_visible_cycle = cycle
    }
    cycles = cycle
    if output_value(simulator, "ring_fault_valid") != 0UL ||
      output_value(simulator, "transport_halted") != 0UL {
      fail("concurrent successful fixture encountered a device fault")
    }
    if retired == 10 && host.pending is None {
      break
    }
  }
  if retired != 10 ||
    published != 10 ||
    held_edges != 64 ||
    held_progress == 0 ||
    descriptor_overlap == 0 ||
    operand_overlap == 0 ||
    store_overlap == 0 ||
    advancing_edges != 512 ||
    store_ack_cycle == 0 ||
    mat_visible_cycle <= store_ack_cycle {
    fail(
      "required measured overlap missing: descriptor=\{descriptor_overlap}, operand=\{operand_overlap}, store=\{store_overlap}, Run=\{advancing_edges}, held-progress=\{held_progress}, held-edges=\{held_edges}, store-ACK=\{store_ack_cycle}, Mat-visible=\{mat_visible_cycle}, retired=\{retired}",
    )
  }
  if host.stalls == 0 ||
    host.requests != 1860 ||
    host.reads != 1858 ||
    host.writes != 8 ||
    output_value(simulator, "producer_count") != 10UL ||
    output_value(simulator, "consumer_count") != 10UL ||
    output_value(simulator, "accepted_steps") != 512UL ||
    output_value(simulator, "elapsed_cycles") != 513UL ||
    output_value(simulator, "active_cycles") != 512UL ||
    output_value(simulator, "stall_cycles") != 0UL ||
    output_value(simulator, "capture_cycles") != 1UL {
    fail("concurrent fixture did not finish exact byte/counter obligations")
  }
  let (old_result, new_result) = verify_concurrent_memory(host.memory)
  trace.finish(
    design,
    cycles,
    "LUNACHIP-PHASE6-FIXTURE 1\nPROFILE flux-tile-0/fetched-concurrent\nDEVICE-ABI 1.0\nDESCRIPTOR 0.2\nCYCLES \{cycles}\nCOMPLETIONS 10\nREQUESTS 1860\nREAD-BYTES 1858\nWRITE-BYTES 8\nOLD-RESULT \{old_result}\nRESULT \{new_result}\nORACLE match\nRING-SLOT-REUSE true\nCOMPLETION-HOLD-CYCLES \{held_edges}\nHELD-OPERAND-REQUESTS \{held_progress}\nRUN-ADVANCING-EDGES \{advancing_edges}\nRUN-DESCRIPTOR-READS \{descriptor_overlap}\nRUN-OPERAND-READS \{operand_overlap}\nRUN-STORE-WRITES \{store_overlap}\nOLD-STORE-ACK-CYCLE \{store_ack_cycle}\nMAT-COMPLETION-CYCLE \{mat_visible_cycle}\nCLAIM generated-reference-only\nEND\n",
  )
}
