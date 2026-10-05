///|
fn generate_run(
  design : @ir.Design,
  hardware : @ir.Module,
  ports : ReadOnlyArray[@verilator.HarnessPort],
) -> FixtureRun raise {
  let trace = fixture_trace(hardware, ports)
  let simulator = trace.simulator
  let host = host()
  let reset_row : InputRow = {
    reset: 1UL,
    config_valid: 0UL,
    config_base: 512UL,
    publish_valid: 0UL,
    publish_producer: 0UL,
    completion_ready: 0UL,
    bus: {
      request_ready: 0UL,
      response_valid: 0UL,
      response_tag: 0UL,
      response_data: 0UL,
    },
  }
  trace.drive(reset_row, 0UL)
  trace.edge(0UL, observe=false)
  let mut configured = false
  let mut first_published = false
  let mut final_published = false
  let mut fence_installed = false
  let mut hold_until = 0
  let mut held_once = false
  let mut retired = 0
  let mut cycles = 0
  for cycle in 1..<=4096 {
    if !fence_installed && output_value(simulator, "consumer_count") >= 1UL {
      install_packet(host.memory, 0, fence_packet())
      fence_installed = true
    }
    if !held_once && output_value(simulator, "completion_valid") == 1UL {
      hold_until = cycle + 9
      held_once = true
    }
    let publish = output_value(simulator, "configured") == 1UL &&
      (!first_published || (fence_installed && !final_published))
    let row : InputRow = {
      reset: 0UL,
      config_base: 512UL,
      config_valid: if configured {
        0UL
      } else {
        1UL
      },
      publish_valid: if publish {
        1UL
      } else {
        0UL
      },
      publish_producer: if first_published {
        5UL
      } else {
        4UL
      },
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
      if first_published {
        final_published = true
      } else {
        first_published = true
      }
    }
    if row.completion_ready == 1UL &&
      output_value(simulator, "completion_valid") == 1UL {
      let progress = [2UL, 2UL, 0UL, 4UL, 0UL]
      if retired >= 5 ||
        output_value(simulator, "completion_id") != (41 + retired).to_uint64() ||
        output_value(simulator, "completion_fault") != 0UL ||
        output_value(simulator, "completion_bytes_completed") !=
        progress[retired] ||
        output_value(simulator, "completion_fault_address") != 0UL {
        fail("unexpected ordered completion \{retired}")
      }
      retired += 1
    }
    ignore(host.accept(simulator, row.bus))
    trace.edge(cycle_u64, observe=true)
    cycles = cycle
    if output_value(simulator, "ring_fault_valid") != 0UL ||
      output_value(simulator, "transport_halted") != 0UL {
      fail("successful fixture encountered a device fault")
    }
    if retired == 5 && host.pending is None {
      break
    }
  }
  if retired != 5 ||
    !final_published ||
    !held_once ||
    host.stalls == 0 ||
    host.requests != 165 ||
    host.reads != 164 ||
    host.writes != 4 ||
    output_value(simulator, "producer_count") != 5UL ||
    output_value(simulator, "consumer_count") != 5UL ||
    output_value(simulator, "accepted_steps") != 2UL ||
    output_value(simulator, "elapsed_cycles") != 3UL ||
    output_value(simulator, "active_cycles") != 2UL ||
    output_value(simulator, "stall_cycles") != 0UL ||
    output_value(simulator, "capture_cycles") != 1UL {
    fail("fixture did not complete its bounded workload and counters")
  }
  let oracle = verify_workload(host.memory)
  trace.finish(
    design,
    cycles,
    "LUNACHIP-PHASE6-FIXTURE 1\nPROFILE flux-tile-0/fetched-concurrent\nDEVICE-ABI 1.0\nDESCRIPTOR 0.2\nCYCLES \{cycles}\nCOMPLETIONS 5\nREQUESTS 165\nREAD-BYTES 164\nWRITE-BYTES 4\nRESULT \{oracle}\nORACLE match\nRING-SLOT-REUSE true\nCOMPLETION-HOLD-CYCLES 9\nCLAIM generated-reference-only\nEND\n",
  )
}
