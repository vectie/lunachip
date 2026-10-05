///|
fn generate_seeded_run(
  design : @ir.Design,
  hardware : @ir.Module,
  ports : ReadOnlyArray[@verilator.HarnessPort],
) -> FixtureRun raise {
  let trace = fixture_trace(hardware, ports)
  let simulator = trace.simulator
  let policy = seeded_policy()
  let host = seeded_host(policy)
  let measurement = seeded_measurement()
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
  let mut published = 0
  let mut offered = 4
  let mut retired = 0
  let mut cycles = 0
  let mut hold_until = 0
  let mut held : CompletionSnapshot? = None
  let mut held_edges = 0
  let mut held_bus_requests = 0
  let mut held_bus_acks = 0
  let mut compute_completions = 0
  let mut refills = 0
  for cycle in 1..<=32768 {
    let consumer = output_value(simulator, "consumer_count").to_int()
    if offered == 4 && published == 4 && retired == 4 {
      if consumer != 4 {
        fail(
          "first seeded 8x8 Fence did not drain before the second slot workload",
        )
      }
      for position in 4..<8 {
        array8_install(host.memory, position)
      }
      offered = 8
      refills += 1
    }
    if offered == 8 && published == 8 && consumer >= 6 {
      // Slot0/1 are free only after positions4/5 have actually been consumed.
      // Publication uses pre-edge capacity, never same-edge freed credit.
      for position in 8..<10 {
        array8_install(host.memory, position)
      }
      offered = 10
      refills += 1
    }
    if retired == 4 && output_value(simulator, "completion_valid") == 1UL {
      let snapshot = completion_snapshot(simulator)
      match held {
        None => {
          array8_assert_completion(snapshot, 4)
          held = Some(snapshot)
          hold_until = cycle + 64
        }
        Some(previous) =>
          if snapshot != previous {
            fail("seeded 8x8 oldest held LoadA1 changed its completion payload")
          }
      }
    }
    let holding = retired == 4 && cycle < hold_until
    if holding {
      if output_value(simulator, "completion_valid") != 1UL ||
        held != Some(completion_snapshot(simulator)) {
        fail("seeded 8x8 held retirement lost valid or a payload field")
      }
      held_edges += 1
    }
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
        fail(
          "seeded 8x8 publication used a slot that was not free before its edge",
        )
      }
      published = offered
    }
    let completion = if row.completion_ready == 1UL &&
      output_value(simulator, "completion_valid") == 1UL {
      Some(completion_snapshot(simulator))
    } else {
      None
    }
    let events = host.accept(simulator, row.bus)
    measurement.observe(events, host, policy, row.bus, cycle)
    if holding {
      if events.accepted is Some(request) && request.write == 0UL {
        let class = array8_read_class(request.address.to_int())
        if class == 0 || class == 4 {
          held_bus_requests += 1
        }
      }
      if events.acknowledged is Some(request) && request.write == 0UL {
        let class = array8_read_class(request.address.to_int())
        if class == 0 || class == 4 {
          held_bus_acks += 1
        }
      }
    }
    trace.edge(cycle_u64, observe=true)
    if holding &&
      (
        output_value(simulator, "completion_valid") != 1UL ||
        held != Some(completion_snapshot(simulator))
      ) {
      fail("seeded 8x8 held completion changed across a bus-progress edge")
    }
    if completion is Some(actual) {
      array8_assert_completion(actual, retired)
      if retired == 2 || retired == 6 {
        array8_assert_compute(simulator)
        compute_completions += 1
      }
      retired += 1
    }
    if output_value(simulator, "ring_fault_valid") != 0UL ||
      output_value(simulator, "transport_halted") != 0UL ||
      output_value(simulator, "halted") != 0UL {
      fail(
        "seeded 8x8 successful replay encountered a reader or transport fault",
      )
    }
    cycles = cycle
    if retired == 10 && host.pending is None {
      break
    }
  }
  if retired != 10 ||
    published != 10 ||
    refills != 2 ||
    held_edges != 64 ||
    held_bus_requests == 0 ||
    held_bus_acks == 0 ||
    compute_completions != 2 ||
    output_value(simulator, "producer_count") != 10UL ||
    output_value(simulator, "consumer_count") != 10UL {
    fail(
      "seeded 8x8 bounded workload missing retirement/progress: retired=\{retired}, P=\{published}, refills=\{refills}, held=\{held_edges}, held-requests=\{held_bus_requests}, held-ACKs=\{held_bus_acks}, MatMul=\{compute_completions}",
    )
  }
  measurement.finish(host, cycles)
  array8_assert_compute(simulator)
  let (result0, result1) = verify_seeded_memory(host.memory)
  let summary = StringBuilder()
  summary.write_string(
    "LUNACHIP-PHASE6-FIXTURE 1\nPROFILE flux-tile-0/fetched-concurrent\nDEVICE-ABI 1.0\nDESCRIPTOR 0.2\nCYCLES \{cycles}\nCOMPLETIONS 10\nREQUESTS 960\nACKNOWLEDGEMENTS 960\nREAD-BYTES 832\nWRITE-REQUESTS 128\nWRITE-BYTES 512\nDESCRIPTOR-READS 320\nOPERAND-READS 512\nRESULT-WORDS 128\nORACLE match\nHOST-BYTES match\nRING-REFILLS \{refills}\nPRODUCER 10\nCONSUMER 10\nCOMPLETION-HOLD-CYCLES \{held_edges}\nHELD-BUS-REQUESTS \{held_bus_requests}\nHELD-BUS-ACKS \{held_bus_acks}\nCOMPUTE-COMPLETIONS \{compute_completions}\nPER-MATMUL-ACCEPTED-STEPS 30\nPER-MATMUL-ACTIVE-CYCLES 30\nPER-MATMUL-ELAPSED-CYCLES 31\nPER-MATMUL-STALL-CYCLES 0\nPER-MATMUL-CAPTURE-CYCLES 64\n",
  )
  summary.write_string(
    "PRNG SplitMix64\nMASTER-SEED 5eedc0de20261005\nMATRIX-SEED \{@verilator.padded_hex(seeded_master() ^ 0x4d4154524958UL, 64)}\nREADINESS-SEED \{@verilator.padded_hex(seeded_master() ^ 0x5245414459UL, 64)}\nLATENCY-SEED \{@verilator.padded_hex(seeded_master() ^ 0x4c4154454e4359UL, 64)}\nMATRIX-PRNG-DRAWS 516\nRETAINED-RANDOM-INT8 492\nEXPLICIT-INT8-EDGE-VALUES 20\nREADINESS-PRNG-DRAWS 32769\nLATENCY-PRNG-DRAWS 960\nREQUEST-READY-0-CYCLES \{measurement.readiness[0]}\nREQUEST-READY-1-CYCLES \{measurement.readiness[1]}\nVALID-REQUEST-STALL-CYCLES \{host.stalls}\n",
  )
  for index, count in measurement.delays {
    summary.write_string("RESPONSE-DELAY-\{index + 1}-REQUESTS \{count}\n")
  }
  for (slot, values) in [(0, result0), (1, result1)] {
    for row in 0..<8 {
      let cells = StringBuilder()
      for column in 0..<8 {
        if column > 0 {
          cells.write_char(',')
        }
        cells.write_string(values[row * 8 + column].to_string())
      }
      summary.write_string(
        "RESULT-SLOT-\{slot}-ROW-\{row} \{cells.to_string()}\n",
      )
    }
  }
  summary.write_string("CLAIM generated-reference-only\nEND\n")
  trace.finish(design, cycles, summary.to_string())
}
