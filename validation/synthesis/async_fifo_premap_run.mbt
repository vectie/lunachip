///|
pub fn audit_async_fifo_pre_map_json(
  inventory_source : String,
  pre_map_source : String,
) -> AsyncFifoPreMapReport raise {
  let inventory = parse_async_fifo_role_inventory_v2(inventory_source)
  let document = parse_yosys_pre_map_json(pre_map_source)
  let issues : Array[AsyncFifoPreMapIssue] = []
  let checks = [
    "identity", "roles", "ports", "owned_state", "registers", "pipelines", "transfers",
    "binary_next", "gray_next", "full", "nonempty", "addresses", "memory_shape",
    "memory_write", "memory_read", "visible_payload", "dependency_cutsets", "crossing_fanout",
    "payload_barriers", "lane_isolation", "graph_closure",
  ]
  if document.hardware_module.name != inventory.top_module {
    premap_issue(
      issues,
      "identity.top",
      "top_module",
      inventory.top_module,
      document.hardware_module.name,
    )
  }
  if !document.creator.has_prefix("Yosys 0.68 ") {
    premap_issue(
      issues,
      "identity.creator",
      "creator",
      "Yosys 0.68",
      document.creator,
    )
  }
  let roles = bind_all_premap_roles(document.hardware_module, inventory, issues)
  if !issues.is_empty() {
    return {
      fixture: inventory.fixture,
      top_module: inventory.top_module,
      creator: document.creator,
      checks,
      issues,
      sequential_bits: 0,
      memory_bits: 0,
    }
  }
  for
    port_role in [
      ("source_clock", inventory.source_domain.clock),
      ("source_reset", inventory.source_domain.reset.signal),
      ("destination_clock", inventory.destination_domain.clock),
      ("destination_reset", inventory.destination_domain.reset.signal),
      ("source_valid", inventory.source_valid),
      ("destination_ready", inventory.destination_ready),
    ] {
    let (role, name) = port_role
    premap_check_port_alias(
      document.hardware_module,
      issues,
      role,
      roles[name],
      "input",
    )
  }
  premap_check_port_alias(
    document.hardware_module,
    issues,
    "source_ready",
    roles[inventory.source_ready],
    "output",
  )
  premap_check_port_alias(
    document.hardware_module,
    issues,
    "destination_valid",
    roles[inventory.destination_valid],
    "output",
  )
  for lane in inventory.lanes {
    premap_check_port_alias(
      document.hardware_module,
      issues,
      "lane_\{lane.index}.source",
      roles[lane.source_payload],
      "input",
    )
    premap_check_port_alias(
      document.hardware_module,
      issues,
      "lane_\{lane.index}.visible",
      roles[lane.visible_payload],
      "output",
    )
  }
  let expected_ports = 8 + inventory.lanes.length() * 2
  if document.hardware_module.ports.length() != expected_ports {
    premap_issue(
      issues,
      "port.count",
      "top",
      expected_ports.to_string(),
      document.hardware_module.ports.length().to_string(),
    )
  }
  let sequential_bits = check_owned_state(
    document.hardware_module,
    inventory,
    roles,
    issues,
  )
  check_premap_registers(document.hardware_module, inventory, roles, issues)
  check_premap_equations(document.hardware_module, inventory, roles, issues)
  check_premap_graph_closure(document.hardware_module, inventory, roles, issues)
  let mut memory_bits = 0
  for lane in inventory.lanes {
    memory_bits += premap_check_memory(
      document.hardware_module,
      inventory,
      lane,
      roles,
      issues,
    )
  }
  let memory_count = document.hardware_module.cells
    .filter(cell => cell.cell_type == "$mem_v2")
    .length()
  if memory_count != inventory.lanes.length() {
    premap_issue(
      issues,
      "memory.count",
      "lanes",
      inventory.lanes.length().to_string(),
      memory_count.to_string(),
    )
  }
  let allowed = [
    "$mux", "$pmux", "$not", "$and", "$xor", "$eq", "$eqx", "$nex", "$logic_not",
    "$logic_and", "$reduce_or", "$reduce_xor", "$dff", "$mem_v2",
  ]
  for cell in document.hardware_module.cells {
    if !allowed.contains(cell.cell_type) {
      premap_issue(
        issues,
        "cell.unsupported",
        cell.name,
        "typed whitelist",
        cell.cell_type,
      )
    }
  }
  {
    fixture: inventory.fixture,
    top_module: inventory.top_module,
    creator: document.creator,
    checks,
    issues,
    sequential_bits,
    memory_bits,
  }
}
