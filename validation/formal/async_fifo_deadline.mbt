///|
const ASYNC_FIFO_MAX_CLOCK_GAP_INTERVALS : Int = 4

///|
const ASYNC_FIFO_ACTIVATION_INTERVALS : Int = 20

///|
const ASYNC_FIFO_SYNC_AND_NONEMPTY_DESTINATION_EDGES : Int = 3

///|
const ASYNC_FIFO_READY_DESTINATION_EDGES_PER_TOKEN : Int = 4

///|
const ASYNC_FIFO_DEPTH : Int = 4

///|
const ASYNC_FIFO_COMPLETION_INTERVALS : Int = 80

///|
const ASYNC_FIFO_OBSERVATION_INTERVALS : Int = 2

///|
const ASYNC_FIFO_ENGINE_STEPS_PER_INTERVAL : Int = 2

///|
const ASYNC_FIFO_STANDARD_TASK_BOUND : Int = 128

///|
struct AsyncFifoDeadlineDerivation {
  max_clock_gap_intervals : Int
  activation_intervals : Int
  sync_and_nonempty_destination_edges : Int
  readiness_destination_edges_per_token : Int
  depth : Int
  drain_destination_edges : Int
  drain_intervals : Int
  completion_intervals : Int
  observation_intervals : Int
  valid_bmc_bound : Int
  physical_post_activation_intervals : Int
} derive(Debug, Eq)

///|
fn async_fifo_deadline_derivation() -> AsyncFifoDeadlineDerivation {
  let drain_destination_edges = ASYNC_FIFO_SYNC_AND_NONEMPTY_DESTINATION_EDGES +
    ASYNC_FIFO_READY_DESTINATION_EDGES_PER_TOKEN * ASYNC_FIFO_DEPTH
  let drain_intervals = drain_destination_edges *
    ASYNC_FIFO_MAX_CLOCK_GAP_INTERVALS
  let valid_bmc_bound = ASYNC_FIFO_ENGINE_STEPS_PER_INTERVAL *
    (
      ASYNC_FIFO_ACTIVATION_INTERVALS +
      ASYNC_FIFO_COMPLETION_INTERVALS +
      ASYNC_FIFO_OBSERVATION_INTERVALS
    )
  {
    max_clock_gap_intervals: ASYNC_FIFO_MAX_CLOCK_GAP_INTERVALS,
    activation_intervals: ASYNC_FIFO_ACTIVATION_INTERVALS,
    sync_and_nonempty_destination_edges: ASYNC_FIFO_SYNC_AND_NONEMPTY_DESTINATION_EDGES,
    readiness_destination_edges_per_token: ASYNC_FIFO_READY_DESTINATION_EDGES_PER_TOKEN,
    depth: ASYNC_FIFO_DEPTH,
    drain_destination_edges,
    drain_intervals,
    completion_intervals: ASYNC_FIFO_COMPLETION_INTERVALS,
    observation_intervals: ASYNC_FIFO_OBSERVATION_INTERVALS,
    valid_bmc_bound,
    physical_post_activation_intervals: valid_bmc_bound /
    ASYNC_FIFO_ENGINE_STEPS_PER_INTERVAL -
    ASYNC_FIFO_ACTIVATION_INTERVALS,
  }
}

///|
fn async_fifo_safety_bmc_bound(fixture : AsyncFifoFormalFixture) -> Int {
  if fixture is ValidAsyncFifo {
    async_fifo_deadline_derivation().valid_bmc_bound
  } else {
    ASYNC_FIFO_STANDARD_TASK_BOUND
  }
}
