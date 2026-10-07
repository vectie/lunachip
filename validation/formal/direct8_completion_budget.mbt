///|
priv struct Direct8CompletionBudget {
  transaction : Int
  load : Int
  store : Int
  compute : Int
  engine : Int
  deadline : Int
  watch_window : Int
  required_global_steps : Int
  global_steps : Int
  age_width : Int
  age_max : Int
}

///|
// Source-derived allowance, NOT a controller-progress theorem. The ordinary
// direct generator has two engines sharing DMA and no fetched descriptor reader.
// R/H/C are public ready/response-OFFER/completion-ready windows, all equal2.
// The 2*T term allows one payload transaction plus at most one competing
// transaction. Each loader byte also has one SRAM commit; each Store word
// also has two indexed-read/synchronous-payload edges.
// Compute: Issue + clear + K+rows+columns-2 Run edges + 64 capture cells;
// the extra five edges include accepted-command/Done collection/reuse margins.
// A q3 watch has at most six older packets, so serialize seven allowances.
fn direct8_completion_budget() -> Direct8CompletionBudget {
  let transaction = 2 + 2 + 2
  let load = 8 * 16 * (2 * transaction + 1) + 2
  let store = 8 * 8 * (2 * transaction + 2) + 2
  let compute = 16 + 8 + 8 - 2 + 8 * 8 + 5
  let engine = if load > store && load > compute {
    load
  } else if store > compute {
    store
  } else {
    compute
  }
  let deadline = (2 * 3 + 1) * (4 + engine + 2 + 2)
  let watch_window = 32
  // One startup reset PRE, up to32 public-admission PREs, and the entire
  // inclusive deadline. Doubling maps DUT rising clocks to global steps.
  let required_global_steps = 2 * (1 + watch_window + deadline)
  // Round upward to a 64-global-step boundary, never truncate the watch tail.
  let global_steps = (required_global_steps + 63) / 64 * 64
  {
    transaction,
    load,
    store,
    compute,
    engine,
    deadline,
    watch_window,
    required_global_steps,
    global_steps,
    age_width: 14,
    age_max: 16383,
  }
}

///|
// Legal V2 slot0 packets. All four deliberately use the same caller ID73.
// Address ranges are disjoint and fit host4096; no numerical data is assumed.
fn direct8_completion_packet(
  index : Int,
) -> Array[UInt64] raise FormalGateError {
  let (opcode, rows, columns, reduction, base, stride) : (
    UInt64,
    UInt64,
    UInt64,
    UInt64,
    UInt64,
    UInt64,
  ) = match index {
    0 => (0UL, 8UL, 16UL, 0UL, 256UL, 16UL)
    1 => (1UL, 16UL, 8UL, 0UL, 512UL, 8UL)
    2 => (2UL, 8UL, 8UL, 16UL, 0UL, 0UL)
    3 => (3UL, 8UL, 8UL, 0UL, 1024UL, 32UL)
    _ => raise InvalidFormalBundleIdentity("direct8 completion packet index")
  }
  [
    (73UL << 32) | (opcode << 16) | 0x200UL,
    rows | (columns << 16) | (reduction << 32),
    base | (stride << 32),
    0UL,
  ]
}

///|
fn direct8_completion_packet_literal(
  index : Int,
) -> String raise FormalGateError {
  let lanes = direct8_completion_packet(index)
  "{64'd\{lanes[3]}, 64'd\{lanes[2]}, 64'd\{lanes[1]}, 64'd\{lanes[0]}}"
}

///|
fn direct8_completion_monitor_source(
  negative : Bool,
) -> String raise FormalGateError {
  let budget = direct8_completion_budget()
  direct_completion_monitor_with_parameters(negative, {
    load_literal: direct8_completion_packet_literal(0),
    store_literal: direct8_completion_packet_literal(3),
    age_width: budget.age_width,
    deadline: budget.deadline,
    age_max: budget.age_max,
  })
}
