///|
fn premap_role_signals(
  roles : Map[String, PreMapSignal],
  names : Array[String],
) -> Array[PreMapSignal] {
  names.map(name => roles[name])
}

///|
fn premap_check_equation_cutsets(
  hardware_module : PreMapModule,
  inventory : AsyncFifoRoleInventoryV2,
  roles : Map[String, PreMapSignal],
  issues : Array[AsyncFifoPreMapIssue],
) -> Unit {
  let read_last = inventory.read_gray_pipeline[inventory.synchronizer_stages - 1]
  let write_last = inventory.write_gray_pipeline[inventory.synchronizer_stages -
    1]
  for
    contract in [
      ("source_ready", inventory.source_ready, [inventory.full]),
      (
        "source_transfer",
        inventory.source_transfer,
        [inventory.source_valid, inventory.full],
      ),
      (
        "destination_transfer",
        inventory.destination_transfer,
        [inventory.destination_ready, inventory.nonempty],
      ),
      (
        "write_binary_next",
        inventory.write_binary_next,
        [inventory.write_binary, inventory.source_valid, inventory.full],
      ),
      (
        "write_gray_next",
        inventory.write_gray_next,
        [inventory.write_binary, inventory.source_valid, inventory.full],
      ),
      (
        "full_next",
        inventory.full_next,
        [
          inventory.write_binary,
          inventory.source_valid,
          inventory.full,
          read_last,
        ],
      ),
      (
        "read_binary_next",
        inventory.read_binary_next,
        [inventory.read_binary, inventory.destination_ready, inventory.nonempty],
      ),
      (
        "read_gray_next",
        inventory.read_gray_next,
        [inventory.read_binary, inventory.destination_ready, inventory.nonempty],
      ),
      (
        "nonempty_next",
        inventory.nonempty_next,
        [
          inventory.read_binary,
          inventory.destination_ready,
          inventory.nonempty,
          write_last,
        ],
      ),
    ] {
    let (role, target, roots) = contract
    premap_check_leaf_contract(
      hardware_module,
      issues,
      role,
      roles[target],
      premap_role_signals(roles, roots),
    )
  }
  for lane in inventory.lanes {
    premap_check_leaf_contract(
      hardware_module,
      issues,
      "lane_\{lane.index}.visible_payload",
      roles[lane.visible_payload],
      [roles[lane.raw_read], roles[inventory.nonempty]],
    )
  }
}

///|
fn premap_state_d_signal(
  hardware_module : PreMapModule,
  state : PreMapSignal,
) -> PreMapSignal? {
  let owners = premap_find_cells(hardware_module, "$dff", "Q", state)
  guard owners.length() == 1 else { return None }
  owners[0].connections.get("D")
}

///|
fn premap_dependent_state_sinks(
  hardware_module : PreMapModule,
  inventory : AsyncFifoRoleInventoryV2,
  roles : Map[String, PreMapSignal],
  root_name : String,
  domain_filter : String?,
) -> Map[String, Bool] {
  let root = premap_wire_set([roles[root_name]])
  let cutpoints = premap_graph_cutpoints(hardware_module)
  let sinks : Map[String, Bool] = Map([])
  for state_role in fifo_state_roles(inventory) {
    let (role, state, _, domain, _) = state_role
    if domain_filter is Some(expected_domain) && domain != expected_domain {
      continue
    }
    guard premap_state_d_signal(hardware_module, roles[state]) is Some(d) else {
      continue
    }
    let leaves = premap_graph_trace(hardware_module, d, cutpoints).leaves
    if premap_wire_sets_intersect(leaves, root) {
      sinks[role] = true
    }
  }
  sinks
}

///|
fn premap_check_sink_names(
  issues : Array[AsyncFifoPreMapIssue],
  role : String,
  observed : Map[String, Bool],
  expected_names : Array[String],
) -> Unit {
  let expected : Map[String, Bool] = Map([])
  for name in expected_names {
    expected[name] = true
  }
  if observed.length() != expected.length() ||
    observed.keys().any(name => !expected.contains(name)) {
    let observed_names = observed.keys().to_array()
    observed_names.sort()
    let wanted_names = expected.keys().to_array()
    wanted_names.sort()
    premap_issue(
      issues,
      "graph.pipeline_fanout",
      role,
      wanted_names.join(","),
      observed_names.join(","),
    )
  }
}

///|
fn premap_check_pipeline_fanout(
  hardware_module : PreMapModule,
  inventory : AsyncFifoRoleInventoryV2,
  roles : Map[String, PreMapSignal],
  issues : Array[AsyncFifoPreMapIssue],
) -> Unit {
  premap_check_sink_names(
    issues,
    "read_gray.crossing",
    premap_dependent_state_sinks(
      hardware_module,
      inventory,
      roles,
      inventory.read_gray,
      Some("source"),
    ),
    ["read_gray_pipeline_0"],
  )
  premap_check_sink_names(
    issues,
    "write_gray.crossing",
    premap_dependent_state_sinks(
      hardware_module,
      inventory,
      roles,
      inventory.write_gray,
      Some("destination"),
    ),
    ["write_gray_pipeline_0"],
  )
  for index, stage in inventory.read_gray_pipeline {
    premap_check_sink_names(
      issues,
      "read_gray_pipeline_\{index}",
      premap_dependent_state_sinks(
        hardware_module,
        inventory,
        roles,
        stage,
        None,
      ),
      [
        if index + 1 < inventory.synchronizer_stages {
          "read_gray_pipeline_\{index + 1}"
        } else {
          "full"
        },
      ],
    )
  }
  for index, stage in inventory.write_gray_pipeline {
    premap_check_sink_names(
      issues,
      "write_gray_pipeline_\{index}",
      premap_dependent_state_sinks(
        hardware_module,
        inventory,
        roles,
        stage,
        None,
      ),
      [
        if index + 1 < inventory.synchronizer_stages {
          "write_gray_pipeline_\{index + 1}"
        } else {
          "nonempty"
        },
      ],
    )
  }
}

///|
fn premap_required_sink_trace(
  hardware_module : PreMapModule,
) -> PreMapGraphTrace {
  let cutpoints = premap_graph_cutpoints(hardware_module)
  let combined : PreMapGraphTrace = {
    leaves: Map([]),
    cells: Map([]),
    ambiguous_wires: Map([]),
  }
  let trace_signal = fn(signal : PreMapSignal) {
    let trace = premap_graph_trace(hardware_module, signal, cutpoints)
    for wire in trace.leaves.keys() {
      combined.leaves[wire] = true
    }
    for cell in trace.cells.keys() {
      combined.cells[cell] = true
    }
    for wire in trace.ambiguous_wires.keys() {
      combined.ambiguous_wires[wire] = true
    }
  }
  for port in hardware_module.ports.values() {
    if port.direction == "output" {
      trace_signal(port.signal)
    }
  }
  for cell in hardware_module.cells {
    if cell.cell_type == "$dff" {
      match cell.connections.get("D") {
        Some(signal) => trace_signal(signal)
        None => ()
      }
    } else if cell.cell_type == "$mem_v2" {
      for port, direction in cell.directions {
        if direction == "input" {
          match cell.connections.get(port) {
            Some(signal) => trace_signal(signal)
            None => ()
          }
        }
      }
    }
  }
  combined
}

///|
fn premap_check_no_orphan_cells(
  hardware_module : PreMapModule,
  issues : Array[AsyncFifoPreMapIssue],
) -> Unit {
  let trace = premap_required_sink_trace(hardware_module)
  for index, cell in hardware_module.cells {
    if cell.cell_type != "$dff" &&
      cell.cell_type != "$mem_v2" &&
      !trace.cells.contains(index) {
      premap_issue(
        issues,
        "graph.orphan_cell",
        cell.name,
        "path to a required sink",
        cell.cell_type,
      )
    }
  }
}

///|
fn premap_check_payload_barriers(
  hardware_module : PreMapModule,
  inventory : AsyncFifoRoleInventoryV2,
  roles : Map[String, PreMapSignal],
  issues : Array[AsyncFifoPreMapIssue],
) -> Unit {
  let cutpoints = premap_graph_cutpoints(hardware_module)
  for lane in inventory.lanes {
    let source = premap_wire_set([roles[lane.source_payload]])
    for target_role in [lane.raw_read, lane.visible_payload] {
      let trace = premap_graph_trace(
        hardware_module,
        roles[target_role],
        cutpoints,
      )
      if premap_wire_sets_intersect(trace.leaves, source) {
        premap_issue(
          issues,
          "graph.payload_bypass",
          "lane_\{lane.index}.\{target_role}",
          "memory barrier",
          "source payload dependency",
        )
      }
    }
    for other in inventory.lanes {
      if other.index != lane.index {
        let trace = premap_graph_trace(
          hardware_module,
          roles[other.visible_payload],
          cutpoints,
        )
        if premap_wire_sets_intersect(trace.leaves, source) {
          premap_issue(
            issues,
            "graph.lane_isolation",
            "lane_\{other.index}.visible_payload",
            "no lane_\{lane.index} source dependency",
            "cross-lane path",
          )
        }
      }
    }
  }
}

///|
fn check_premap_graph_closure(
  hardware_module : PreMapModule,
  inventory : AsyncFifoRoleInventoryV2,
  roles : Map[String, PreMapSignal],
  issues : Array[AsyncFifoPreMapIssue],
) -> Unit {
  premap_check_equation_cutsets(hardware_module, inventory, roles, issues)
  premap_check_pipeline_fanout(hardware_module, inventory, roles, issues)
  premap_check_payload_barriers(hardware_module, inventory, roles, issues)
  premap_check_no_orphan_cells(hardware_module, issues)
}
