///|
fn premap_graph_module(
  ports : Array[(String, PreMapPort)],
  cells : Array[PreMapCell],
) -> PreMapModule {
  { name: "graph", ports: Map(ports), cells, netnames: Map([]) }
}

///|
fn premap_input_port(wire : Int) -> PreMapPort {
  { direction: "input", signal: premap_test_signal(wire) }
}

///|
fn premap_output_port(wire : Int) -> PreMapPort {
  { direction: "output", signal: premap_test_signal(wire) }
}

///|
fn premap_xor_cell(
  name : String,
  left : PreMapSignal,
  right : PreMapSignal,
  output : PreMapSignal,
) -> PreMapCell {
  premap_test_cell(name, "$xor", [("A", left), ("B", right), ("Y", output)], [
    ("A", "input"),
    ("B", "input"),
    ("Y", "output"),
  ])
}

///|
fn premap_mux_cell(
  name : String,
  disabled : PreMapSignal,
  enabled : PreMapSignal,
  select : PreMapSignal,
  output : PreMapSignal,
) -> PreMapCell {
  premap_test_cell(
    name,
    "$mux",
    [("A", disabled), ("B", enabled), ("S", select), ("Y", output)],
    [("A", "input"), ("B", "input"), ("S", "input"), ("Y", "output")],
  )
}

///|
fn premap_memory_barrier_cell(
  name : String,
  raw_wire : Int,
  source_wire : Int,
) -> PreMapCell {
  premap_test_cell(
    name,
    "$mem_v2",
    [
      ("RD_DATA", premap_test_signal(raw_wire)),
      ("WR_DATA", premap_test_signal(source_wire)),
    ],
    [("RD_DATA", "output"), ("WR_DATA", "input")],
  )
}

///|
test "structural cutsets reject a canceled extra dependency" {
  let hardware_module = premap_graph_module(
    [("a", premap_input_port(1)), ("b", premap_input_port(2))],
    [
      premap_xor_cell(
        "cancel_b",
        premap_test_signal(2),
        premap_test_signal(2),
        premap_test_signal(3),
      ),
      premap_xor_cell(
        "semantic_a",
        premap_test_signal(1),
        premap_test_signal(3),
        premap_test_signal(4),
      ),
    ],
  )
  assert_true(
    premap_relation_matches(
      hardware_module,
      premap_test_signal(4),
      [premap_test_signal(1), premap_test_signal(2)],
      assignment => [(assignment & 1) == 1],
    ),
  )
  let issues : Array[AsyncFifoPreMapIssue] = []
  premap_check_leaf_contract(
    hardware_module,
    issues,
    "semantic_a",
    premap_test_signal(4),
    [premap_test_signal(1)],
  )
  assert_true(premap_has_issue(issues, "graph.cutset"))
}

///|
test "memory read data is a barrier and source payload cannot reach visible" {
  let hardware_module = premap_graph_module(
    [
      ("source", premap_input_port(1)),
      ("nonempty", premap_input_port(2)),
      ("visible", premap_output_port(4)),
    ],
    [
      premap_memory_barrier_cell("renamable_memory", 3, 1),
      premap_mux_cell(
        "visible_mux",
        { bits: [Zero] },
        premap_test_signal(3),
        premap_test_signal(2),
        premap_test_signal(4),
      ),
    ],
  )
  let trace = premap_graph_trace(
    hardware_module,
    premap_test_signal(4),
    premap_graph_cutpoints(hardware_module),
  )
  assert_true(trace.leaves.contains(2))
  assert_true(trace.leaves.contains(3))
  assert_false(trace.leaves.contains(1))
  let issues : Array[AsyncFifoPreMapIssue] = []
  premap_check_leaf_contract(
    hardware_module,
    issues,
    "visible",
    premap_test_signal(4),
    [premap_test_signal(3), premap_test_signal(2)],
  )
  assert_eq(issues, [])
}

///|
test "payload bypass and cross-lane raw-data mutants fail exact cutsets" {
  let bypass_module = premap_graph_module(
    [("source", premap_input_port(1)), ("nonempty", premap_input_port(2))],
    [
      premap_memory_barrier_cell("memory", 3, 1),
      premap_mux_cell(
        "bypass",
        { bits: [Zero] },
        premap_test_signal(1),
        premap_test_signal(2),
        premap_test_signal(4),
      ),
    ],
  )
  let bypass_issues : Array[AsyncFifoPreMapIssue] = []
  premap_check_leaf_contract(
    bypass_module,
    bypass_issues,
    "lane_0.visible",
    premap_test_signal(4),
    [premap_test_signal(3), premap_test_signal(2)],
  )
  assert_true(premap_has_issue(bypass_issues, "graph.cutset"))

  let cross_lane_module = premap_graph_module(
    [("nonempty", premap_input_port(2))],
    [
      premap_memory_barrier_cell("memory_0", 3, 10),
      premap_memory_barrier_cell("memory_1", 5, 11),
      premap_mux_cell(
        "cross_lane",
        { bits: [Zero] },
        premap_test_signal(5),
        premap_test_signal(2),
        premap_test_signal(4),
      ),
    ],
  )
  let lane_issues : Array[AsyncFifoPreMapIssue] = []
  premap_check_leaf_contract(
    cross_lane_module,
    lane_issues,
    "lane_0.visible",
    premap_test_signal(4),
    [premap_test_signal(3), premap_test_signal(2)],
  )
  assert_true(premap_has_issue(lane_issues, "graph.cutset"))
}

///|
fn premap_closure_inventory() -> AsyncFifoRoleInventoryV2 {
  let reset : AsyncFifoResetRole = {
    signal: "reset",
    kind: "synchronous",
    polarity: "high",
    value: "zero",
  }
  {
    fixture: "closure",
    top_module: "graph",
    depth: 4,
    synchronizer_stages: 2,
    pointer_width: 3,
    address_width: 2,
    source_domain: { clock: "source_clock", edge: "positive", reset },
    destination_domain: { clock: "destination_clock", edge: "positive", reset },
    source_valid: "source_valid",
    source_ready: "source_ready",
    destination_ready: "destination_ready",
    destination_valid: "destination_valid",
    source_transfer: "source_transfer",
    destination_transfer: "destination_transfer",
    write_binary: "wb",
    write_binary_next: "wbn",
    write_gray: "wg",
    write_gray_next: "wgn",
    read_binary: "rb",
    read_binary_next: "rbn",
    read_gray: "rg",
    read_gray_next: "rgn",
    full: "full",
    full_next: "fulln",
    nonempty: "nonempty",
    nonempty_next: "nonemptyn",
    write_address: "wa",
    read_address: "ra",
    read_gray_pipeline: ["rp0", "rp1"],
    write_gray_pipeline: ["wp0", "wp1"],
    lanes: [
      {
        index: 0,
        memory: "memory",
        width: 1,
        source_payload: "source",
        raw_read: "raw",
        visible_payload: "visible",
      },
    ],
  }
}

///|
fn premap_closure_roles() -> Map[String, PreMapSignal] {
  let roles : Map[String, PreMapSignal] = Map([])
  let names = [
    "wb", "wbn", "wg", "wgn", "rb", "rbn", "rg", "rgn", "full", "fulln", "nonempty",
    "nonemptyn", "rp0", "rp1", "wp0", "wp1", "source_valid", "source_ready", "destination_ready",
    "destination_valid", "source_transfer", "destination_transfer", "wa", "ra", "source",
    "raw", "visible", "source_clock", "destination_clock", "reset",
  ]
  for index, name in names {
    roles[name] = premap_test_signal(100 + index)
  }
  roles
}

///|
fn premap_pipeline_dff(
  name : String,
  q : PreMapSignal,
  d : PreMapSignal,
) -> PreMapCell {
  premap_test_cell(name, "$dff", [("D", d), ("Q", q)], [
    ("D", "input"),
    ("Q", "output"),
  ])
}

///|
test "crossing and pipeline fanout use state bits, not cell names" {
  let inventory = premap_closure_inventory()
  let roles = premap_closure_roles()
  let hardware_module = premap_graph_module([], [
    premap_pipeline_dff("random_stage_a", roles["rp0"], roles["rg"]),
    premap_pipeline_dff("random_stage_b", roles["rp1"], roles["rp0"]),
    premap_pipeline_dff("random_full", roles["full"], roles["rp1"]),
  ])
  assert_eq(
    premap_dependent_state_sinks(
      hardware_module,
      inventory,
      roles,
      "rg",
      Some("source"),
    )
    .keys()
    .to_array(),
    ["read_gray_pipeline_0"],
  )
  assert_eq(
    premap_dependent_state_sinks(hardware_module, inventory, roles, "rp0", None)
    .keys()
    .to_array(),
    ["read_gray_pipeline_1"],
  )
  assert_eq(
    premap_dependent_state_sinks(hardware_module, inventory, roles, "rp1", None)
    .keys()
    .to_array(),
    ["full"],
  )
}

///|
test "pipeline skip mutant creates forbidden crossing fanout" {
  let inventory = premap_closure_inventory()
  let roles = premap_closure_roles()
  let hardware_module = premap_graph_module([], [
    premap_pipeline_dff("stage_0", roles["rp0"], roles["rg"]),
    premap_pipeline_dff("stage_1", roles["rp1"], roles["rg"]),
    premap_pipeline_dff("full", roles["full"], roles["rp1"]),
  ])
  let observed = premap_dependent_state_sinks(
    hardware_module,
    inventory,
    roles,
    "rg",
    Some("source"),
  )
  assert_true(observed.contains("read_gray_pipeline_0"))
  assert_true(observed.contains("read_gray_pipeline_1"))
}

///|
test "combinational cells must reach an output state or memory sink" {
  let hardware_module = premap_graph_module(
    [("a", premap_input_port(1)), ("y", premap_output_port(2))],
    [
      premap_test_cell(
        "used",
        "$not",
        [("A", premap_test_signal(1)), ("Y", premap_test_signal(2))],
        [("A", "input"), ("Y", "output")],
      ),
      premap_test_cell(
        "orphan",
        "$not",
        [("A", premap_test_signal(1)), ("Y", premap_test_signal(9))],
        [("A", "input"), ("Y", "output")],
      ),
    ],
  )
  let issues : Array[AsyncFifoPreMapIssue] = []
  premap_check_no_orphan_cells(hardware_module, issues)
  assert_eq(issues.length(), 1)
  assert_eq(issues[0].code, "graph.orphan_cell")
  assert_eq(issues[0].role, "orphan")
}
