///|
struct AsyncFifoResetTransition {
  source_reset : Bool
  destination_reset : Bool
  source_seen : Bool
  destination_seen : Bool
  source_operations : Int
  destination_operations : Int
} derive(Debug, Eq)

///|
fn async_fifo_reset_initial() -> AsyncFifoResetTransition {
  {
    source_reset: true,
    destination_reset: true,
    source_seen: false,
    destination_seen: false,
    source_operations: 0,
    destination_operations: 0,
  }
}

///|
fn async_fifo_reset_transition(
  state : AsyncFifoResetTransition,
  source_edge : Bool,
  destination_edge : Bool,
) -> AsyncFifoResetTransition {
  let source_operates = source_edge && !state.source_reset
  let destination_operates = destination_edge && !state.destination_reset
  let source_increment = if source_operates { 1 } else { 0 }
  let destination_increment = if destination_operates { 1 } else { 0 }
  {
    source_reset: if source_edge && state.source_reset && state.destination_seen {
      false
    } else {
      state.source_reset
    },
    destination_reset: if destination_edge &&
      state.destination_reset &&
      state.source_seen {
      false
    } else {
      state.destination_reset
    },
    source_seen: state.source_seen || (source_edge && state.source_reset),
    destination_seen: state.destination_seen ||
    (destination_edge && state.destination_reset),
    source_operations: state.source_operations + source_increment,
    destination_operations: state.destination_operations + destination_increment,
  }
}

///|
fn async_fifo_reset_trace(
  schedule : Array[(Bool, Bool)],
) -> Array[AsyncFifoResetTransition] {
  let trace = [async_fifo_reset_initial()]
  let mut state = trace[0]
  for edges in schedule {
    let (source_edge, destination_edge) = edges
    state = async_fifo_reset_transition(state, source_edge, destination_edge)
    trace.push(state)
  }
  trace
}

///|
test "coordinated reset transition model covers asymmetric and simultaneous edges" {
  let source_first = async_fifo_reset_trace([
    (true, false),
    (true, false),
    (false, true),
    (false, true),
    (true, false),
    (true, false),
  ])
  assert_eq(source_first, [
    {
      source_reset: true,
      destination_reset: true,
      source_seen: false,
      destination_seen: false,
      source_operations: 0,
      destination_operations: 0,
    },
    {
      source_reset: true,
      destination_reset: true,
      source_seen: true,
      destination_seen: false,
      source_operations: 0,
      destination_operations: 0,
    },
    {
      source_reset: true,
      destination_reset: true,
      source_seen: true,
      destination_seen: false,
      source_operations: 0,
      destination_operations: 0,
    },
    {
      source_reset: true,
      destination_reset: false,
      source_seen: true,
      destination_seen: true,
      source_operations: 0,
      destination_operations: 0,
    },
    {
      source_reset: true,
      destination_reset: false,
      source_seen: true,
      destination_seen: true,
      source_operations: 0,
      destination_operations: 1,
    },
    {
      source_reset: false,
      destination_reset: false,
      source_seen: true,
      destination_seen: true,
      source_operations: 0,
      destination_operations: 1,
    },
    {
      source_reset: false,
      destination_reset: false,
      source_seen: true,
      destination_seen: true,
      source_operations: 1,
      destination_operations: 1,
    },
  ])
  let destination_first = async_fifo_reset_trace([
    (false, true),
    (false, true),
    (true, false),
    (true, false),
    (false, true),
    (false, true),
  ])
  assert_eq(destination_first[destination_first.length() - 1], {
    source_reset: false,
    destination_reset: false,
    source_seen: true,
    destination_seen: true,
    source_operations: 1,
    destination_operations: 1,
  })
  let simultaneous = async_fifo_reset_trace([
    (true, true),
    (true, true),
    (true, true),
  ])
  assert_eq(simultaneous, [
    {
      source_reset: true,
      destination_reset: true,
      source_seen: false,
      destination_seen: false,
      source_operations: 0,
      destination_operations: 0,
    },
    {
      source_reset: true,
      destination_reset: true,
      source_seen: true,
      destination_seen: true,
      source_operations: 0,
      destination_operations: 0,
    },
    {
      source_reset: false,
      destination_reset: false,
      source_seen: true,
      destination_seen: true,
      source_operations: 0,
      destination_operations: 0,
    },
    {
      source_reset: false,
      destination_reset: false,
      source_seen: true,
      destination_seen: true,
      source_operations: 1,
      destination_operations: 1,
    },
  ])
  let mut frontier = [async_fifo_reset_initial()]
  for _ in 0..<6 {
    let next : Array[AsyncFifoResetTransition] = []
    for state in frontier {
      for edges in [(false, false), (true, false), (false, true), (true, true)] {
        let (source_edge, destination_edge) = edges
        let updated = async_fifo_reset_transition(
          state, source_edge, destination_edge,
        )
        if updated.source_operations > state.source_operations ||
          updated.destination_operations > state.destination_operations {
          assert_true(state.source_seen && state.destination_seen)
        }
        if !updated.source_reset || !updated.destination_reset {
          assert_true(updated.source_seen && updated.destination_seen)
        }
        next.push(updated)
      }
    }
    frontier = next
  }
}
