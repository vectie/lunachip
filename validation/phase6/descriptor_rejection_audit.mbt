///|
priv struct DescriptorRejectionAudit {
  requests : Array[Int32]
  acknowledgements : Array[Int32]
  operand_requests : Array[Int32]
  operand_acknowledgements : Array[Int32]
  store_requests : Array[Int32]
  store_acknowledgements : Array[Int32]
  faults : Array[Int32]
  rejected_reads : Array[Int32]
  rejected_acknowledgements : Array[Int32]
  rejected_edges : Array[Int32]
  run_cycles : Array[Int32]
  capture_cycles : Array[Int32]
  mut mat_completions : Int32
  mut progress : Int32
  mut configurations : Int32
  mut publications : Int32
  mut refills : Int32
  mut held_edges : Int32
  mut hold_cycle : Int32
  mut response_delay_edges : Int32
  mut response_hold_edges : Int32
}

///|
fn descriptor_rejection_audit() -> DescriptorRejectionAudit {
  {
    requests: [0, 0, 0],
    acknowledgements: [0, 0, 0],
    operand_requests: Array::make(5, 0),
    operand_acknowledgements: Array::make(5, 0),
    store_requests: Array::make(3, 0),
    store_acknowledgements: Array::make(3, 0),
    faults: Array::make(16, 0),
    rejected_reads: Array::make(7, 0),
    rejected_acknowledgements: Array::make(7, 0),
    rejected_edges: Array::make(7, 0),
    run_cycles: [],
    capture_cycles: [],
    mat_completions: 0,
    progress: 0,
    configurations: 0,
    publications: 0,
    refills: 0,
    held_edges: 0,
    hold_cycle: 0,
    response_delay_edges: 0,
    response_hold_edges: 0,
  }
}

///|
fn descriptor_rejection_window(position : Int32) -> Int32 {
  for
    index, (first, end) in [
      (6, 26),
      (32, 42),
      (44, 47),
      (49, 60),
      (63, 70),
      (71, 76),
      (77, 81),
    ] {
    if position >= first && position < end {
      return index
    }
  }
  -1
}

///|
fn DescriptorRejectionAudit::record_request(
  self : DescriptorRejectionAudit,
  request : Request,
  acknowledged~ : Bool,
  window~ : Int32,
) -> Unit raise {
  let class = writer_fault_request_class(request)
  if window >= 0 {
    if class != 0 {
      fail("descriptor rejection window issued or acknowledged data DMA")
    }
    let counts = if acknowledged {
      self.rejected_acknowledgements
    } else {
      self.rejected_reads
    }
    counts[window] += 1
  }
  let counts = if acknowledged { self.acknowledgements } else { self.requests }
  counts[class] += 1
  if class == 1 {
    let index = match request.address {
      512UL => 0
      640UL => 1
      768UL => 2
      896UL => 3
      1024UL => 4
      _ => fail("unexpected descriptor rejection operand address")
    }
    let operands = if acknowledged {
      self.operand_acknowledgements
    } else {
      self.operand_requests
    }
    operands[index] += 1
  } else if class == 2 {
    let index = match request.address {
      1536UL => 0
      1792UL => 1
      2048UL => 2
      _ => fail("unexpected descriptor rejection store address")
    }
    let stores = if acknowledged {
      self.store_acknowledgements
    } else {
      self.store_requests
    }
    stores[index] += 1
  }
}

///|
fn DescriptorRejectionAudit::record_compute_edge(
  self : DescriptorRejectionAudit,
  before : Array[UInt64],
  after : Array[UInt64],
  cycle : Int32,
) -> Unit raise {
  if after[1] > before[1] {
    if before[0] != 0UL ||
      before[1] != 0UL ||
      after[0] != 1UL ||
      after[1] != 1UL ||
      after[2] != 2UL ||
      after[3] != 0UL ||
      after[4] != 0UL {
      fail(
        "descriptor rejection MatMul did not advance exactly one scalar Run edge",
      )
    }
    self.run_cycles.push(cycle)
  }
  if after[4] > before[4] {
    if before[4] != 0UL || after != [1UL, 1UL, 2UL, 0UL, 1UL] {
      fail(
        "descriptor rejection MatMul did not commit exactly one scalar capture",
      )
    }
    self.capture_cycles.push(cycle)
  }
}

///|
fn DescriptorRejectionAudit::record_completion(
  self : DescriptorRejectionAudit,
  actual : CompletionSnapshot,
  position : Int32,
  counters : Array[UInt64],
) -> Unit raise {
  descriptor_rejection_assert_completion(actual, position)
  if actual.fault >= 16UL {
    fail("descriptor rejection completion fault is outside the profile")
  }
  self.faults[actual.fault.to_int()] += 1
  self.progress += actual.bytes.to_int()
  for index, mat in [2, 5, 28, 29, 43, 48, 60, 70, 83] {
    if position == mat {
      if self.mat_completions != index ||
        self.run_cycles.length() != index + 1 ||
        self.capture_cycles.length() != index + 1 ||
        self.run_cycles[index] >= self.capture_cycles[index] ||
        counters != [1UL, 1UL, 2UL, 0UL, 1UL] {
        fail(
          "successful descriptor rejection MatMul lacked real Run/capture before completion",
        )
      }
      self.mat_completions += 1
    }
  }
  for index, store in [26, 27, 30, 31, 61, 62, 76, 81, 84] {
    if position == store && self.acknowledgements[2] < index + 1 {
      fail(
        "descriptor rejection Store became terminal before its saved success ACK",
      )
    }
  }
}

///|
fn DescriptorRejectionAudit::check_final(
  self : DescriptorRejectionAudit,
  host : Host,
) -> Unit raise {
  if self.requests != [2752, 7, 9] ||
    self.acknowledgements != self.requests ||
    self.operand_requests != [2, 1, 1, 2, 1] ||
    self.operand_acknowledgements != self.operand_requests ||
    self.store_requests != [4, 4, 1] ||
    self.store_acknowledgements != self.store_requests ||
    self.faults != [26, 5, 19, 5, 4, 6, 1, 2, 3, 0, 0, 0, 1, 11, 3, 0] ||
    self.rejected_reads != [640, 320, 96, 352, 224, 160, 128] ||
    self.rejected_acknowledgements != self.rejected_reads ||
    self.rejected_edges.any(count => count == 0) ||
    self.run_cycles.length() != 9 ||
    self.capture_cycles.length() != 9 ||
    self.mat_completions != 9 ||
    self.progress != 43 ||
    self.configurations != 1 ||
    self.publications != 31 ||
    self.refills != 30 ||
    self.held_edges != 32 ||
    self.hold_cycle == 0 ||
    host.requests != 2768 ||
    host.reads != 2759 ||
    host.writes != 36 ||
    host.next_tag != 2768UL ||
    host.pending is Some(_) ||
    host.held is Some(_) ||
    host.stalls == 0 ||
    self.response_delay_edges == 0 {
    fail(
      "descriptor rejection replay did not satisfy its exact observed totals",
    )
  }
}

///|
fn descriptor_rejection_summary(
  audit : DescriptorRejectionAudit,
  host : Host,
  cycles : Int32,
) -> String {
  let out = StringBuilder()
  out.write_string(
    "LUNACHIP-PHASE6-FIXTURE 1\nPROFILE flux-tile-0/fetched-concurrent\nDEVICE-ABI 1.0\nDESCRIPTOR 0.2\n",
  )
  out.write_string(
    "CYCLES \{cycles}\nCYCLE-BOUND 65536\nCOMPLETIONS 86\nSUCCESS-COMPLETIONS \{audit.faults[0]}\nFAULT-COMPLETIONS \{86 - audit.faults[0]}\n",
  )
  for fault, count in audit.faults {
    out.write_string("FAULT-COUNT \{fault} \{count}\n")
  }
  out.write_string(
    "REQUESTS \{host.requests}\nACKNOWLEDGEMENTS \{audit.acknowledgements[0] + audit.acknowledgements[1] + audit.acknowledgements[2]}\nREAD-BYTES \{host.reads}\nWRITE-BYTES \{host.writes}\nCOMPLETION-PROGRESS \{audit.progress}\nNEXT-TAG \{host.next_tag}\nLAST-ACCEPTED-TAG \{host.next_tag - 1UL}\n",
  )
  for index, name in ["DESCRIPTOR-READS", "OPERAND-READS", "WORD-WRITES"] {
    out.write_string(
      "\{name} \{audit.requests[index]}\n\{name}-ACKS \{audit.acknowledgements[index]}\n",
    )
  }
  for index, address in [512, 640, 768, 896, 1024] {
    out.write_string(
      "OPERAND-ADDRESS \{address} ACCEPTS \{audit.operand_requests[index]} ACKS \{audit.operand_acknowledgements[index]}\n",
    )
  }
  for index, address in [1536, 1792, 2048] {
    out.write_string(
      "ORACLE-WRITE-ADDRESS \{address} ACCEPTS \{audit.store_requests[index]} ACKS \{audit.store_acknowledgements[index]}\n",
    )
  }
  for
    index, (first, end) in [
      (6, 26),
      (32, 42),
      (44, 47),
      (49, 60),
      (63, 70),
      (71, 76),
      (77, 81),
    ] {
    out.write_string(
      "REJECTION-WINDOW \{first} \{end} EDGES \{audit.rejected_edges[index]} DESCRIPTOR-READS \{audit.rejected_reads[index]} ACKS \{audit.rejected_acknowledgements[index]} DATA-REQUESTS 0 DATA-ACKS 0 COUNTER-TUPLE unchanged\n",
    )
  }
  for index, position in [2, 5, 28, 29, 43, 48, 60, 70, 83] {
    out.write_string(
      "MATMUL-POSITION \{position} RUN-EDGE \{audit.run_cycles[index]} CAPTURE-EDGE \{audit.capture_cycles[index]} STEPS 1 ACTIVE 1 ELAPSED 2 STALL 0 CAPTURE 1\n",
    )
  }
  out.write_string(
    "REQUEST-READY-STALL-EDGES \{host.stalls}\nRESPONSE-DELAY-EDGES \{audit.response_delay_edges}\nRESPONSE-HOLD-EDGES \{audit.response_hold_edges}\nRING-REFILLS \{audit.refills}\nPUBLICATIONS \{audit.publications}\nPRODUCER 86\nCONSUMER 86\nCOMPLETION-HOLD-DISCOVERY-CYCLE \{audit.hold_cycle}\nCOMPLETION-HOLD-CYCLES \{audit.held_edges}\nQUIET-EDGES 8\n",
  )
  for
    (label, base) in [
      ("RESULT", 1536),
      ("UNRELATED-RESULT", 1792),
      ("RECOVERY-RESULT", 2048),
    ] {
    let mut word = 0
    for byte in 0..<4 {
      word = word | (host.memory[base + byte] << (byte * 8))
    }
    out.write_string("\{label} \{word}\n")
  }
  out.write_string(
    "ORACLE per-write-and-saved-ack-match\nHOST-BYTES 4096 match\nINITIAL-RESET 1\nJOINT-RESETS 0\nHOST-REINITIALIZATIONS 0\nTRANSPORT-POISON false\nSCOPE finite-descriptor-location-branch-priority-1x1-k1-arithmetic-on-2x2-k2-profile-no-new-overlap-or-formal-claim\nCLAIM generated-reference-only\nEND\n",
  )
  out.to_string()
}
