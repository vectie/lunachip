///|
fn writer_fault_counters(simulator : @sim.Simulator) -> Array[UInt64] raise {
  [
    for
      name in [
        "accepted_steps", "active_cycles", "elapsed_cycles", "stall_cycles", "capture_cycles",
      ] => output_value(simulator, name)
  ]
}

///|
// Classify only accepted public requests (and the host's saved ACK identity).
// Neither the descriptor workload nor a modeled command can stand in for DMA.
fn writer_fault_request_class(request : Request) -> Int raise {
  if request.write == 0UL {
    if request.address >= 3072UL && request.address < 3200UL {
      0
    } else if request.address == 512UL ||
      request.address == 640UL ||
      request.address == 768UL ||
      request.address == 896UL ||
      request.address == 1024UL {
      1
    } else {
      fail("writer-fault replay read an unexpected host byte")
    }
  } else if request.write == 1UL &&
    (
      request.address == 1536UL ||
      request.address == 1792UL ||
      request.address == 2048UL
    ) {
    2
  } else {
    fail("writer-fault replay wrote an unexpected host word")
  }
}

///|
fn generate_writer_fault_run(
  design : @ir.Design,
  hardware : @ir.Module,
  ports : ReadOnlyArray[@verilator.HarnessPort],
) -> FixtureRun raise {
  let trace = fixture_trace(hardware, ports)
  let simulator = trace.simulator
  let host = writer_fault_host()
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
        response_data: 0UL,
      },
    },
    0UL,
  )
  trace.edge(0UL, observe=false)
  let mut offered = 3
  let mut published = 0
  let mut retired = 0
  let mut refills = 0
  let mut cycles = 0
  let mut hold_until = 0
  let mut held : CompletionSnapshot? = None
  let mut held_edges = 0
  let requests : Array[Int] = [0, 0, 0]
  let acknowledgements : Array[Int] = [0, 0, 0]
  let mut rejected_counters : Array[UInt64]? = None
  let mut rejected_descriptor_reads = 0
  let mut rejected_operand_reads = 0
  let mut rejected_c0_writes = 0
  let mut rejected_c1_writes = 0
  let mut recovery_active_edges = 0
  let mut recovery_capture_edges = 0
  for cycle in 1..<=16384 {
    let consumer = output_value(simulator, "consumer_count").to_int()
    let next = if published == offered && retired == offered {
      match offered {
        3 => 6
        6 => 9
        9 => 13
        13 => 16
        16 => 17
        _ => offered
      }
    } else {
      offered
    }
    if next != offered {
      if consumer != published || host.pending is Some(_) {
        fail("writer-fault ring refill preceded the prior group drain")
      }
      for position in offered..<next {
        writer_fault_install(host.memory, position)
      }
      offered = next
      refills += 1
      if next == 13 {
        rejected_counters = Some(writer_fault_counters(simulator))
      }
    }
    if retired == 9 && output_value(simulator, "completion_valid") == 1UL {
      let snapshot = completion_snapshot(simulator)
      match held {
        None => {
          writer_fault_assert_completion(snapshot, 9)
          held = Some(snapshot)
          hold_until = cycle + 32
        }
        Some(previous) =>
          if snapshot != previous {
            fail("rejected writer changed its oldest held terminal payload")
          }
      }
    }
    let holding = retired == 9 && cycle < hold_until
    let row : InputRow = {
      reset: 0UL,
      config_valid: if output_value(simulator, "configured") == 0UL {
        1UL
      } else {
        0UL
      },
      config_base: 3072UL,
      publish_valid: if output_value(simulator, "configured") == 1UL &&
        published != offered {
        1UL
      } else {
        0UL
      },
      publish_producer: offered.to_uint64(),
      completion_ready: if holding {
        0UL
      } else {
        1UL
      },
      bus: host.drive(cycle),
    }
    let cycle_u64 = cycle.to_uint64()
    trace.drive(row, cycle_u64)
    if row.publish_valid == 1UL &&
      output_value(simulator, "publish_ready") == 1UL {
      if offered - published > 4 - (published - consumer) {
        fail("writer-fault publication consumed same-edge ring capacity")
      }
      published = offered
    }
    if holding {
      if output_value(simulator, "completion_valid") != 1UL ||
        held != Some(completion_snapshot(simulator)) {
        fail("held rejected writer lost valid or a pre-edge payload field")
      }
      held_edges += 1
    }
    let completion = if row.completion_ready == 1UL &&
      output_value(simulator, "completion_valid") == 1UL {
      Some(completion_snapshot(simulator))
    } else {
      None
    }
    let counters_before = writer_fault_counters(simulator)
    if offered == 13 && rejected_counters != Some(counters_before) {
      fail("rejected writer group changed retained compute/capture counters")
    }
    let events = host.accept(simulator, row.bus)
    if events.accepted is Some(request) {
      let class = writer_fault_request_class(request)
      requests[class] += 1
      if offered == 13 {
        if class == 0 {
          rejected_descriptor_reads += 1
        } else if class == 1 {
          rejected_operand_reads += 1
          fail("rejected writer or its dependent issued an operand read")
        } else if request.address == 1536UL {
          rejected_c0_writes += 1
          fail("rejected C0 generation fell back to a stale result store")
        } else if request.address == 1792UL {
          rejected_c1_writes += 1
        } else {
          fail("recovery store issued before rejected group retirement")
        }
      }
    }
    if events.acknowledged is Some(request) {
      acknowledgements[writer_fault_request_class(request)] += 1
    }
    trace.edge(cycle_u64, observe=true)
    let counters_after = writer_fault_counters(simulator)
    if offered == 13 && rejected_counters != Some(counters_after) {
      fail("rejected MatMul advanced or reset a compute/capture counter")
    }
    if offered == 16 {
      if counters_after[1] > counters_before[1] {
        if counters_after[1] != counters_before[1] + 1UL {
          fail("recovery active counter did not advance one physical edge")
        }
        recovery_active_edges += 1
      }
      if counters_after[4] > counters_before[4] {
        if counters_after[4] != counters_before[4] + 1UL {
          fail("recovery capture counter did not advance one physical edge")
        }
        recovery_capture_edges += 1
      }
    }
    if holding &&
      (
        output_value(simulator, "completion_valid") != 1UL ||
        held != Some(completion_snapshot(simulator))
      ) {
      fail("held rejected writer changed across a physical edge")
    }
    if completion is Some(actual) {
      writer_fault_assert_completion(actual, retired)
      retired += 1
    }
    for name in ["ring_fault_valid", "transport_halted", "halted"] {
      if output_value(simulator, name) != 0UL {
        fail("writer-fault replay encountered reader or transport poison")
      }
    }
    cycles = cycle
    if retired == 17 && host.pending is None {
      break
    }
  }
  if retired != 17 ||
    published != 17 ||
    refills != 5 ||
    held_edges != 32 ||
    requests != [544, 5, 3] ||
    acknowledgements != requests ||
    host.requests != 552 ||
    host.reads != 549 ||
    host.writes != 12 ||
    host.next_tag != 552UL ||
    host.pending is Some(_) ||
    host.held is Some(_) ||
    host.stalls == 0 ||
    rejected_descriptor_reads != 128 ||
    rejected_operand_reads != 0 ||
    rejected_c0_writes != 0 ||
    rejected_c1_writes != 1 ||
    recovery_active_edges != 1 ||
    recovery_capture_edges != 1 ||
    output_value(simulator, "producer_count") != 17UL ||
    output_value(simulator, "consumer_count") != 17UL ||
    writer_fault_counters(simulator) != [1UL, 1UL, 2UL, 0UL, 1UL] {
    fail(
      "writer-fault bounded replay did not finish exact obligations: cycles=\{cycles}, retired=\{retired}, published=\{published}, refills=\{refills}, hold=\{held_edges}, recovered-active=\{recovery_active_edges}, recovered-capture=\{recovery_capture_edges}",
    )
  }
  verify_writer_fault_memory(host.memory)
  // Read the checked host words, not the independent oracle's expectations.
  let results : Array[Int] = []
  for base in [1536, 1792, 2048] {
    let mut word = 0
    for byte in 0..<4 {
      word = word | (host.memory[base + byte] << (byte * 8))
    }
    results.push(word)
  }
  let summary = StringBuilder()
  summary.write_string(
    "LUNACHIP-PHASE6-FIXTURE 1\nPROFILE flux-tile-0/fetched-concurrent\nDEVICE-ABI 1.0\nDESCRIPTOR 0.2\nCYCLES \{cycles}\nCOMPLETIONS 17\nREQUESTS \{host.requests}\nACKNOWLEDGEMENTS \{acknowledgements[0] + acknowledgements[1] + acknowledgements[2]}\nREAD-BYTES \{host.reads}\nWRITE-REQUESTS \{requests[2]}\nWRITE-BYTES \{host.writes}\nDESCRIPTOR-READS \{requests[0]}\nOPERAND-READS \{requests[1]}\nRESULT-WORDS 3\nRESULT \{results[0]}\nUNRELATED-RESULT \{results[1]}\nRECOVERY-RESULT \{results[2]}\nORACLE match\nHOST-BYTES match\nRING-REFILLS \{refills}\nPRODUCER 17\nCONSUMER 17\nCOMPLETION-HOLD-CYCLES \{held_edges}\n",
  )
  summary.write_string(
    "REJECTED-GROUP-DESCRIPTOR-READS \{rejected_descriptor_reads}\nREJECTED-GROUP-OPERAND-READS \{rejected_operand_reads}\nREJECTED-GROUP-C0-WRITES \{rejected_c0_writes}\nREJECTED-GROUP-C1-WRITES \{rejected_c1_writes}\nREJECTED-COMPUTE-COUNTERS unchanged\nRECOVERY-ACTIVE-EDGES \{recovery_active_edges}\nRECOVERY-CAPTURE-EDGES \{recovery_capture_edges}\nCLAIM generated-reference-only\nEND\n",
  )
  trace.finish(design, cycles, summary.to_string())
}
