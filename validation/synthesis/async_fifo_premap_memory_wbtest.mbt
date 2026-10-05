///|
fn memory_test_signal(first_wire : Int, width : Int) -> PreMapSignal {
  let bits : Array[PreMapBit] = []
  for index in 0..<width {
    bits.push(Wire(first_wire + index))
  }
  { bits, }
}

///|
fn memory_test_domain(clock : String) -> AsyncFifoDomainRole {
  {
    clock,
    edge: "positive",
    reset: {
      signal: "reset",
      kind: "synchronous",
      polarity: "high",
      value: "zero",
    },
  }
}

///|
fn memory_test_inventory() -> AsyncFifoRoleInventoryV2 {
  {
    fixture: "memory-topology",
    top_module: "fifo_top",
    depth: 4,
    synchronizer_stages: 2,
    pointer_width: 3,
    address_width: 2,
    source_domain: memory_test_domain("source_clock"),
    destination_domain: memory_test_domain("destination_clock"),
    source_valid: "source_valid",
    source_ready: "source_ready",
    destination_ready: "destination_ready",
    destination_valid: "destination_valid",
    source_transfer: "source_transfer",
    destination_transfer: "destination_transfer",
    write_binary: "write_binary",
    write_binary_next: "write_binary_next",
    write_gray: "write_gray",
    write_gray_next: "write_gray_next",
    read_binary: "read_binary",
    read_binary_next: "read_binary_next",
    read_gray: "read_gray",
    read_gray_next: "read_gray_next",
    full: "full",
    full_next: "full_next",
    nonempty: "nonempty",
    nonempty_next: "nonempty_next",
    write_address: "write_address",
    read_address: "read_address",
    read_gray_pipeline: [],
    write_gray_pipeline: [],
    lanes: [
      {
        index: 0,
        memory: "lc_f0_l0",
        width: 3,
        source_payload: "source_payload_0",
        raw_read: "raw_read_0",
        visible_payload: "visible_payload_0",
      },
    ],
  }
}

///|
fn memory_test_cell(
  name : String,
  cell_type : String,
  connections : Array[(String, PreMapSignal)],
  directions : Array[(String, String)],
  parameters : Map[String, String],
) -> PreMapCell {
  {
    name,
    cell_type,
    parameters,
    connections: Map(connections),
    directions: Map(directions),
  }
}

///|
fn memory_test_mux(
  name : String,
  width : Int,
  a : PreMapSignal,
  b : PreMapSignal,
  select : PreMapSignal,
  output : PreMapSignal,
) -> PreMapCell {
  memory_test_cell(
    name,
    "$mux",
    [("A", a), ("B", b), ("S", select), ("Y", output)],
    [("A", "input"), ("B", "input"), ("S", "input"), ("Y", "output")],
    Map([("WIDTH", width.to_string(radix=2))]),
  )
}

///|
fn memory_test_parameters() -> Map[String, String] {
  Map([
    ("ABITS", "10"),
    ("INIT", "xxxxxxxxxxxx"),
    ("MEMID", "\\lc_f0_l0"),
    ("OFFSET", "0"),
    ("RD_ARST_VALUE", "xxx"),
    ("RD_CE_OVER_SRST", "0"),
    ("RD_CLK_ENABLE", "0"),
    ("RD_CLK_POLARITY", "0"),
    ("RD_COLLISION_X_MASK", "0"),
    ("RD_INIT_VALUE", "xxx"),
    ("RD_PORTS", "1"),
    ("RD_SRST_VALUE", "xxx"),
    ("RD_TRANSPARENCY_MASK", "0"),
    ("RD_WIDE_CONTINUATION", "0"),
    ("SIZE", "100"),
    ("WIDTH", "11"),
    ("WR_CLK_ENABLE", "1"),
    ("WR_CLK_POLARITY", "1"),
    ("WR_PORTS", "1"),
    ("WR_PRIORITY_MASK", "0"),
    ("WR_WIDE_CONTINUATION", "0"),
  ])
}

///|
fn memory_test_roles() -> Map[String, PreMapSignal] {
  Map([
    ("source_clock", memory_test_signal(1, 1)),
    ("destination_clock", memory_test_signal(2, 1)),
    ("source_transfer", memory_test_signal(3, 1)),
    ("write_address", memory_test_signal(10, 2)),
    ("read_address", memory_test_signal(20, 2)),
    ("source_payload_0", memory_test_signal(30, 3)),
    ("raw_read_0", memory_test_signal(40, 3)),
    ("visible_payload_0", memory_test_signal(50, 3)),
    ("nonempty", memory_test_signal(4, 1)),
  ])
}

///|
fn memory_test_fixture() -> (
  PreMapModule,
  AsyncFifoRoleInventoryV2,
  AsyncFifoLaneRole,
  Map[String, PreMapSignal],
) {
  let inventory = memory_test_inventory()
  let lane = inventory.lanes[0]
  let roles = memory_test_roles()
  let write_guard = roles["source_transfer"]
  let write_enable = memory_test_signal(60, lane.width)
  let write_data = memory_test_signal(70, lane.width)
  let write_address = memory_test_signal(80, inventory.address_width)
  let memory = memory_test_cell(
    lane.memory,
    "$mem_v2",
    [
      ("RD_ADDR", roles[inventory.read_address]),
      ("RD_ARST", { bits: [Zero], }),
      ("RD_CLK", { bits: [Unknown], }),
      ("RD_DATA", roles[lane.raw_read]),
      ("RD_EN", { bits: [One], }),
      ("RD_SRST", { bits: [Zero], }),
      ("WR_ADDR", write_address),
      ("WR_CLK", roles[inventory.source_domain.clock]),
      ("WR_DATA", write_data),
      ("WR_EN", write_enable),
    ],
    [
      ("RD_ADDR", "input"),
      ("RD_ARST", "input"),
      ("RD_CLK", "input"),
      ("RD_DATA", "output"),
      ("RD_EN", "input"),
      ("RD_SRST", "input"),
      ("WR_ADDR", "input"),
      ("WR_CLK", "input"),
      ("WR_DATA", "input"),
      ("WR_EN", "input"),
    ],
    memory_test_parameters(),
  )
  let hardware_module : PreMapModule = {
    name: "fifo_top",
    ports: Map([]),
    netnames: Map([]),
    cells: [
      memory_test_mux(
        "enable_mux",
        lane.width,
        { bits: Array::make(lane.width, Zero), },
        { bits: Array::make(lane.width, One), },
        write_guard,
        write_enable,
      ),
      memory_test_mux(
        "address_mux",
        inventory.address_width,
        { bits: Array::make(inventory.address_width, Unknown), },
        roles[inventory.write_address],
        write_guard,
        write_address,
      ),
      memory_test_mux(
        "data_mux",
        lane.width,
        { bits: Array::make(lane.width, Unknown), },
        roles[lane.source_payload],
        write_guard,
        write_data,
      ),
      memory_test_mux(
        "visible_mux",
        lane.width,
        { bits: Array::make(lane.width, Zero), },
        roles[lane.raw_read],
        roles[inventory.nonempty],
        roles[lane.visible_payload],
      ),
      memory,
    ],
  }
  (hardware_module, inventory, lane, roles)
}

///|
fn memory_test_check(
  hardware_module : PreMapModule,
  inventory : AsyncFifoRoleInventoryV2,
  lane : AsyncFifoLaneRole,
  roles : Map[String, PreMapSignal],
) -> Array[AsyncFifoPreMapIssue] {
  let issues : Array[AsyncFifoPreMapIssue] = []
  let bits = premap_check_memory(
    hardware_module, inventory, lane, roles, issues,
  )
  ignore(bits)
  issues
}

///|
test "exact single-port asynchronous-read memory topology passes" {
  let (hardware_module, inventory, lane, roles) = memory_test_fixture()
  assert_eq(memory_test_check(hardware_module, inventory, lane, roles), [])
}

///|
test "memory parameter masks continuations priorities initialization and resets are pinned" {
  for
    mutant in [
      ("INIT", "xxxxxxxxxxx"),
      ("RD_ARST_VALUE", "000"),
      ("RD_SRST_VALUE", "000"),
      ("RD_INIT_VALUE", "000"),
      ("RD_CE_OVER_SRST", "1"),
      ("RD_TRANSPARENCY_MASK", "1"),
      ("RD_COLLISION_X_MASK", "1"),
      ("RD_WIDE_CONTINUATION", "1"),
      ("WR_PRIORITY_MASK", "1"),
      ("WR_WIDE_CONTINUATION", "1"),
    ] {
    let (hardware_module, inventory, lane, roles) = memory_test_fixture()
    let (parameter, value) = mutant
    hardware_module.cells[4].parameters[parameter] = value
    let issues = memory_test_check(hardware_module, inventory, lane, roles)
    assert_true(
      issues.any(issue => {
        issue.code == "memory.parameter" && issue.role == "lane_0.\{parameter}"
      }),
    )
  }
}

///|
test "memory read owner address clock reset and direction mutants are isolated" {
  let (wrong_address, inventory, lane, roles) = memory_test_fixture()
  wrong_address.cells[4].connections["RD_ADDR"] = memory_test_signal(90, 2)
  assert_true(
    memory_test_check(wrong_address, inventory, lane, roles).any(issue => {
      issue.code == "memory.read"
    }),
  )

  let (wrong_clock, inventory, lane, roles) = memory_test_fixture()
  wrong_clock.cells[4].connections["WR_CLK"] = memory_test_signal(91, 1)
  assert_true(
    memory_test_check(wrong_clock, inventory, lane, roles).any(issue => {
      issue.code == "memory.write_clock"
    }),
  )

  let (wrong_direction, inventory, lane, roles) = memory_test_fixture()
  wrong_direction.cells[4].directions["RD_DATA"] = "input"
  assert_true(
    memory_test_check(wrong_direction, inventory, lane, roles).any(issue => {
      issue.code == "memory.port_direction"
    }),
  )

  let (second_writer, inventory, lane, roles) = memory_test_fixture()
  second_writer.cells[4].parameters["WR_PORTS"] = "10"
  assert_true(
    memory_test_check(second_writer, inventory, lane, roles).any(issue => {
      issue.code == "memory.parameter" && issue.role == "lane_0.WR_PORTS"
    }),
  )
}

///|
test "memory guarded write rejects non-X arms lane swaps and duplicate owners" {
  let (address_arm, inventory, lane, roles) = memory_test_fixture()
  address_arm.cells[1].connections["A"] = {
    bits: Array::make(inventory.address_width, Zero),
  }
  assert_true(
    memory_test_check(address_arm, inventory, lane, roles).any(issue => {
      issue.code == "memory.write_mux"
    }),
  )

  let (data_arm, inventory, lane, roles) = memory_test_fixture()
  data_arm.cells[2].connections["A"] = { bits: Array::make(lane.width, Zero), }
  assert_true(
    memory_test_check(data_arm, inventory, lane, roles).any(issue => {
      issue.code == "memory.write_mux"
    }),
  )

  let (lane_swap, inventory, lane, roles) = memory_test_fixture()
  lane_swap.cells[2].connections["B"] = memory_test_signal(95, lane.width)
  assert_true(
    memory_test_check(lane_swap, inventory, lane, roles).any(issue => {
      issue.code == "memory.write_mux"
    }),
  )

  let (duplicate, inventory, lane, roles) = memory_test_fixture()
  duplicate.cells.push(duplicate.cells[4])
  let issues : Array[AsyncFifoPreMapIssue] = []
  assert_eq(premap_check_memory(duplicate, inventory, lane, roles, issues), 0)
  assert_true(issues.any(issue => issue.code == "memory.owner"))
}

///|
test "memory replicated enable and common guard are exact" {
  let (enable_arm, inventory, lane, roles) = memory_test_fixture()
  enable_arm.cells[0].connections["B"] = { bits: [One, One, Zero], }
  assert_true(
    memory_test_check(enable_arm, inventory, lane, roles).any(issue => {
      issue.code == "memory.write_mux"
    }),
  )

  let (guard_swap, inventory, lane, roles) = memory_test_fixture()
  guard_swap.cells[2].connections["S"] = memory_test_signal(96, 1)
  assert_true(
    memory_test_check(guard_swap, inventory, lane, roles).any(issue => {
      issue.code == "memory.write_mux"
    }),
  )
}
