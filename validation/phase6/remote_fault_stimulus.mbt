///|
fn generate_remote_fault_run(
  design : @ir.Design,
  hardware : @ir.Module,
  ports : ReadOnlyArray[@verilator.HarnessPort],
) -> FixtureRun raise {
  let context = fault_context(
    hardware,
    ports,
    host=remote_fault_host(),
    cycle_limit=16384,
  )
  let host = context.host
  let simulator = context.trace.simulator
  let state = match host.kind {
    RemoteFault(state) => state
    _ => fail("remote-fault replay requires its fixed host environment")
  }
  let measurement = remote_fault_measurement()
  let mut offered = 3
  let mut published = 0
  let mut retired = 0
  for _ in 0..<16384 {
    let next = if published == offered && retired == offered {
      match offered {
        3 => 6
        6 => 9
        9 => 12
        12 => 15
        15 => 16
        _ => offered
      }
    } else {
      offered
    }
    if next != offered {
      if output_value(simulator, "consumer_count") != published.to_uint64() ||
        host.pending is Some(_) ||
        host.held is Some(_) {
        fail(
          "remote-fault refill preceded prior ordered retirement/consumer credit",
        )
      }
      if offered == 6 {
        if measurement.failed_acks != 1 ||
          state.write_effect_bytes != 6 ||
          measurement.store_ack_bytes != 4 ||
          measurement.requests != [192, 8, 2] {
          fail(
            "remote-fault partial checkpoint preceded its actual failing store ACK",
          )
        }
        remote_fault_verify_partial(host.memory)
        measurement.partial_checked = true
      }
      for position in offered..<next {
        remote_fault_install(host.memory, position)
      }
      offered = next
      measurement.refills += 1
      if offered == 12 {
        measurement.rejected_counters = Some(remote_fault_counters(simulator))
      }
    }
    let before = remote_fault_counters(simulator)
    if offered == 12 && measurement.rejected_counters != Some(before) {
      fail(
        "failed generations changed retained compute counters before an edge",
      )
    }
    remote_fault_assert_unpoisoned(simulator)
    let bus = host.drive(context.cycle + 1)
    let configured = output_value(simulator, "configured") == 1UL
    let events = context.tick(
      bus,
      config_valid=if configured { 0UL } else { 1UL },
      publish_valid=if configured && published != offered { 1UL } else { 0UL },
      publish_producer=offered.to_uint64(),
    )
    if events.publication_accepted {
      if offered - published > 4 - (published - retired) {
        fail("remote-fault publication used unavailable pre-edge ring capacity")
      }
      published = offered
    }
    measurement.record(state, events, bus, offered)
    let after = remote_fault_counters(simulator)
    if offered == 12 && measurement.rejected_counters != Some(after) {
      fail(
        "failed generations advanced or reset compute counters across an edge",
      )
    }
    if offered == 15 {
      if after[1] > before[1] {
        if after[1] != before[1] + 1UL {
          fail("recovery skipped an actual active edge")
        }
        measurement.recovery_active_edges += 1
      }
      if after[4] > before[4] {
        if after[4] != before[4] + 1UL {
          fail("recovery skipped an actual capture edge")
        }
        measurement.recovery_capture_edges += 1
      }
    }
    if events.completion is Some(actual) {
      remote_fault_assert_completion(actual, retired)
      retired += 1
    }
    remote_fault_assert_unpoisoned(simulator)
    if retired == 16 && host.pending is None {
      break
    }
  }
  measurement.check_final(context, state, published, retired)
  remote_fault_verify_final(host.memory)
  let words = remote_fault_result_words(host.memory)
  let summary = remote_fault_summary(context, state, measurement, words)
  context.trace.finish(design, context.cycle, summary)
}

///|
fn remote_fault_summary(
  context : FaultContext,
  state : RemoteFaultHostState,
  measurement : RemoteFaultMeasurement,
  words : Array[Int],
) -> String raise {
  let store = match state.store_failure {
    Some(request) => request
    None => fail("remote-fault summary has no observed store owner")
  }
  let load = match state.load_failure {
    Some(request) => request
    None => fail("remote-fault summary has no observed load owner")
  }
  let host = context.host
  let summary = StringBuilder()
  summary.write_string(
    "LUNACHIP-PHASE6-FIXTURE 1\nPROFILE flux-tile-0/fetched-concurrent\nDEVICE-ABI 1.0\nDESCRIPTOR 0.2\nCYCLES \{context.cycle}\nCOMPLETIONS 16\nREQUESTS \{host.requests}\nACKNOWLEDGEMENTS \{measurement.acknowledgements[0] + measurement.acknowledgements[1] + measurement.acknowledgements[2]}\nDESCRIPTOR-READS \{measurement.requests[0]}\nOPERAND-READS \{measurement.requests[1]}\nREAD-BYTES \{host.reads}\nWRITE-REQUESTS \{measurement.requests[2]}\nWRITE-REQUEST-BYTES \{host.writes}\nWRITE-EFFECT-BYTES \{state.write_effect_bytes}\nWRITE-ACK-BYTES \{measurement.store_ack_bytes}\nREMOTE-FAILURE-ACKS \{measurement.failed_acks}\n",
  )
  summary.write_string(
    "STORE-FAILURE-TAG \{store.tag}\nSTORE-FAULT-ADDRESS \{store.address}\nSTORE-COMPLETED-BYTES 4\nLOAD-FAILURE-TAG \{load.tag}\nLOAD-FAULT-ADDRESS \{load.address}\nLOAD-COMPLETED-BYTES 2\nPARTIAL-WRITE-HOST-BYTES 4096 match\nRETRY-SAME-C0 true\nFAILED-MATMUL-FAULT 4\nFAILED-STORE-FAULT 5\nORACLE match\nHOST-BYTES 4096 match\nRESULT \{words[0]},\{words[1]}\nUNRELATED-RESULT \{words[2]},\{words[3]}\nRECOVERY-RESULT \{words[4]},\{words[5]}\n",
  )
  summary.write_string(
    "REJECTED-GROUP-DESCRIPTOR-READS \{measurement.rejected_reads}\nREJECTED-GROUP-OPERAND-READS \{measurement.rejected_operands}\nREJECTED-GROUP-C0-WRITES \{measurement.rejected_c0_writes}\nREJECTED-GROUP-C1-WRITES \{measurement.rejected_c1_writes}\nREJECTED-COMPUTE-COUNTERS unchanged\nRECOVERY-ACTIVE-EDGES \{measurement.recovery_active_edges}\nRECOVERY-CAPTURE-EDGES \{measurement.recovery_capture_edges}\nRING-REFILLS \{measurement.refills}\nPRODUCER 16\nCONSUMER 16\nINITIAL-RESET 1\nJOINT-RESETS 0\nHOST-REINITIALIZATIONS 0\nTRANSPORT-POISON false\nCLAIM generated-reference-only\nEND\n",
  )
  summary.to_string()
}
