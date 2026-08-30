///|
fn premap_string_map_has_exact_keys(
  values : Map[String, String],
  expected : Array[String],
) -> Bool {
  values.length() == expected.length() &&
  expected.all(fn(key) { values.contains(key) })
}

///|
fn premap_exact_connections(
  values : Map[String, PreMapSignal],
  expected : Array[String],
) -> Bool {
  values.length() == expected.length() &&
  expected.all(fn(key) { values.contains(key) })
}

///|
fn premap_check_memory_parameters(
  memory : PreMapCell,
  inventory : AsyncFifoRoleInventoryV2,
  lane : AsyncFifoLaneRole,
  issues : Array[AsyncFifoPreMapIssue],
) -> Unit {
  let role = "lane_\{lane.index}"
  let parameter_names = [
    "ABITS", "INIT", "MEMID", "OFFSET", "RD_ARST_VALUE", "RD_CE_OVER_SRST", "RD_CLK_ENABLE",
    "RD_CLK_POLARITY", "RD_COLLISION_X_MASK", "RD_INIT_VALUE", "RD_PORTS", "RD_SRST_VALUE",
    "RD_TRANSPARENCY_MASK", "RD_WIDE_CONTINUATION", "SIZE", "WIDTH", "WR_CLK_ENABLE",
    "WR_CLK_POLARITY", "WR_PORTS", "WR_PRIORITY_MASK", "WR_WIDE_CONTINUATION",
  ]
  if !premap_string_map_has_exact_keys(memory.parameters, parameter_names) {
    premap_issue(
      issues,
      "memory.parameter_keys",
      role,
      "exact $mem_v2 parameter inventory",
      memory.parameters.keys().to_array().join(","),
    )
  }
  for
    parameter in [
      ("WIDTH", lane.width),
      ("SIZE", inventory.depth),
      ("ABITS", inventory.address_width),
      ("OFFSET", 0),
      ("RD_PORTS", 1),
      ("WR_PORTS", 1),
      ("RD_CLK_ENABLE", 0),
      ("RD_CLK_POLARITY", 0),
      ("RD_TRANSPARENCY_MASK", 0),
      ("RD_COLLISION_X_MASK", 0),
      ("RD_WIDE_CONTINUATION", 0),
      ("RD_CE_OVER_SRST", 0),
      ("WR_CLK_ENABLE", 1),
      ("WR_CLK_POLARITY", 1),
      ("WR_PRIORITY_MASK", 0),
      ("WR_WIDE_CONTINUATION", 0),
    ] {
    let (name, expected) = parameter
    if premap_parameter_int(memory, name) != Some(expected) {
      premap_issue(
        issues,
        "memory.parameter",
        "\{role}.\{name}",
        expected.to_string(),
        memory.parameters.get(name).unwrap_or("missing"),
      )
    }
  }
  for parameter in ["RD_ARST_VALUE", "RD_SRST_VALUE", "RD_INIT_VALUE"] {
    let expected = "x".repeat(lane.width)
    if memory.parameters.get(parameter) != Some(expected) {
      premap_issue(
        issues,
        "memory.parameter",
        "\{role}.\{parameter}",
        expected,
        memory.parameters.get(parameter).unwrap_or("missing"),
      )
    }
  }
  let expected_init = "x".repeat(inventory.depth * lane.width)
  if memory.parameters.get("INIT") != Some(expected_init) {
    premap_issue(
      issues,
      "memory.parameter",
      "\{role}.INIT",
      expected_init,
      memory.parameters.get("INIT").unwrap_or("missing"),
    )
  }
  let expected_memid = "\\\{lane.memory}"
  if memory.name != lane.memory ||
    memory.parameters.get("MEMID") != Some(expected_memid) {
    premap_issue(
      issues,
      "memory.identity",
      role,
      "cell \{lane.memory} with MEMID \{expected_memid}",
      "cell \{memory.name} with MEMID \{memory.parameters.get("MEMID").unwrap_or("missing")}",
    )
  }
}

///|
fn premap_check_memory_ports(
  memory : PreMapCell,
  inventory : AsyncFifoRoleInventoryV2,
  lane : AsyncFifoLaneRole,
  roles : Map[String, PreMapSignal],
  issues : Array[AsyncFifoPreMapIssue],
) -> Unit {
  let role = "lane_\{lane.index}"
  let port_names = [
    "RD_ADDR", "RD_ARST", "RD_CLK", "RD_DATA", "RD_EN", "RD_SRST", "WR_ADDR", "WR_CLK",
    "WR_DATA", "WR_EN",
  ]
  if !premap_exact_connections(memory.connections, port_names) ||
    !premap_string_map_has_exact_keys(memory.directions, port_names) {
    premap_issue(
      issues, "memory.port_keys", role, "exact $mem_v2 port inventory", "connection or direction key drift",
    )
  }
  for port in port_names {
    let expected = if port == "RD_DATA" { "output" } else { "input" }
    if memory.directions.get(port) != Some(expected) {
      premap_issue(
        issues,
        "memory.port_direction",
        "\{role}.\{port}",
        expected,
        memory.directions.get(port).unwrap_or("missing"),
      )
    }
  }
  let read_ok = memory.connections.get("RD_ADDR") ==
    Some(roles[inventory.read_address]) &&
    memory.connections.get("RD_DATA") == Some(roles[lane.raw_read]) &&
    memory.connections.get("RD_EN") == Some({ bits: [One] }) &&
    memory.connections.get("RD_CLK") == Some({ bits: [Unknown] }) &&
    memory.connections.get("RD_ARST") == Some({ bits: [Zero] }) &&
    memory.connections.get("RD_SRST") == Some({ bits: [Zero] })
  if !read_ok {
    premap_issue(
      issues, "memory.read", role, "one lane-local asynchronous read", "mismatch",
    )
  }
  if memory.connections.get("WR_CLK") !=
    Some(roles[inventory.source_domain.clock]) {
    premap_issue(
      issues, "memory.write_clock", role, "one positive-edge source clock writer",
      "mismatch",
    )
  }
}

///|
fn premap_mux_contract_matches(
  cell : PreMapCell,
  width : Int,
  a : PreMapSignal,
  b : PreMapSignal,
  select : PreMapSignal,
  output : PreMapSignal,
) -> Bool {
  premap_string_map_has_exact_keys(cell.parameters, ["WIDTH"]) &&
  premap_parameter_int(cell, "WIDTH") == Some(width) &&
  premap_exact_connections(cell.connections, ["A", "B", "S", "Y"]) &&
  premap_string_map_has_exact_keys(cell.directions, ["A", "B", "S", "Y"]) &&
  cell.directions.get("A") == Some("input") &&
  cell.directions.get("B") == Some("input") &&
  cell.directions.get("S") == Some("input") &&
  cell.directions.get("Y") == Some("output") &&
  cell.connections.get("A") == Some(a) &&
  cell.connections.get("B") == Some(b) &&
  cell.connections.get("S") == Some(select) &&
  cell.connections.get("Y") == Some(output)
}

///|
fn premap_check_memory_write_topology(
  hardware_module : PreMapModule,
  inventory : AsyncFifoRoleInventoryV2,
  lane : AsyncFifoLaneRole,
  roles : Map[String, PreMapSignal],
  memory : PreMapCell,
  issues : Array[AsyncFifoPreMapIssue],
) -> Unit {
  let role = "lane_\{lane.index}"
  guard memory.connections.get("WR_EN") is Some(write_enable) &&
    memory.connections.get("WR_ADDR") is Some(write_port_address) &&
    memory.connections.get("WR_DATA") is Some(write_data) else {
    premap_issue(
      issues, "memory.write", role, "complete write ports", "missing",
    )
    return
  }
  let enable_muxes = premap_find_cells(
    hardware_module, "$mux", "Y", write_enable,
  )
  let address_muxes = premap_find_cells(
    hardware_module, "$mux", "Y", write_port_address,
  )
  let data_muxes = premap_find_cells(hardware_module, "$mux", "Y", write_data)
  if enable_muxes.length() != 1 ||
    address_muxes.length() != 1 ||
    data_muxes.length() != 1 {
    premap_issue(
      issues,
      "memory.write_owner",
      role,
      "one mux owner for each write port",
      "enable=\{enable_muxes.length()},address=\{address_muxes.length()},data=\{data_muxes.length()}",
    )
    return
  }
  guard enable_muxes[0].connections.get("S") is Some(write_guard) else {
    premap_issue(issues, "memory.write_guard", role, "one-bit guard", "missing")
    return
  }
  let guard_width_ok = write_guard.width() == 1
  let enable_ok = premap_mux_contract_matches(
    enable_muxes[0],
    lane.width,
    { bits: Array::make(lane.width, Zero) },
    { bits: Array::make(lane.width, One) },
    write_guard,
    write_enable,
  )
  let address_ok = premap_mux_contract_matches(
    address_muxes[0],
    inventory.address_width,
    { bits: Array::make(inventory.address_width, Unknown) },
    roles[inventory.write_address],
    write_guard,
    write_port_address,
  )
  let data_ok = premap_mux_contract_matches(
    data_muxes[0],
    lane.width,
    { bits: Array::make(lane.width, Unknown) },
    roles[lane.source_payload],
    write_guard,
    write_data,
  )
  if !guard_width_ok || !enable_ok || !address_ok || !data_ok {
    premap_issue(
      issues, "memory.write_mux", role, "replicated enable and shared X-disabled lane-local address/data muxes",
      "mismatch",
    )
  }
  premap_check_relation(
    hardware_module,
    issues,
    "\{role}.write_guard",
    write_guard,
    [roles[inventory.source_transfer], roles[inventory.write_address]],
    assignment => [(assignment & 1) == 1],
  )
}

///|
fn premap_check_memory(
  hardware_module : PreMapModule,
  inventory : AsyncFifoRoleInventoryV2,
  lane : AsyncFifoLaneRole,
  roles : Map[String, PreMapSignal],
  issues : Array[AsyncFifoPreMapIssue],
) -> Int {
  let raw = roles[lane.raw_read]
  let matches_by_raw = hardware_module.cells.filter(cell => {
    cell.cell_type == "$mem_v2" && cell.connections.get("RD_DATA") == Some(raw)
  })
  let matches_by_name = hardware_module.cells.filter(cell => {
    cell.cell_type == "$mem_v2" && cell.name == lane.memory
  })
  if matches_by_raw.length() != 1 ||
    matches_by_name.length() != 1 ||
    matches_by_raw[0] != matches_by_name[0] {
    premap_issue(
      issues,
      "memory.owner",
      "lane_\{lane.index}",
      "one lane-local $mem_v2 bound by name and RD_DATA bits",
      "name=\{matches_by_name.length()},raw=\{matches_by_raw.length()}",
    )
    return 0
  }
  let memory = matches_by_raw[0]
  premap_check_memory_parameters(memory, inventory, lane, issues)
  premap_check_memory_ports(memory, inventory, lane, roles, issues)
  premap_check_memory_write_topology(
    hardware_module, inventory, lane, roles, memory, issues,
  )
  let visible = roles[lane.visible_payload]
  premap_check_relation(
    hardware_module,
    issues,
    "lane_\{lane.index}.visible_payload",
    visible,
    [raw, roles[inventory.nonempty]],
    assignment => {
      let value = assignment_word(assignment, 0, lane.width)
      let enabled = ((assignment >> lane.width) & 1) == 1
      word_bits(if enabled { value } else { 0 }, lane.width)
    },
  )
  inventory.depth * lane.width
}
