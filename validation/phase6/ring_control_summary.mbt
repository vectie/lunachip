///|
fn ring_control_fault_snapshot(context : FaultContext) -> Array[UInt64] raise {
  [
    for
      name in [
        "ring_fault_code", "ring_fault_address", "configured", "producer_count",
        "consumer_count",
      ] => output_value(context.trace.simulator, name)
  ]
}

///|
fn ring_control_word(memory : Array[Int], address : Int) -> Int {
  let mut word = 0
  for byte in 0..<4 {
    word = word | (memory[address + byte] << (byte * 8))
  }
  word
}

///|
fn ring_control_summary(
  context : FaultContext,
  counts : RingControlCounts,
  progress : RingControlProgress,
) -> String raise {
  let summary = StringBuilder()
  summary.write_string(
    "LUNACHIP-PHASE6-FIXTURE 1\nPROFILE flux-tile-0/fetched-concurrent\n",
  )
  summary.write_string(
    "FIXTURE fetched-concurrent-1x1-k512-ring-control-recovery\n",
  )
  summary.write_string("DEVICE-ABI 1.0\nDESCRIPTOR 0.2\n")
  summary.write_string(
    "CYCLES \{context.cycle}\nCYCLE-BOUND \{context.cycle_limit}\nEPOCHS 7\n",
  )
  let totals = [0, 0, 0]
  let ack_totals = [0, 0, 0]
  let mut completions = 0
  let mut configurations = 0
  let mut publications = 0
  for index in 0..<7 {
    let requests = counts.requests[index]
    let acks = counts.acks[index]
    for class in 0..<3 {
      totals[class] += requests[class]
      ack_totals[class] += acks[class]
    }
    completions += counts.retired[index]
    configurations += counts.configurations[index]
    publications += counts.publications[index]
    summary.write_string(
      "EPOCH \{index + 1} CONFIGURATIONS \{counts.configurations[index]} PUBLICATIONS \{counts.publications[index]} COMPLETIONS \{counts.retired[index]} DESCRIPTOR-READS \{requests[0]} OPERAND-READS \{requests[1]} WORD-WRITES \{requests[2]} DESCRIPTOR-ACKS \{acks[0]} OPERAND-ACKS \{acks[1]} WORD-ACKS \{acks[2]} RUN-EDGES \{progress.active_edges[index]} CAPTURE-EDGES \{progress.capture_edges[index]} QUIET-EDGES \{progress.quiet_edges[index]}\n",
    )
    if index < 6 {
      let fault = progress.fault_snapshots[index]
      summary.write_string(
        "RING-FAULT-EPOCH \{index + 1} CODE \{fault[0]} ADDRESS \{fault[1]} CONFIGURED \{fault[2]} PRODUCER \{fault[3]} CONSUMER \{fault[4]}\n",
      )
    }
  }
  summary.write_string(
    "CONFIGURATION-ACCEPTS \{configurations}\nPUBLICATION-ACCEPTS \{publications}\nNOOP-PUBLICATIONS \{counts.noop_publications}\n",
  )
  summary.write_string(
    "COMPLETIONS \{completions}\nREQUESTS \{context.host.requests}\nACKNOWLEDGEMENTS \{ack_totals[0] + ack_totals[1] + ack_totals[2]}\n",
  )
  summary.write_string(
    "DESCRIPTOR-READS \{totals[0]}\nOPERAND-READS \{totals[1]}\nWORD-WRITES \{totals[2]}\nDESCRIPTOR-ACKS \{ack_totals[0]}\nOPERAND-ACKS \{ack_totals[1]}\nWORD-ACKS \{ack_totals[2]}\n",
  )
  summary.write_string(
    "READ-BYTES \{context.host.reads}\nWRITE-BYTES \{context.host.writes}\n",
  )
  summary.write_string(
    "STORE-PACKET-FINAL-ACK-CYCLE \{progress.final_ack_cycle}\nPUBLICATION-FAULT-CYCLE \{progress.fault_cycle}\n",
  )
  summary.write_string(
    "PUBLICATION-FAULT-ACTIVE-BEFORE \{progress.fault_active_before}\nPUBLICATION-FAULT-ACTIVE-AFTER \{progress.fault_active_before + 1UL}\n",
  )
  summary.write_string(
    "BAD-PUBLICATION-CANDIDATE 8\nFAULT-PRODUCER 6\nPACKET-ADMISSION-CONSUMER 3 4\n",
  )
  summary.write_string(
    "COMPLETION-HOLD-DISCOVERY-CYCLE \{progress.hold_cycle}\nCOMPLETION-HOLD-CYCLES \{counts.held_edges}\n",
  )
  summary.write_string("LONG-COUNTERS 512 512 513 0 1\nRECOVERY-COUNTERS")
  for value in ring_control_core(context) {
    summary.write_string(" \{value}")
  }
  summary.write_string(
    "\nFINAL-PRODUCER \{output_value(context.trace.simulator, "producer_count")}\nFINAL-CONSUMER \{output_value(context.trace.simulator, "consumer_count")}\n",
  )
  summary.write_string(
    "REQUEST-READY-STALL-EDGES \{context.host.stalls}\nFINAL-TAG \{context.host.next_tag}\nSTARTUP-RESETS 1\nJOINT-RESETS \{progress.resets}\n",
  )
  summary.write_string(
    "LONG-RESULT \{ring_control_word(context.host.memory, 2816)}\nRECOVERY-RESULT \{ring_control_word(context.host.memory, 2800)}\n",
  )
  summary.write_string(
    "HOST-BYTES 4096 match\nORACLE per-write-and-saved-ACK\nRESET-HOST-BYTES preserved\nTRANSPORT-POISON false\n",
  )
  summary.write_string(
    "SCOPE finite-runtime-ring-control-and-recovery-only\nCLAIM generated-reference-only\nEND\n",
  )
  summary.to_string()
}
