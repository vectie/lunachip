///|
priv struct Direct8EngineNative {
  held : Array[Array[UInt64]?]
  configuration : Array[Array[UInt64]?]
  cursors : Array[(UInt64, UInt64)?]
  states : Array[UInt64?]
  mut core : (UInt64, UInt64)?
  mut capture_cursor : (UInt64, UInt64)?
  mut capture_state : UInt64?
  mut lease : UInt64?
  advances : Array[Int]
  mut core_advances : Int
  mut captures : Int
  mut releases : Int
}

///|
fn Direct8EngineNative::new() -> Direct8EngineNative {
  {
    held: [None, None],
    configuration: [None, None],
    cursors: [None, None],
    states: [None, None],
    core: None,
    capture_cursor: None,
    capture_state: None,
    lease: None,
    advances: [0, 0],
    core_advances: 0,
    captures: 0,
    releases: 0,
  }
}

///|
// Independent integer PRE observer. It never reads unselected memory payloads.
fn Direct8EngineNative::step(
  self : Direct8EngineNative,
  read : (String) -> UInt64 raise,
) -> Unit raise {
  if read("i_reset") == 1UL {
    return
  }
  let yes = name => read(name) == 1UL
  for
    (index, client, engine, request_state, wait_state) in [
      (0, "reader", 0, 1UL, 2UL),
      (1, "engine", 2, 2UL, 3UL),
    ] {
    let state = read("q_engine_state_\{engine}")
    let valid = yes("i_" + client + "_valid")
    let config = ["base", "stride", "rows", "columns"].map(field => {
      read("t_" + client + "_" + field)
    })
    let row = read("t_" + client + "_row")
    let column = read("t_" + client + "_column")
    direct8_fair_require(!valid || state == request_state, "d8e_request_hold")
    let payload = if valid {
      Some(
        ["write", "address", "bytes", "mask", "data", "tag"].map(field => {
          read("i_" + client + "_" + field)
        }),
      )
    } else {
      None
    }
    if self.held[index] is Some(previous) {
      direct8_fair_require(payload == Some(previous), "d8e_request_hold")
    }
    if self.configuration[index] is Some(previous) {
      direct8_fair_require(config == previous, "d8e_config_hold")
    }
    if self.cursors[index] is Some(previous) {
      direct8_fair_require((row, column) == previous, "d8e_cursor_step")
    }
    if self.states[index] is Some(previous) {
      direct8_fair_require(state == previous, "d8e_wait_progress")
    }
    if state >= 1UL && state <= 3UL {
      let maximum = if index == 0 { 16UL } else { 8UL }
      direct8_fair_require(
        config[2] > 0UL &&
        config[2] <= maximum &&
        config[3] > 0UL &&
        config[3] <= maximum &&
        row < config[2] &&
        column < config[3] &&
        (index == 1 || config[2] <= 8UL || config[3] <= 8UL),
        "d8e_cursor_bounds",
      )
      // Check actual 64-bit address and its unmodified public encoding.
      let full = config[0] +
        row * config[1] +
        column * (if index == 0 { 1UL } else { 4UL })
      assert_eq(read("t_" + client + "_address_full"), full)
      if valid {
        assert_eq(payload.unwrap()[1], full & 0xffffffffUL)
      }
    }
    let accept = yes("t_" + client + "_accept")
    let advance = yes("t_" + client + "_advance")
    let last_column = column + 1UL == config[3]
    assert_eq(yes("t_" + client + "_last_column"), last_column)
    if index == 0 && state == 3UL {
      direct8_fair_require(advance, "d8e_loader_commit")
    }
    self.cursors[index] = Some(
      if accept {
        (0UL, 0UL)
      } else {
        (
          row + (if advance && last_column { 1UL } else { 0UL }),
          if advance {
            if last_column {
              0UL
            } else {
              column + 1UL
            }
          } else {
            column
          },
        )
      },
    )
    self.configuration[index] = if accept { None } else { Some(config) }
    self.held[index] = if valid && !yes("e_" + client + "_request_ready") {
      payload
    } else {
      None
    }
    self.states[index] = if yes(client + "_ack") {
      Some(
        if index == 0 {
          3UL
        } else if last_column && row + 1UL == config[2] {
          4UL
        } else {
          1UL
        },
      )
    } else if valid && yes("e_" + client + "_request_ready") {
      Some(wait_state)
    } else if index == 1 && state == 1UL {
      Some(2UL)
    } else {
      None
    }
    if advance {
      self.advances[index] += 1
    }
  }
  let core_state = read("composition_shape_core_state")
  let steps = read("x_core_steps")
  if self.core is Some(expected) {
    direct8_fair_require((core_state, steps) == expected, "d8e_core_step")
  }
  let rows = read("composition_shape_core_rows")
  let columns = read("composition_shape_core_columns")
  let reduction = read("composition_shape_core_reduction")
  if core_state == 1UL || core_state == 2UL {
    direct8_fair_require(
      read("composition_shape_core_fault") == 0UL &&
      rows > 0UL &&
      rows <= 8UL &&
      columns > 0UL &&
      columns <= 8UL &&
      reduction > 0UL &&
      reduction <= 16UL,
      "d8e_core_shape",
    )
    let total = read("x_core_total")
    direct8_fair_require(
      total == reduction + rows + columns - 2UL &&
      total > 0UL &&
      total <= 30UL &&
      steps < total &&
      (!yes("x_running") || yes("x_core_advance")),
      "d8e_core_rank",
    )
  }
  self.core = if yes("x_clear") {
    Some((2UL, steps))
  } else if yes("x_running") {
    Some((if yes("x_core_final_step") { 3UL } else { 2UL }, steps + 1UL))
  } else {
    None
  }
  if yes("x_core_advance") {
    self.core_advances += 1
  }
  let capture_state = read("composition_capture_state")
  let row = read("composition_capture_row")
  let column = read("composition_capture_column")
  if self.capture_cursor is Some(expected) {
    direct8_fair_require((row, column) == expected, "d8e_capture_step")
  }
  if self.capture_state is Some(expected) {
    direct8_fair_require(capture_state == expected, "d8e_capture_step")
  }
  let capture = yes("composition_shape_capture")
  let last_column = column + 1UL == columns
  let last = yes("x_final_capture")
  let active = capture_state == 1UL || capture_state == 2UL
  direct8_fair_require(
    (
      !active ||
      (
        read("composition_shape_core_fault") == 0UL &&
        rows > 0UL &&
        rows <= 8UL &&
        columns > 0UL &&
        columns <= 8UL &&
        row < rows &&
        column < columns
      )
    ) &&
    (!capture || active) &&
    (capture_state != 2UL || capture) &&
    last == (capture && last_column && row + 1UL == rows),
    "d8e_capture_shape",
  )
  self.capture_cursor = Some(
    if yes("x_slotted_accept") {
      (0UL, 0UL)
    } else {
      (
        row + (if capture && last_column { 1UL } else { 0UL }),
        if capture {
          if last_column {
            0UL
          } else {
            column + 1UL
          }
        } else {
          column
        },
      )
    },
  )
  self.capture_state = if capture {
    Some(if last { 3UL } else { 2UL })
  } else {
    None
  }
  let lease = read("x_lease")
  let release = yes("x_release")
  direct8_fair_require(
    self.lease.map(expected => lease == expected).unwrap_or(true) &&
    (!yes("x_ownership") || lease == 1UL) &&
    release == (last || (yes("x_compute_terminal") && !yes("x_ownership"))),
    "d8e_lease_step",
  )
  self.lease = Some(
    if yes("x_compute_legal_accept") {
      1UL
    } else if release {
      0UL
    } else {
      lease
    },
  )
  if capture {
    self.captures += 1
  }
  if release && lease == 1UL {
    self.releases += 1
  }
  direct8_engine_owner_native(read)
}

///|
fn direct8_engine_native_nodes(
  source : @ir.Module,
  pending_slot? : Bool = false,
) -> Map[String, @ir.NodeId] raise {
  let fixture = direct8_arbiter_fixture()
  assert_eq(source, fixture.hardware())
  let probe = direct8_arbiter_probe(fixture)
  let nodes = direct8_arbiter_native_nodes(source)
  for binding in direct8_engine_transfer_bindings(fixture, probe) {
    nodes[binding.name] = binding.node
  }
  for binding in direct8_engine_compute_bindings(fixture) {
    nodes[binding.name] = binding.node
  }
  for binding in direct8_engine_owner_bindings(fixture, probe) {
    nodes[binding.name] = binding.node
  }
  if pending_slot {
    let binding = direct8_done_slot_binding(fixture)
    nodes[binding.name] = binding.node
  }
  nodes
}

///|
test "direct8 engine progress on both complete slot pipelines and competing traffic" {
  let packets = Array::makei(8, index => direct8_completion_packet(index % 4))
  for (index, selectors) in [(4, 1UL), (5, 256UL), (6, 65793UL), (7, 65536UL)] {
    packets[index][3] = selectors
  }
  let result = direct8_fair_native_run(
    packets,
    Array::make(8, 0UL),
    3,
    512,
    128,
    require_competing=true,
    observe_engines=true,
  )
  assert_eq((result.admitted, result.retired), (8, 8))
}

///|
test "direct8 native engine observer rejects withdrawn request and full-width cursor corruption" {
  for kind in 0..<2 {
    let observer = Direct8EngineNative::new()
    let frame : Map[String, UInt64] = {
      "t_reader_rows": 8UL,
      "t_reader_columns": 16UL,
      "q_engine_state_0": 1UL,
      "i_reader_valid": 1UL,
      "i_reader_address": 0x80000001UL,
      "t_reader_base": 0x80000001UL,
      "t_reader_address_full": 0x80000001UL,
    }
    let read : (String) -> UInt64 raise = name => frame.get(name).unwrap_or(0UL)
    observer.step(read)
    if kind == 0 {
      frame["i_reader_valid"] = 0UL
    } else {
      observer.held[0] = None
      frame["t_reader_column"] = 4096UL
    }
    try observer.step(read) catch {
      BadFairEdge(label) =>
        assert_eq(
          label,
          if kind == 0 {
            "d8e_request_hold"
          } else {
            "d8e_cursor_step"
          },
        )
      error => fail("unexpected engine observer error: \{error}")
    } noraise {
      _ => fail("engine progress mutation must fail")
    }
  }
}

///|
test "direct8 native final capture advances the corner and releases its lease" {
  for mutation in 0..<3 {
    let observer = Direct8EngineNative::new()
    let frame : Map[String, UInt64] = {
      "composition_shape_core_rows": 8UL,
      "composition_shape_core_columns": 8UL,
      "composition_shape_core_state": 3UL,
      "composition_capture_state": 2UL,
      "composition_capture_row": 7UL,
      "composition_capture_column": 7UL,
      "composition_shape_capture": 1UL,
      "x_final_capture": 1UL,
      "x_ownership": 1UL,
      "q_engine_state_1": 2UL,
      "x_lease": 1UL,
      "x_release": 1UL,
    }
    let read : (String) -> UInt64 raise = name => frame.get(name).unwrap_or(0UL)
    observer.step(read)
    frame["composition_capture_state"] = 3UL
    frame["composition_capture_row"] = if mutation == 1 { 7UL } else { 8UL }
    frame["composition_capture_column"] = 0UL
    for
      name in [
        "composition_shape_capture", "x_final_capture", "x_ownership", "x_release",
      ] {
      frame[name] = 0UL
    }
    frame["x_lease"] = if mutation == 2 { 1UL } else { 0UL }
    if mutation == 0 {
      observer.step(read)
      assert_eq((observer.captures, observer.releases), (1, 1))
    } else {
      try observer.step(read) catch {
        BadFairEdge(label) =>
          assert_eq(
            label,
            if mutation == 1 {
              "d8e_capture_step"
            } else {
              "d8e_lease_step"
            },
          )
        error => fail("unexpected capture/lease error: \{error}")
      } noraise {
        _ => fail("stuck capture or lease must fail")
      }
    }
  }
}
