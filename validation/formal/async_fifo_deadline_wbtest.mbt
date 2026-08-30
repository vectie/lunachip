///|
fn async_fifo_deadline_artifact(
  bundle : AsyncFifoFormalBundle,
  path : String,
) -> String raise {
  for artifact in bundle.artifacts() {
    if artifact.path() == path {
      return artifact.content()
    }
  }
  fail("missing deadline artifact \{path}")
}

///|
test "asynchronous FIFO completion bound has physical nonvacuity margin" {
  let derivation = async_fifo_deadline_derivation()
  assert_eq(derivation.max_clock_gap_intervals, 4)
  assert_eq(derivation.activation_intervals, 20)
  assert_eq(derivation.sync_and_nonempty_destination_edges, 3)
  assert_eq(derivation.readiness_destination_edges_per_token, 4)
  assert_eq(derivation.depth, 4)
  assert_eq(derivation.drain_destination_edges, 19)
  assert_eq(derivation.drain_intervals, 76)
  assert_true(derivation.drain_intervals <= derivation.completion_intervals)
  assert_eq(derivation.completion_intervals, 80)
  assert_eq(derivation.observation_intervals, 2)
  assert_eq(derivation.valid_bmc_bound, 204)
  assert_eq(derivation.physical_post_activation_intervals, 82)
  assert_true(
    derivation.physical_post_activation_intervals >=
    derivation.completion_intervals + derivation.observation_intervals,
  )
}

///|
test "asynchronous FIFO parent and supplemental bounds stay distinct" {
  let valid = generate_async_fifo_formal_bundle(ValidAsyncFifo)
  assert_eq(valid.tasks().length(), 7)
  assert_eq(valid.tasks()[0].bound(), 128)
  assert_true(
    valid.tasks()[1:].all(task => {
      task.task_class() is BoundedCoverTask && task.bound() == 128
    }),
  )
  let valid_source = async_fifo_deadline_artifact(valid, "source-set.lcfs")
  assert_true(valid_source.contains("SAFETY-BMC-BOUND engine-steps 128\n"))
  assert_true(valid_source.contains("COVER-BOUND engine-steps 128\n"))
  assert_true(
    valid_source.contains(
      "SUPPLEMENTAL-NONVACUITY-BMC-BOUND engine-steps 204 formula 2*(20-activation+80-completion+2-observation) property watched-token-consumed-only parent-claim false\n",
    ),
  )
  assert_true(
    valid_source.contains(
      "COMPLETION-DRAIN-BOUND scheduling-intervals 76 formula (3-sync-and-nonempty+4-ready-edges*4-tokens)*4-clock-gap\n",
    ),
  )
  assert_true(
    valid_source.contains(
      "COMPLETION-BOUND scheduling-intervals 80 conditional-on-bounded-clocks-eventual-ready-and-at-least-80-remaining-scheduling-intervals\n",
    ),
  )
  assert_true(
    async_fifo_deadline_artifact(valid, "valid-async-fifo-bmc.lcfg").contains(
      "BOUND 128\n",
    ),
  )
  let valid_execution = async_fifo_deadline_artifact(
    valid, "valid-async-fifo-bmc.lcfg",
  )
  assert_true(
    valid_execution.contains(
      "COMPLETION-BOUND conditional 80-scheduling-intervals-with-at-least-80-remaining-scheduling-intervals\n",
    ),
  )
  assert_false(valid_execution.contains("remaining-bmc-intervals"))
  assert_true(
    async_fifo_deadline_artifact(valid, "valid-async-fifo-cover-full.lcfg").contains(
      "BOUND 128\n",
    ),
  )
  assert_true(
    valid
    .job_json()
    .contains(
      "\"name\": \"valid-async-fifo-bmc\", \"mode\": \"bmc\", \"claim\": \"bounded-safety-up-to-bound\", \"bound\": 128",
    ),
  )
  let mutants = [
    BrokenAsyncFifoGray,
    BrokenAsyncFifoFull,
    BrokenAsyncFifoAddress,
    BrokenAsyncFifoStorageOrder,
    BrokenAsyncFifoReadPipeline,
    BrokenAsyncFifoWritePipeline,
    BrokenAsyncFifoWriteAddressBounds,
    BrokenAsyncFifoReadAddressBounds,
  ]
  let mut task_count = valid.tasks().length()
  for fixture in mutants {
    let bundle = generate_async_fifo_formal_bundle(fixture)
    assert_eq(bundle.tasks().length(), 1)
    assert_eq(bundle.tasks()[0].bound(), 128)
    assert_true(
      async_fifo_deadline_artifact(bundle, "source-set.lcfs").contains(
        "SAFETY-BMC-BOUND engine-steps 128\nCOVER-BOUND engine-steps 128\n",
      ),
    )
    assert_true(
      async_fifo_deadline_artifact(bundle, fixture.id() + "-bmc.lcfg").contains(
        "BOUND 128\n",
      ),
    )
    task_count += bundle.tasks().length()
  }
  assert_eq(task_count, 15)
}

///|
fn async_fifo_watchdog_step(
  active : Bool,
  consumes : Bool,
  age : Int,
) -> (Int, Bool) {
  if active && !consumes {
    if age >= 79 {
      (age, true)
    } else {
      (age + 1, false)
    }
  } else {
    (age, false)
  }
}

///|
test "asynchronous FIFO deadline lets terminal consume win" {
  assert_eq(async_fifo_watchdog_step(true, false, 78), (79, false))
  assert_eq(async_fifo_watchdog_step(true, false, 79), (79, true))
  assert_eq(async_fifo_watchdog_step(true, true, 79), (79, false))
  assert_eq(async_fifo_watchdog_step(false, false, 79), (79, false))
  let valid = generate_async_fifo_formal_bundle(ValidAsyncFifo)
  let harness = async_fifo_deadline_artifact(valid, "formal-harness.sv")
  assert_eq(
    harness
    .split(
      "wire lc_watch_consumes = lc_destination_event && lc_watch_active && (lc_watch_remaining == 1);",
    )
    .length(),
    2,
  )
  assert_eq(
    harness
    .split(
      "if (lc_watch_active && !lc_watch_consumes) begin if (lc_watch_age >= 8'd79) lc_completion_error <= 1; else lc_watch_age <= lc_watch_age + 1; end",
    )
    .length(),
    2,
  )
  assert_false(harness.contains("lc_watch_age >= 8'd80"))
}
