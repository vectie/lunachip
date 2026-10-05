///|
fn dma_poison_setup(context : FaultContext) -> Unit raise {
  let mut offered = 3
  let mut published = 0
  let mut retired = 0
  for _ in 0..<65536 {
    let simulator = context.trace.simulator
    if offered == 3 && published == 3 && retired == 3 {
      if output_value(simulator, "consumer_count") != 3UL ||
        context.host.pending is Some(_) {
        fail("DMA-poison setup changed host bytes before the first batch drain")
      }
      for position in 3..<5 {
        dma_poison_install(context.host.memory, position)
      }
      offered = 5
    }
    let events = context.tick(
      context.host.drive(context.cycle + 1),
      config_valid=if output_value(simulator, "configured") == 0UL {
        1UL
      } else {
        0UL
      },
      publish_valid=if output_value(simulator, "configured") == 1UL &&
        published != offered {
        1UL
      } else {
        0UL
      },
      publish_producer=offered.to_uint64(),
    )
    if events.publication_accepted {
      published = offered
    }
    if events.completion is Some(actual) {
      let progress : Array[UInt64] = [40UL, 40UL, 0UL, 512UL, 512UL]
      if retired >= 5 {
        fail("DMA-poison setup produced an extra completion")
      }
      assert_fault_completion(
        actual,
        (10 + retired).to_uint64(),
        0UL,
        progress[retired],
      )
      retired += 1
    }
    for name in ["ring_fault_valid", "transport_halted", "halted"] {
      if output_value(simulator, name) != 0UL {
        fail("DMA-poison setup encountered a device fault")
      }
    }
    if retired == 5 && context.host.pending is None {
      if published != 5 || output_value(simulator, "consumer_count") != 5UL {
        fail("DMA-poison signed setup did not drain exactly five packets")
      }
      return
    }
  }
  fail("DMA-poison setup exceeded the finite trace budget")
}

///|
fn dma_poison_recovery(context : FaultContext) -> Unit raise {
  let simulator = context.trace.simulator
  let expected = [ for byte in context.host.memory => byte ]
  for position in 0..<2 {
    dma_poison_recovery_install(context.host.memory, position)
    dma_poison_recovery_install(expected, position)
  }
  let requests_before = context.host.requests
  let reads_before = context.host.reads
  let writes_before = context.host.writes
  let mut published = false
  let mut retired = 0
  let mut acknowledged = 0
  for _ in 0..<65536 {
    let events = context.tick(
      context.host.drive(context.cycle + 1),
      config_valid=if output_value(simulator, "configured") == 0UL {
        1UL
      } else {
        0UL
      },
      publish_valid=if output_value(simulator, "configured") == 1UL &&
        !published {
        1UL
      } else {
        0UL
      },
      publish_producer=2UL,
    )
    if events.publication_accepted {
      published = true
    }
    if events.memory.accepted is Some(request) {
      if request.write != 0UL ||
        request.address < 8192UL ||
        request.address >= 8256UL ||
        request.bytes != 1UL ||
        request.mask != 1UL ||
        request.data != 0UL {
        fail("reset-invalidated stale MatMul issued operand or result DMA")
      }
      if context.host.requests == requests_before + 1 && request.tag != 0UL {
        fail("DMA-poison recovery did not restart global request tags at zero")
      }
    }
    if events.memory.acknowledged is Some(_) {
      acknowledged += 1
    }
    if events.completion is Some(actual) {
      match retired {
        0 => assert_fault_completion(actual, 92UL, 4UL, 0UL)
        1 => assert_fault_completion(actual, 93UL, 0UL, 0UL)
        _ => fail("DMA-poison recovery produced an extra completion")
      }
      retired += 1
    }
    for
      name in [
        "ring_fault_valid", "transport_halted", "halted", "accepted_steps", "active_cycles",
        "elapsed_cycles", "stall_cycles", "capture_cycles",
      ] {
      if output_value(simulator, name) != 0UL {
        fail("DMA-poison recovery retained poison or executed stale compute")
      }
    }
    if retired == 2 && context.host.pending is None {
      if !published ||
        acknowledged != 64 ||
        context.host.requests != requests_before + 64 ||
        context.host.reads != reads_before + 64 ||
        context.host.writes != writes_before ||
        output_value(simulator, "producer_count") != 2UL ||
        output_value(simulator, "consumer_count") != 2UL ||
        context.host.held is Some(_) {
        fail(
          "DMA-poison recovery did not finish exact fetched reset obligations",
        )
      }
      for index in 0..<16384 {
        if context.host.memory[index] != expected[index] {
          fail("DMA-poison recovery changed an unowned host byte")
        }
      }
      return
    }
  }
  fail("DMA-poison recovery exceeded the finite trace budget")
}

///|
fn generate_dma_poison_run(
  design : @ir.Design,
  hardware : @ir.Module,
  ports : ReadOnlyArray[@verilator.HarnessPort],
) -> FixtureRun raise {
  let context = fault_context(
    hardware,
    ports,
    host=dma_poison_host(),
    config_base=8192UL,
    cycle_limit=65536,
  )
  let summary = StringBuilder()
  summary.write_string(
    "LUNACHIP-PHASE6-FIXTURE 1\nPROFILE flux-tile-0/fetched-concurrent\nDEVICE-ABI 1.0\nDESCRIPTOR 0.2\nOWNERS 2\nFAULT-EPOCHS 2\n",
  )
  for owner in [Loader, Storer] {
    dma_poison_setup(context)
    let measured = run_dma_poison_epoch(context, owner)
    context.joint_reset()
    dma_poison_recovery(context)
    context.joint_reset()
    summary.write_string(dma_poison_audit(measured))
    if owner == Loader {
      // Explicit host reinitialization AFTER reset, never a hardware rollback.
      dma_poison_seed_memory(context.host.memory)
    }
  }
  summary.write_string(
    "CYCLES \{context.cycle}\nREQUESTS \{context.host.requests}\nREAD-BYTES \{context.host.reads}\nWRITE-BYTES \{context.host.writes}\nINITIAL-RESET 1\nJOINT-RESETS 4\nHOST-REINITIALIZATIONS 1\nHOST-BYTES match\nCLAIM generated-reference-only\nEND\n",
  )
  context.trace.finish(design, context.cycle, summary.to_string())
}
