///|
// Read actual settled public pins before Host::accept applies any write effect.
fn descriptor_rejection_offered_request(
  simulator : @sim.Simulator,
  drive : HostDrive,
) -> Request? raise {
  if drive.request_ready != 1UL ||
    output_value(simulator, "memory_request_valid") != 1UL {
    return None
  }
  Some({
    write: output_value(simulator, "memory_request_write"),
    address: output_value(simulator, "memory_request_address"),
    bytes: output_value(simulator, "memory_request_bytes"),
    mask: output_value(simulator, "memory_request_mask"),
    data: output_value(simulator, "memory_request_data"),
    tag: output_value(simulator, "memory_request_tag"),
  })
}

///|
fn descriptor_rejection_assert_unpoisoned(
  simulator : @sim.Simulator,
) -> Unit raise {
  for name in ["ring_fault_valid", "transport_halted", "halted"] {
    if output_value(simulator, name) != 0UL {
      fail(
        "descriptor rejection replay encountered a reader or transport fault",
      )
    }
  }
}

///|
fn descriptor_rejection_trace(
  design : @ir.Design,
  hardware : @ir.Module,
  ports : ReadOnlyArray[@verilator.HarnessPort],
) -> FixtureRun raise {
  let host : Host = {
    kind: WriterFault,
    memory: descriptor_rejection_memory(),
    pending: None,
    held: None,
    next_tag: 0UL,
    requests: 0,
    reads: 0,
    writes: 0,
    stalls: 0,
  }
  // Reuse the shared initial reset and all-public-output trace implementation.
  let context = fault_context(hardware, ports, host~, cycle_limit=65536)
  let trace = context.trace
  let simulator = trace.simulator
  let audit = descriptor_rejection_audit()
  let groups = descriptor_rejection_groups()
  if groups.length() != 31 || groups[0] != (0, 3) || groups[30] != (85, 86) {
    fail("descriptor rejection group profile drifted")
  }
  let mut group = 0
  let mut offered = 3
  let mut published = 0
  let mut retired = 0
  let mut window = -1
  let mut rejected_counters : Array[UInt64]? = None
  let mut held : CompletionSnapshot? = None
  let mut cycles = 0
  let mut quiet_edges = 0
  for cycle in 1..<=65536 {
    let consumer = output_value(simulator, "consumer_count").to_int()
    if retired == offered && published == offered && group + 1 < groups.length() {
      let (first, end) = groups[group + 1]
      if first != offered ||
        end <= first ||
        end - first > 4 ||
        consumer != first ||
        output_value(simulator, "producer_count") != first.to_uint64() ||
        host.pending is Some(_) ||
        host.held is Some(_) {
        fail(
          "descriptor rejection refill lacked drained pre-edge consumer credit",
        )
      }
      for position in first..<end {
        descriptor_rejection_install(host.memory, position)
      }
      offered = end
      group += 1
      audit.refills += 1
      let next_window = descriptor_rejection_window(first)
      if next_window != window {
        window = next_window
        rejected_counters = if window >= 0 {
          Some(writer_fault_counters(simulator))
        } else {
          None
        }
      }
    }
    if retired == 32 && output_value(simulator, "completion_valid") == 1UL {
      let snapshot = completion_snapshot(simulator)
      match held {
        None => {
          descriptor_rejection_assert_completion(snapshot, 32)
          held = Some(snapshot)
          audit.hold_cycle = cycle
        }
        Some(previous) =>
          if snapshot != previous {
            fail("position32 held rejection changed terminal payload")
          }
      }
    }
    let holding = retired == 32 && held is Some(_) && audit.held_edges < 32
    let configured = output_value(simulator, "configured") == 1UL
    let row : InputRow = {
      reset: 0UL,
      config_valid: if configured {
        0UL
      } else {
        1UL
      },
      config_base: 3072UL,
      publish_valid: if configured && published != offered {
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
    trace.drive(row, cycle.to_uint64())
    descriptor_rejection_assert_unpoisoned(simulator)
    if row.config_valid == 1UL && output_value(simulator, "config_ready") == 1UL {
      audit.configurations += 1
    }
    if row.publish_valid == 1UL &&
      output_value(simulator, "publish_ready") == 1UL {
      if offered - published > 4 - (published - consumer) {
        fail("descriptor rejection publication used same-edge freed capacity")
      }
      published = offered
      audit.publications += 1
    }
    let counters_before = writer_fault_counters(simulator)
    if window >= 0 {
      if rejected_counters != Some(counters_before) {
        fail("rejection window changed a retained compute tuple before an edge")
      }
      audit.rejected_edges[window] += 1
    }
    if holding {
      if output_value(simulator, "completion_valid") != 1UL ||
        held != Some(completion_snapshot(simulator)) {
        fail("position32 held rejection lost pre-edge valid or payload")
      }
      audit.held_edges += 1
    }
    let completion = if row.completion_ready == 1UL &&
      output_value(simulator, "completion_valid") == 1UL {
      Some(completion_snapshot(simulator))
    } else {
      None
    }
    if completion is Some(actual) {
      // The terminal is already visible in this PRE state. Its Store ACK must
      // have happened earlier, not merely coincide with this retirement edge.
      audit.record_completion(actual, retired, counters_before)
    }
    let quiet = retired == 86
    if quiet &&
      (
        completion is Some(_) ||
        output_value(simulator, "completion_valid") != 0UL ||
        output_value(simulator, "memory_request_valid") != 0UL ||
        host.pending is Some(_) ||
        host.held is Some(_)
      ) {
      fail("descriptor rejection replay was not quiet after final retirement")
    }
    if host.pending is Some(response) && response.delay > 0 {
      audit.response_delay_edges += 1
    }
    if row.bus.response_valid == 1UL &&
      output_value(simulator, "memory_response_ready") == 0UL {
      audit.response_hold_edges += 1
    }
    let offered_request = descriptor_rejection_offered_request(
      simulator,
      row.bus,
    )
    if offered_request is Some(request) {
      if window >= 0 && writer_fault_request_class(request) != 0 {
        fail("rejection window attempted data DMA before host memory effects")
      }
      if request.write == 1UL {
        descriptor_rejection_assert_write(request, audit.requests[2])
      }
    }
    let events = host.accept(simulator, row.bus)
    if events.accepted != offered_request {
      fail(
        "descriptor rejection request observation differed from actual host acceptance",
      )
    }
    if events.accepted is Some(request) {
      audit.record_request(request, acknowledged=false, window~)
    }
    if events.acknowledged is Some(request) {
      if row.bus.response_fault != 0UL || row.bus.response_tag != request.tag {
        fail(
          "descriptor rejection ACK did not match its saved successful request",
        )
      }
      if request.write == 1UL {
        descriptor_rejection_assert_write(request, audit.acknowledgements[2])
      }
      audit.record_request(request, acknowledged=true, window~)
    }
    trace.edge(cycle.to_uint64(), observe=true)
    let counters_after = writer_fault_counters(simulator)
    if window >= 0 && rejected_counters != Some(counters_after) {
      fail("rejection window advanced or reset a compute/capture counter")
    }
    audit.record_compute_edge(counters_before, counters_after, cycle)
    if holding &&
      (
        output_value(simulator, "completion_valid") != 1UL ||
        held != Some(completion_snapshot(simulator))
      ) {
      fail("position32 held rejection changed across a physical edge")
    }
    if completion is Some(_) {
      retired += 1
    }
    descriptor_rejection_assert_unpoisoned(simulator)
    cycles = cycle
    if quiet {
      if output_value(simulator, "completion_valid") != 0UL ||
        output_value(simulator, "memory_request_valid") != 0UL ||
        host.pending is Some(_) ||
        host.held is Some(_) {
        fail("descriptor rejection quiet edge produced an extra obligation")
      }
      quiet_edges += 1
      if quiet_edges == 8 {
        break
      }
    }
  }
  if retired != 86 ||
    published != 86 ||
    quiet_edges != 8 ||
    group != 30 ||
    output_value(simulator, "producer_count") != 86UL ||
    output_value(simulator, "consumer_count") != 86UL ||
    writer_fault_counters(simulator) != [1UL, 1UL, 2UL, 0UL, 1UL] {
    fail(
      "descriptor rejection bounded replay did not drain all86 packets: cycle=\{cycles}, retired=\{retired}, published=\{published}, group=\{group}, quiet=\{quiet_edges}",
    )
  }
  audit.check_final(host)
  verify_descriptor_rejection_memory(host.memory)
  trace.finish(
    design,
    cycles,
    descriptor_rejection_summary(audit, host, cycles),
  )
}
