///|
fn generate_shape_reload_run(
  design : @ir.Design,
  hardware : @ir.Module,
  ports : ReadOnlyArray[@verilator.HarnessPort],
) -> FixtureRun raise {
  let trace = fixture_trace(hardware, ports)
  let simulator = trace.simulator
  let host : Host = {
    kind: ShapeReload,
    memory: shape_reload_memory(),
    pending: None,
    held: None,
    next_tag: 0UL,
    requests: 0,
    reads: 0,
    writes: 0,
    stalls: 0,
  }
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
  let reads = Array::make(5, 0)
  let writes = Array::make(2, 0)
  let write_acks = Array::make(2, 0)
  let delays = Array::make(5, 0)
  let mut acknowledgements = 0
  let mut published = 0
  let mut offered = 4
  let mut retired = 0
  let mut cycles = 0
  let mut refills = 0
  let mut hold_until = 0
  let mut held : CompletionSnapshot? = None
  let mut held_edges = 0
  let mut computes = 0
  for cycle in 1..<=16384 {
    let consumer = output_value(simulator, "consumer_count").to_int()
    if offered == 4 && published == 4 && retired == 4 {
      if consumer != 4 {
        fail("shape-reload first Fence did not drain before source reload")
      }
      for position in 4..<8 {
        shape_reload_install(host.memory, position)
      }
      offered = 8
      refills += 1
    }
    if offered == 8 && published == 8 && consumer >= 6 {
      for position in 8..<10 {
        shape_reload_install(host.memory, position)
      }
      offered = 10
      refills += 1
    }
    if retired == 0 &&
      output_value(simulator, "completion_valid") == 1UL &&
      held is None {
      let snapshot = completion_snapshot(simulator)
      shape_reload_assert_completion(snapshot, 0)
      held = Some(snapshot)
      hold_until = cycle + 16
    }
    let holding = retired == 0 && cycle < hold_until
    if holding {
      if output_value(simulator, "completion_valid") != 1UL ||
        held != Some(completion_snapshot(simulator)) {
        fail("shape-reload held completion changed at PRE")
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
        fail("shape-reload publication used unavailable pre-edge capacity")
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
    if events.accepted is Some(request) {
      if request.write == 0UL {
        reads[shape_reload_read_class(request.address.to_int())] += 1
      } else {
        writes[shape_reload_write_class(request.address.to_int())] += 1
      }
      let delay = (request.tag % 5UL).to_int()
      delays[delay] += 1
      match host.pending {
        Some(response) =>
          if response.request != request || response.delay != delay + 1 {
            fail(
              "shape-reload host did not install the recorded response delay",
            )
          }
        None => fail("shape-reload accepted request has no owned response")
      }
    }
    if events.acknowledged is Some(request) {
      acknowledgements += 1
      if request.write == 1UL {
        write_acks[shape_reload_write_class(request.address.to_int())] += 1
      }
    }
    trace.edge(cycle_u64, observe=true)
    if holding &&
      (
        output_value(simulator, "completion_valid") != 1UL ||
        held != Some(completion_snapshot(simulator))
      ) {
      fail("shape-reload held completion changed across an edge")
    }
    if completion is Some(actual) {
      shape_reload_assert_completion(actual, retired)
      if retired == 2 || retired == 6 {
        shape_reload_assert_compute(simulator, retired == 6)
        computes += 1
      }
      retired += 1
    }
    if output_value(simulator, "ring_fault_valid") != 0UL ||
      output_value(simulator, "transport_halted") != 0UL ||
      output_value(simulator, "halted") != 0UL {
      fail(
        "shape-reload successful replay encountered a reader or transport fault",
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
    held_edges != 16 ||
    computes != 2 ||
    output_value(simulator, "producer_count") != 10UL ||
    output_value(simulator, "consumer_count") != 10UL ||
    reads != [320, 51, 85, 8, 8] ||
    writes != [15, 64] ||
    write_acks != [15, 64] ||
    acknowledgements != 551 ||
    host.requests != 551 ||
    host.next_tag != 551UL ||
    host.reads != 472 ||
    host.writes != 316 ||
    host.stalls == 0 ||
    host.pending is Some(_) ||
    host.held is Some(_) {
    fail(
      "shape-reload bounded workload did not complete exact commands, transfers and hold",
    )
  }
  shape_reload_assert_compute(simulator, true)
  let results = shape_reload_verify(host.memory)
  let summary = StringBuilder()
  summary.write_string(
    "LUNACHIP-PHASE6-FIXTURE 1\nPROFILE flux-tile-0/fetched-concurrent\nDEVICE-ABI 1.0\nDESCRIPTOR 0.2\nARRAY 8 8\nREDUCTION-CAPACITY 17\nCYCLES \{cycles}\nCOMPLETIONS 10\nREQUESTS 551\nACKNOWLEDGEMENTS 551\nREAD-BYTES 472\nWRITE-REQUESTS 79\nWRITE-BYTES 316\nDESCRIPTOR-READS 320\nOPERAND-READS 152\nRESULT-WORDS 79\nORACLE match\nHOST-BYTES match\nHOST-BYTE-COUNT 4096\nRING-REFILLS \{refills}\nPRODUCER 10\nCONSUMER 10\nCOMPLETION-HOLD-CYCLES \{held_edges}\nCOMPUTE-COMPLETIONS \{computes}\nSOURCE-SLOTS A1 B0\nEXACT-SHAPE-RELOADS 2\nMATMUL-0-SHAPE 3 5 17\nMATMUL-0-ACCEPTED-STEPS 23\nMATMUL-0-ELAPSED-CYCLES 24\nMATMUL-0-CAPTURE-CYCLES 15\nMATMUL-1-SHAPE 8 8 1\nMATMUL-1-ACCEPTED-STEPS 15\nMATMUL-1-ELAPSED-CYCLES 16\nMATMUL-1-CAPTURE-CYCLES 64\n",
  )
  for index, count in delays {
    if count == 0 {
      fail("shape-reload did not exercise all response-delay classes")
    }
    summary.write_string("RESPONSE-DELAY-\{index + 1}-REQUESTS \{count}\n")
  }
  for slot, values in results {
    let rows = if slot == 0 { 3 } else { 8 }
    let columns = if slot == 0 { 5 } else { 8 }
    for row in 0..<rows {
      let cells = values[row * columns:(row + 1) * columns]
        .map(value => value.to_string())
        .join(",")
      summary.write_string("RESULT-SLOT-\{slot}-ROW-\{row} \{cells}\n")
    }
  }
  summary.write_string("CLAIM generated-reference-only\nEND\n")
  trace.finish(design, cycles, summary.to_string())
}
