///|
const ASYNC_FIFO_MAX_CLOCK_GAP_INTERVALS : Int32 = 4

///|
const ASYNC_FIFO_ACTIVATION_INTERVALS : Int32 = 20

///|
const ASYNC_FIFO_SYNC_AND_NONEMPTY_DESTINATION_EDGES : Int32 = 3

///|
const ASYNC_FIFO_READY_DESTINATION_EDGES_PER_TOKEN : Int32 = 4

///|
const ASYNC_FIFO_DEPTH : Int32 = 4

///|
const ASYNC_FIFO_COMPLETION_INTERVALS : Int32 = 80

///|
const ASYNC_FIFO_OBSERVATION_INTERVALS : Int32 = 2

///|
const ASYNC_FIFO_ENGINE_STEPS_PER_INTERVAL : Int32 = 2

///|
const ASYNC_FIFO_STANDARD_TASK_BOUND : Int32 = 128

///|
struct AsyncFifoDeadlineDerivation {
  max_clock_gap_intervals : Int32
  activation_intervals : Int32
  sync_and_nonempty_destination_edges : Int32
  readiness_destination_edges_per_token : Int32
  depth : Int32
  drain_destination_edges : Int32
  drain_intervals : Int32
  completion_intervals : Int32
  observation_intervals : Int32
  valid_bmc_bound : Int32
  physical_post_activation_intervals : Int32
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
fn async_fifo_safety_bmc_bound(fixture : AsyncFifoFormalFixture) -> Int32 {
  ignore(fixture)
  ASYNC_FIFO_STANDARD_TASK_BOUND
}

///|
fn async_fifo_supplemental_nonvacuity_bound() -> Int32 {
  async_fifo_deadline_derivation().valid_bmc_bound
}

///|
pub extend AsyncFifoDeadlineDerivation with @moonbitlang/core/debug.Debug::{
  to_repr,
}

///|
pub extend AsyncFifoDeadlineDerivation with Eq::{not_equal, equal}
