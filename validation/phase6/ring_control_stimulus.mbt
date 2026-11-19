///|
priv struct RingControlProgress {
  active_edges : Array[Int32]
  capture_edges : Array[Int32]
  quiet_edges : Array[Int32]
  fault_snapshots : Array[Array[UInt64]]
  mut resets : Int32
  mut final_ack_cycle : Int32
  mut fault_cycle : Int32
  mut fault_active_before : UInt64
  mut hold_cycle : Int32
}

///|
fn ring_control_step(
  context : FaultContext,
  counts : RingControlCounts,
  progress : RingControlProgress,
  epoch~ : Int32,
  config_base~ : UInt64 = 3072UL,
  config_origin~ : UInt64 = 0UL,
  config_valid~ : UInt64 = 0UL,
  publish_valid~ : UInt64 = 0UL,
  publish_producer~ : UInt64 = 0UL,
  completion_ready~ : UInt64 = 1UL,
) -> FaultEvents raise {
  let before = ring_control_core(context)
  let events = ring_control_tick(
    context,
    counts,
    epoch~,
    config_base~,
    config_origin~,
    config_valid~,
    publish_valid~,
    publish_producer~,
    completion_ready~,
  )
  let after = ring_control_core(context)
  if after[1] > before[1] {
    if after[1] != before[1] + 1UL {
      fail("ring control Run did not advance exactly one accepted edge")
    }
    progress.active_edges[epoch - 1] += 1
  }
  if after[4] > before[4] {
    if after[4] != before[4] + 1UL {
      fail("ring control capture did not commit exactly one cell")
    }
    progress.capture_edges[epoch - 1] += 1
  }
  if epoch <= 5 && (before != [0UL, 0UL, 0UL, 0UL, 0UL] || after != before) {
    fail("isolated ring fault epoch performed compute activity")
  }
  events
}

///|
fn ring_control_reset(
  context : FaultContext,
  progress : RingControlProgress,
) -> Unit raise {
  let bytes = context.host.memory[:].to_owned()
  let totals = [context.host.requests, context.host.reads, context.host.writes]
  context.joint_reset()
  if context.host.memory != bytes ||
    [context.host.requests, context.host.reads, context.host.writes] != totals {
    fail("ring control joint reset changed host bytes or lifetime totals")
  }
  progress.resets += 1
}

///|
fn ring_control_configure(
  context : FaultContext,
  counts : RingControlCounts,
  progress : RingControlProgress,
  epoch : Int32,
) -> Unit raise {
  let base = match epoch {
    1 => 4097UL
    2 => 4064UL
    3 => 0xffffffc0UL
    _ => 3072UL
  }
  let origin = if epoch <= 5 { 17UL } else { 0UL }
  for ;; {
    let accepted_before = counts.configurations[epoch - 1]
    let events = ring_control_step(
      context,
      counts,
      progress,
      epoch~,
      config_base=base,
      config_origin=origin,
      config_valid=if accepted_before == 0 { 1UL } else { 0UL },
    )
    if events.configuration_accepted &&
      (
        output_value(context.trace.simulator, "configured") != 0UL ||
        output_value(context.trace.simulator, "ring_fault_valid") != 0UL
      ) {
      fail("ring configuration validation happened on its acceptance edge")
    }
    if output_value(context.trace.simulator, "ring_fault_valid") == 1UL {
      if epoch > 3 || counts.configurations[epoch - 1] != 1 {
        fail("ring control configuration unexpectedly faulted")
      }
      ring_control_assert_fault(context, epoch)
      break
    }
    if output_value(context.trace.simulator, "configured") == 1UL {
      if epoch <= 3 ||
        counts.configurations[epoch - 1] != 1 ||
        output_value(context.trace.simulator, "producer_count") != origin ||
        output_value(context.trace.simulator, "consumer_count") != origin {
        fail("ring control validation did not establish the real empty origin")
      }
      break
    }
  }
}

///|
fn ring_control_publish(
  context : FaultContext,
  counts : RingControlCounts,
  progress : RingControlProgress,
  epoch : Int32,
  producer : UInt64,
) -> Unit raise {
  for ;; {
    let events = ring_control_step(
      context,
      counts,
      progress,
      epoch~,
      publish_valid=1UL,
      publish_producer=producer,
    )
    if events.publication_accepted {
      break
    }
  }
}

///|
fn ring_control_sticky(
  context : FaultContext,
  counts : RingControlCounts,
  progress : RingControlProgress,
  epoch : Int32,
) -> Unit raise {
  progress.fault_snapshots[epoch - 1] = ring_control_fault_snapshot(context)
  for _ in 0..<8 {
    ring_control_assert_fault(context, epoch)
    let events = ring_control_step(
      context,
      counts,
      progress,
      epoch~,
      config_valid=1UL,
      publish_valid=1UL,
      publish_producer=0UL,
    )
    if events.configuration_accepted ||
      events.publication_accepted ||
      events.completion is Some(_) ||
      events.memory.accepted is Some(_) ||
      events.memory.acknowledged is Some(_) {
      fail("sticky isolated ring fault accepted or manufactured an obligation")
    }
    ring_control_assert_fault(context, epoch)
    progress.quiet_edges[epoch - 1] += 1
  }
}

///|
fn ring_control_drain(
  context : FaultContext,
  counts : RingControlCounts,
  progress : RingControlProgress,
  epoch : Int32,
  retired : Int32,
  producer : UInt64,
  zero_core~ : Bool = false,
) -> Unit raise {
  for ;; {
    if counts.retired[epoch - 1] == retired {
      ring_control_assert_drained(context, counts, epoch, retired)
      if output_value(context.trace.simulator, "producer_count") != producer ||
        output_value(context.trace.simulator, "consumer_count") != producer {
        fail("ring control refill did not own all prior ring slots")
      }
      break
    }
    let before = ring_control_core(context)
    ignore(ring_control_step(context, counts, progress, epoch~))
    if zero_core &&
      (
        before != [0UL, 0UL, 0UL, 0UL, 0UL] ||
        ring_control_core(context) != before
      ) {
      fail("reset-unavailable commands issued compute or changed its counters")
    }
  }
}

///|
fn ring_control_quiet(
  context : FaultContext,
  counts : RingControlCounts,
  progress : RingControlProgress,
  epoch : Int32,
) -> Unit raise {
  for _ in 0..<8 {
    let simulator = context.trace.simulator
    if output_value(simulator, "completion_valid") != 0UL ||
      output_value(simulator, "memory_request_valid") != 0UL ||
      context.host.pending is Some(_) ||
      context.host.held is Some(_) {
      fail("ring control final quiet window had a live obligation")
    }
    let events = ring_control_step(context, counts, progress, epoch~)
    if events.completion is Some(_) ||
      events.memory.accepted is Some(_) ||
      events.memory.acknowledged is Some(_) {
      fail("ring control final quiet edge created an extra obligation")
    }
    if epoch == 6 {
      ring_control_assert_fault(context, epoch)
    }
    if output_value(simulator, "completion_valid") != 0UL ||
      output_value(simulator, "memory_request_valid") != 0UL ||
      context.host.pending is Some(_) ||
      context.host.held is Some(_) {
      fail("ring control quiet window changed after its edge")
    }
    progress.quiet_edges[epoch - 1] += 1
  }
}

///|
fn ring_control_long_epoch(
  context : FaultContext,
  counts : RingControlCounts,
  progress : RingControlProgress,
) -> Unit raise {
  let simulator = context.trace.simulator
  ring_control_configure(context, counts, progress, 6)
  for position in 0..<2 {
    ring_control_install(context.host.memory, 6, position)
  }
  ring_control_publish(context, counts, progress, 6, 2UL)
  ring_control_drain(context, counts, progress, 6, 2, 2UL)
  for position in 2..<6 {
    ring_control_install(context.host.memory, 6, position)
  }
  ring_control_publish(context, counts, progress, 6, 6UL)
  for ;; {
    if counts.retired[5] == 4 {
      break
    }
    let active = output_value(simulator, "active_cycles")
    let inject = progress.final_ack_cycle > 0 &&
      progress.fault_cycle == 0 &&
      output_value(simulator, "consumer_count") == 3UL &&
      output_value(simulator, "publish_ready") == 1UL
    if inject &&
      (
        output_value(simulator, "producer_count") != 6UL ||
        active == 0UL ||
        active >= 512UL ||
        context.host.pending is Some(_) ||
        context.host.held is Some(_)
      ) {
      fail("ring control packet/publication boundary missed advancing long Run")
    }
    let visible_mat = counts.retired[5] == 2 &&
      output_value(simulator, "completion_valid") == 1UL
    if visible_mat {
      ring_control_assert_completion(completion_snapshot(simulator), 6, 2)
      if progress.hold_cycle == 0 {
        progress.hold_cycle = context.cycle + 1
      }
    }
    let holding = visible_mat && counts.held_edges < 32
    let events = ring_control_step(
      context,
      counts,
      progress,
      epoch=6,
      publish_valid=if inject { 1UL } else { 0UL },
      publish_producer=8UL,
      completion_ready=if holding { 0UL } else { 1UL },
    )
    if events.memory.acknowledged is Some(request) &&
      request.write == 0UL &&
      request.address == 3199UL {
      if progress.final_ack_cycle != 0 {
        fail("ring control Store packet final byte acknowledged twice")
      }
      progress.final_ack_cycle = context.cycle
    }
    if inject {
      if !events.publication_accepted ||
        output_value(simulator, "producer_count") != 6UL ||
        output_value(simulator, "consumer_count") != 4UL ||
        output_value(simulator, "active_cycles") != active + 1UL {
        fail(
          "bad publication did not coincide with one genuine packet/Run edge",
        )
      }
      ring_control_assert_fault(context, 6)
      progress.fault_snapshots[5] = ring_control_fault_snapshot(context)
      progress.fault_cycle = context.cycle
      progress.fault_active_before = active
    }
    if progress.fault_cycle > 0 {
      ring_control_assert_fault(context, 6)
    }
  }
  if progress.final_ack_cycle == 0 ||
    progress.fault_cycle <= progress.final_ack_cycle ||
    progress.hold_cycle == 0 ||
    counts.held_edges != 32 ||
    ring_control_core(context) != [512UL, 512UL, 513UL, 0UL, 1UL] {
    fail("ring control long command did not complete its observed overlap/hold")
  }
  ring_control_assert_drained(context, counts, 6, 4)
  ring_control_assert_fault(context, 6)
  ring_control_quiet(context, counts, progress, 6)
}

///|
fn ring_control_trace(
  design : @ir.Design,
  hardware : @ir.Module,
  ports : ReadOnlyArray[@verilator.HarnessPort],
) -> FixtureRun raise {
  let host : Host = {
    kind: Concurrent,
    memory: ring_control_memory(),
    pending: None,
    held: None,
    next_tag: 0UL,
    requests: 0,
    reads: 0,
    writes: 0,
    stalls: 0,
  }
  let context = fault_context(hardware, ports, host~, cycle_limit=32768)
  let counts = ring_control_counts()
  let progress : RingControlProgress = {
    active_edges: Array::make(7, 0),
    capture_edges: Array::make(7, 0),
    quiet_edges: Array::make(7, 0),
    resets: 0,
    final_ack_cycle: 0,
    fault_snapshots: [
      for _ in 0..<7 => [0UL, 0UL, 0UL, 0UL, 0UL]
    ],
    fault_cycle: 0,
    fault_active_before: 0UL,
    hold_cycle: 0,
  }
  for epoch in 1..<=5 {
    ring_control_configure(context, counts, progress, epoch)
    if epoch == 4 {
      ring_control_publish(context, counts, progress, epoch, 17UL)
      if counts.requests[3] != [0, 0, 0] || counts.acks[3] != [0, 0, 0] {
        fail("unchanged producer publication caused a fetch")
      }
      ring_control_publish(context, counts, progress, epoch, 16UL)
    } else if epoch == 5 {
      ring_control_publish(context, counts, progress, epoch, 22UL)
    }
    ring_control_sticky(context, counts, progress, epoch)
    ring_control_reset(context, progress)
  }
  ring_control_long_epoch(context, counts, progress)
  ring_control_reset(context, progress)
  ring_control_configure(context, counts, progress, 7)
  for position in 0..<4 {
    ring_control_install(context.host.memory, 7, position)
  }
  ring_control_publish(context, counts, progress, 7, 4UL)
  ring_control_drain(context, counts, progress, 7, 4, 4UL, zero_core=true)
  for position in 4..<7 {
    ring_control_install(context.host.memory, 7, position)
  }
  ring_control_publish(context, counts, progress, 7, 7UL)
  ring_control_drain(context, counts, progress, 7, 7, 7UL)
  ring_control_quiet(context, counts, progress, 7)
  if progress.resets != 6 ||
    progress.active_edges != [0, 0, 0, 0, 0, 512, 1] ||
    progress.capture_edges != [0, 0, 0, 0, 0, 1, 1] ||
    progress.quiet_edges != [8, 8, 8, 8, 8, 8, 8] ||
    ring_control_core(context) != [1UL, 1UL, 2UL, 0UL, 1UL] {
    fail(
      "ring control bounded seven-epoch Run/capture/reset obligations incomplete",
    )
  }
  ring_control_assert_totals(context, counts)
  verify_ring_control_memory(host.memory)
  context.trace.finish(
    design,
    context.cycle,
    ring_control_summary(context, counts, progress),
  )
}
