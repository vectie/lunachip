///|
fn capacity_wrap_publish(
  context : FaultContext,
  counts : CapacityWrapCounts,
  producer : UInt64,
  completion_ready~ : UInt64 = 0UL,
) -> Unit raise {
  for ;; {
    let events = capacity_wrap_tick(
      context,
      counts,
      publish_valid=1UL,
      publish_producer=producer,
      completion_ready~,
    )
    if events.publication_accepted {
      break
    }
  }
}

///|
fn capacity_wrap_wait_refill(
  context : FaultContext,
  counts : CapacityWrapCounts,
  consumer : UInt64,
  reads : Int32,
) -> Unit raise {
  for ;; {
    if output_value(context.trace.simulator, "consumer_count") == consumer &&
      capacity_wrap_idle(context) {
      if counts.requests != reads || counts.acknowledgements != reads {
        fail(
          "capacity/wrap committed refill checkpoint has incomplete descriptor ACKs",
        )
      }
      break
    }
    ignore(capacity_wrap_tick(context, counts))
  }
}

///|
fn generate_capacity_wrap_run(
  design : @ir.Design,
  hardware : @ir.Module,
  ports : ReadOnlyArray[@verilator.HarnessPort],
) -> FixtureRun raise {
  let context = fault_context(
    hardware,
    ports,
    host=capacity_wrap_host(),
    config_origin=0xfffffffeUL,
    cycle_limit=8192,
  )
  let counts : CapacityWrapCounts = {
    configurations: 0,
    publications: 0,
    requests: 0,
    acknowledgements: 0,
    retired: 0,
    held: None,
  }
  let simulator = context.trace.simulator
  // Configuration acceptance precedes the later validation edge. Do not
  // publish until configured and the actual retained origin are visible.
  for ;; {
    ignore(
      capacity_wrap_tick(
        context,
        counts,
        config_valid=if counts.configurations == 0 { 1UL } else { 0UL },
      ),
    )
    if output_value(simulator, "configured") == 1UL {
      if counts.configurations != 1 ||
        output_value(simulator, "producer_count") != 0xfffffffeUL ||
        output_value(simulator, "consumer_count") != 0xfffffffeUL ||
        counts.requests != 0 ||
        counts.acknowledgements != 0 {
        fail("capacity/wrap configuration did not retain its actual origin")
      }
      break
    }
  }
  capacity_wrap_publish(context, counts, 0UL)
  capacity_wrap_wait_refill(context, counts, 0UL, 64)
  for position in 2..<4 {
    capacity_wrap_install(context.host.memory, position)
  }
  capacity_wrap_publish(context, counts, 2UL)
  capacity_wrap_wait_refill(context, counts, 2UL, 128)
  for position in 4..<6 {
    capacity_wrap_install(context.host.memory, position)
  }
  capacity_wrap_publish(context, counts, 4UL)
  // The last ACK means fetched, not admitted. Wait for the committed
  // saturation state and an empty host response/stalled-request owner.
  for ;; {
    if counts.requests > 192 || counts.acknowledgements > 192 {
      fail("capacity/wrap issued beyond the six published descriptors")
    }
    if counts.requests == 192 &&
      counts.acknowledgements == 192 &&
      output_value(simulator, "consumer_count") == 3UL &&
      output_value(simulator, "queue_occupancy") == 2UL &&
      output_value(simulator, "completion_valid") == 1UL &&
      output_value(simulator, "publish_ready") == 0UL &&
      capacity_wrap_idle(context) {
      break
    }
    ignore(capacity_wrap_tick(context, counts))
  }
  capacity_wrap_verify_blocked(context.host.memory)
  let slot = context.host.memory[3104:3136].to_owned()
  capacity_wrap_assert_blocked(context, counts, slot)
  for _ in 0..<32 {
    capacity_wrap_assert_blocked(context, counts, slot)
    let events = capacity_wrap_tick(context, counts)
    if events.configuration_accepted ||
      events.publication_accepted ||
      events.memory.accepted is Some(_) ||
      events.memory.acknowledged is Some(_) ||
      events.completion is Some(_) {
      fail("capacity/wrap quiet edge accepted a new obligation")
    }
    capacity_wrap_assert_blocked(context, counts, slot)
  }
  for ;; {
    if counts.retired == 6 {
      break
    }
    ignore(capacity_wrap_tick(context, counts, completion_ready=1UL))
  }
  capacity_wrap_assert_drained(context, counts, 6, 4UL)
  if counts.requests != 192 || counts.acknowledgements != 192 {
    fail("capacity/wrap drain fetched an unpublished descriptor")
  }
  for position in 6..<8 {
    capacity_wrap_install(context.host.memory, position)
  }
  capacity_wrap_publish(context, counts, 6UL, completion_ready=1UL)
  for ;; {
    if counts.retired == 8 {
      break
    }
    ignore(capacity_wrap_tick(context, counts, completion_ready=1UL))
  }
  capacity_wrap_assert_drained(context, counts, 8, 6UL)
  if counts.configurations != 1 ||
    counts.publications != 4 ||
    counts.requests != 256 ||
    counts.acknowledgements != 256 ||
    context.host.requests != 256 ||
    context.host.reads != 256 ||
    context.host.writes != 0 ||
    context.host.next_tag != 256UL {
    fail("capacity/wrap final transaction and publication totals differ")
  }
  capacity_wrap_verify_final(context.host.memory)
  let summary = StringBuilder()
  summary.write_string("LUNACHIP-PHASE6-FIXTURE 1\n")
  summary.write_string("PROFILE flux-tile-0/fetched-concurrent\n")
  summary.write_string(
    "FIXTURE fetched-concurrent-1x1-k1-capacity-origin-wrap\n",
  )
  summary.write_string("DEVICE-ABI 1.0\nDESCRIPTOR 0.2\n")
  summary.write_string("CYCLES \{context.cycle}\n")
  summary.write_string("CONFIGURATION-ACCEPTS \{counts.configurations}\n")
  summary.write_string("CONFIG-ORIGIN \{context.config_origin}\n")
  summary.write_string("PUBLICATION-ACCEPTS \{counts.publications}\n")
  summary.write_string("PUBLICATION-PRODUCERS 0 2 4 6\n")
  summary.write_string("COMPLETIONS \{counts.retired}\n")
  summary.write_string(
    "REQUESTS \{counts.requests}\nACKS \{counts.acknowledgements}\n",
  )
  summary.write_string(
    "DESCRIPTOR-READS \{context.host.reads}\nOPERAND-READS 0\nWRITE-BYTES \{context.host.writes}\n",
  )
  summary.write_string("BLOCKED-ADMITTED 5\nBLOCKED-FETCHED 6\n")
  summary.write_string(
    "BLOCKED-CONSUMER 3\nBLOCKED-PRODUCER 4\nBLOCKED-QUEUE 2\n",
  )
  summary.write_string(
    "BLOCKED-REQUESTS 192\nBLOCKED-ACKS 192\nQUIET-EDGES 32\n",
  )
  summary.write_string("HELD-TERMINAL-STABLE true\nHELD-SLOT-BYTES match\n")
  summary.write_string(
    "FINAL-CONSUMER \{output_value(simulator, "consumer_count")}\n",
  )
  summary.write_string(
    "FINAL-PRODUCER \{output_value(simulator, "producer_count")}\n",
  )
  summary.write_string("STARTUP-RESETS 1\nCOMPUTE-COUNTERS 0 0 0 0 0\n")
  summary.write_string(
    "HOST-BYTES 4096 match\nCLAIM generated-reference-only\nEND\n",
  )
  context.trace.finish(design, context.cycle, summary.to_string())
}
