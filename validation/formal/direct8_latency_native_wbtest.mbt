///|
priv struct Direct8LatencyNative {
  active : Array[Bool]
  ages : Array[Int]
  previous : Array[Int?]
  maximum : Array[Int]
  completed : Array[Int]
}

///|
fn Direct8LatencyNative::new() -> Direct8LatencyNative {
  {
    active: [false, false, false],
    ages: [0, 0, 0],
    previous: [None, None, None],
    maximum: [0, 0, 0],
    completed: [0, 0, 0],
  }
}

///|
fn Direct8LatencyNative::step(
  self : Direct8LatencyNative,
  read : (String) -> UInt64 raise,
  watches : Array[Direct8ArbiterWatch],
) -> Unit raise {
  if read("i_reset") == 1UL {
    return
  }
  let yes = name => read(name) == 1UL
  let outer = read("q_engine_state_1").to_int()
  let inner = read("composition_capture_state").to_int()
  let core = read("composition_shape_core_state").to_int()
  let capture_row = read("composition_capture_row").to_int()
  let capture_column = read("composition_capture_column").to_int()
  let steps = read("x_core_steps").to_int()
  direct8_fair_require(
    (if outer != 2 {
      inner == 0 && core == 0
    } else {
      inner >= 1 && inner <= 3
    }) &&
    (inner != 1 || (core != 0 && capture_row == 0 && capture_column == 0)) &&
    (inner != 2 || core == 3) &&
    (inner != 3 || core == 0 || core == 3) &&
    (core != 1 || steps == 0) &&
    yes("x_compute_terminal") == (outer == 2 && inner == 3),
    "d8l_phase_link",
  )
  direct8_fair_require(
    outer != 1 ||
    (yes("x_issue_accept") && yes("x_slotted_accept") && yes("x_core_accept")),
    "d8l_issue_progress",
  )
  let ranks = [0, 0, 0]
  for
    (index, client, engine, request, wait) in [
      (0, "reader", 0, 1, 2),
      (1, "engine", 2, 2, 3),
    ] {
    let state = read("q_engine_state_\{engine}").to_int()
    let watch = watches[index]
    direct8_fair_require(
      (!watch.active || state == request || state == wait) &&
      (state != wait || watch.active) &&
      yes("i_\{client}_valid") == (state == request),
      "d8l_client_phase",
    )
    let ack = yes("e_\{client}_response_valid") &&
      yes("i_\{client}_response_ready")
    direct8_fair_require(
      !watch.active || (watch.age <= 11 && (ack || watch.age < 11)),
      "d8l_client_service11",
    )
    if state >= 1 && state <= 3 {
      let row = read("t_\{client}_row").to_int()
      let column = read("t_\{client}_column").to_int()
      if engine == 0 {
        let ordinal = row * (if yes("o_load_operand") { 8 } else { 16 }) +
          column
        ranks[0] = if state == 3 {
          13 * (127 - ordinal) + 1
        } else {
          13 * (128 - ordinal) - watch.age
        }
      } else {
        ranks[2] = 14 * (64 - (row * 8 + column)) -
          (if state == 1 { 0 } else { 1 + watch.age })
      }
    }
  }
  ranks[1] = if outer == 1 {
    97
  } else if outer != 2 {
    0
  } else if inner == 3 {
    1
  } else if core == 1 {
    96
  } else if core == 2 {
    95 - steps
  } else {
    65 - (capture_row * 8 + capture_column)
  }
  self.observe(read, ranks)
}

///|
fn Direct8LatencyNative::observe(
  self : Direct8LatencyNative,
  read : (String) -> UInt64 raise,
  ranks : Array[Int],
) -> Unit raise {
  for
    (engine, done_state, bound) in [(0, 4UL, 1666), (1, 3UL, 99), (2, 4UL, 898)] {
    let state = read("q_engine_state_\{engine}")
    let busy = state != 0UL
    let done = state == done_state
    let accept = read("q_engine_accept_\{engine}") == 1UL
    let rank = ranks[engine]
    direct8_fair_require(
      if done || !busy {
        rank == 0
      } else {
        rank > 0 && rank <= bound
      },
      "d8l_potential_bounds",
    )
    if self.previous[engine] is Some(previous) {
      direct8_fair_require(rank + 1 <= previous, "d8l_potential_step")
    }
    direct8_fair_require(
      self.active[engine] == busy &&
      (if busy { self.ages[engine] > 0 } else { self.ages[engine] == 0 }),
      "d8l_age_history",
    )
    direct8_fair_require(
      !busy || self.ages[engine] + rank <= bound,
      "d8l_age_potential",
    )
    direct8_fair_require(
      !busy ||
      (self.ages[engine] <= bound && (self.ages[engine] < bound || done)),
      "d8l_command_latency",
    )
    if self.ages[engine] > self.maximum[engine] {
      self.maximum[engine] = self.ages[engine]
    }
    if done {
      self.completed[engine] += 1
    }
    self.previous[engine] = if busy && !done && !accept {
      Some(rank)
    } else {
      None
    }
    if accept {
      self.active[engine] = true
      self.ages[engine] = 1
    } else if done {
      self.active[engine] = false
      self.ages[engine] = 0
    } else if self.active[engine] && self.ages[engine] < 2047 {
      self.ages[engine] += 1
    }
  }
}

///|
test "latency observer checks competing full pipelines and compute preflight faults" {
  let packets = Array::makei(8, index => direct8_completion_packet(index % 4))
  for (index, selectors) in [(4, 1UL), (5, 256UL), (6, 65793UL), (7, 65536UL)] {
    packets[index][3] = selectors
  }
  ignore(
    direct8_fair_native_run(
      packets,
      Array::make(8, 0UL),
      3,
      512,
      128,
      require_competing=true,
      observe_engines=true,
      observe_latency=true,
    ),
  )
  ignore(
    direct8_fair_native_run(
      [direct8_completion_packet(2)],
      [4UL],
      0,
      0,
      0,
      observe_latency=true,
    ),
  )
}

///|
test "latency controls reject broken Issue linkage and high cursor ordinal" {
  let observer = Direct8LatencyNative::new()
  let frame : Map[String, UInt64] = { "q_engine_state_1": 1UL }
  let read : (String) -> UInt64 raise = name => frame.get(name).unwrap_or(0UL)
  try observer.step(read, Direct8ArbiterNative::new().watches) catch {
    BadFairEdge(label) => assert_eq(label, "d8l_issue_progress")
    error => fail("unexpected linkage failure: \{error}")
  } noraise {
    _ => fail("Issue cannot be parked")
  }
  frame["q_engine_state_1"] = 0UL
  frame["q_engine_state_0"] = 1UL
  frame["i_reader_valid"] = 1UL
  frame["t_reader_row"] = 4096UL
  try observer.step(read, Direct8ArbiterNative::new().watches) catch {
    BadFairEdge(label) => assert_eq(label, "d8l_potential_bounds")
    error => fail("unexpected high cursor failure: \{error}")
  } noraise {
    _ => fail("full cursor high bits must matter")
  }
}

///|
test "potential controls reject stalls and accept only Done at the inclusive deadline" {
  for mutation in 0..<3 {
    let observer = Direct8LatencyNative::new()
    let frame : Map[String, UInt64] = {
      "q_engine_state_0": if mutation == 0 {
        1UL
      } else {
        4UL
      },
    }
    observer.active[0] = true
    observer.ages[0] = if mutation == 0 {
      10
    } else if mutation == 1 {
      1666
    } else {
      1667
    }
    observer.previous[0] = if mutation == 0 { Some(20) } else { None }
    let ranks = [if mutation == 0 { 20 } else { 0 }, 0, 0]
    try observer.observe(name => frame.get(name).unwrap_or(0UL), ranks) catch {
      BadFairEdge(label) =>
        assert_eq(
          label,
          if mutation == 0 {
            "d8l_potential_step"
          } else {
            "d8l_age_potential"
          },
        )
      error => fail("unexpected potential failure: \{error}")
    } noraise {
      _ => assert_eq(mutation, 1)
    }
  }
}

///|
test "abstract successful inner Done with an uncleared core is not phase closed" {
  // An abstract PRE example for the selected latency relation, NOT a reachable
  // device trace or a solver-produced counterexample to the full conjunction.
  let observer = Direct8LatencyNative::new()
  observer.active[1] = true
  observer.ages[1] = 1
  let frame : Map[String, UInt64] = {
    "q_engine_state_1": 2UL,
    "composition_capture_state": 3UL,
    "composition_shape_core_state": 3UL,
    "composition_shape_core_fault": 0UL,
    "x_compute_terminal": 1UL,
  }
  let read : (String) -> UInt64 raise = name => frame.get(name).unwrap_or(0UL)
  let watches = Direct8ArbiterNative::new().watches
  observer.step(read, watches)
  // The original terminal edge collects inner Done and finishes outer Run.
  // With no final capture and fault=0, the core fault-ACK equation stays false:
  // final_capture || (inner_done && outer_run && !success).
  frame["q_engine_state_1"] = 3UL
  frame["composition_capture_state"] = 0UL
  frame["x_compute_terminal"] = 0UL
  try observer.step(read, watches) catch {
    BadFairEdge(label) => assert_eq(label, "d8l_phase_link")
    error => fail("unexpected abstract phase failure: \{error}")
  } noraise {
    _ => fail("successful inner Done must additionally establish cleared core")
  }
}
