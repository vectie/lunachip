///|
fn bind_premap_role(
  hardware_module : PreMapModule,
  issues : Array[AsyncFifoPreMapIssue],
  roles : Map[String, PreMapSignal],
  role : String,
  name : String,
  width : Int32,
) -> Unit {
  match premap_role_signal(hardware_module, issues, role, name, width) {
    Some(signal) => roles[name] = signal
    None => ()
  }
}

///|
fn fifo_state_roles(
  inventory : AsyncFifoRoleInventoryV2,
) -> Array[(String, String, String, String, Int32)] {
  let p = inventory.pointer_width
  let roles : Array[(String, String, String, String, Int32)] = [
    (
      "write_binary",
      inventory.write_binary,
      inventory.write_binary_next,
      "source",
      p,
    ),
    ("write_gray", inventory.write_gray, inventory.write_gray_next, "source", p),
    ("full", inventory.full, inventory.full_next, "source", 1),
    (
      "read_binary",
      inventory.read_binary,
      inventory.read_binary_next,
      "destination",
      p,
    ),
    (
      "read_gray",
      inventory.read_gray,
      inventory.read_gray_next,
      "destination",
      p,
    ),
    ("nonempty", inventory.nonempty, inventory.nonempty_next, "destination", 1),
  ]
  for index, name in inventory.read_gray_pipeline {
    roles.push(("read_gray_pipeline_\{index}", name, "", "source", p))
  }
  for index, name in inventory.write_gray_pipeline {
    roles.push(("write_gray_pipeline_\{index}", name, "", "destination", p))
  }
  roles
}

///|
fn check_owned_state(
  hardware_module : PreMapModule,
  inventory : AsyncFifoRoleInventoryV2,
  roles : Map[String, PreMapSignal],
  issues : Array[AsyncFifoPreMapIssue],
) -> Int32 {
  let expected : Map[Int32, Bool] = Map([])
  let mut expected_count = 0
  for state_role in fifo_state_roles(inventory) {
    let (_, name, _, _, _) = state_role
    for bit in roles[name].bits {
      match bit {
        Wire(wire) => {
          if expected.contains(wire) {
            premap_issue(
              issues,
              "state.alias",
              name,
              "unique state bit",
              wire.to_string(),
            )
          }
          expected[wire] = true
          expected_count += 1
        }
        _ =>
          premap_issue(issues, "state.constant", name, "wire bits", "constant")
      }
    }
  }
  let observed : Map[Int32, Bool] = Map([])
  for cell in hardware_module.cells {
    if cell.cell_type == "$dff" {
      guard cell.connections.get("Q") is Some(q) else {
        premap_issue(issues, "state.q", "$dff", "Q connection", "missing")
        continue
      }
      for bit in q.bits {
        match bit {
          Wire(wire) => {
            if observed.contains(wire) {
              premap_issue(
                issues,
                "state.multiple_owner",
                "$dff",
                "one owner",
                wire.to_string(),
              )
            }
            observed[wire] = true
          }
          _ =>
            premap_issue(
              issues, "state.q_constant", "$dff", "wire Q", "constant",
            )
        }
      }
    } else if cell.cell_type.contains("dff") || cell.cell_type.contains("latch") {
      premap_issue(
        issues,
        "state.cell_type",
        cell.name,
        "$dff only",
        cell.cell_type,
      )
    }
  }
  for wire in expected.keys() {
    if !observed.contains(wire) {
      premap_issue(issues, "state.missing", "wire_\{wire}", "owned", "missing")
    }
  }
  for wire in observed.keys() {
    if !expected.contains(wire) {
      premap_issue(issues, "state.extra", "wire_\{wire}", "unowned", "present")
    }
  }
  if observed.length() != expected_count {
    premap_issue(
      issues,
      "state.bit_count",
      "owned_state",
      expected_count.to_string(),
      observed.length().to_string(),
    )
  }
  observed.length()
}

///|
fn bind_all_premap_roles(
  hardware_module : PreMapModule,
  inventory : AsyncFifoRoleInventoryV2,
  issues : Array[AsyncFifoPreMapIssue],
) -> Map[String, PreMapSignal] {
  let roles : Map[String, PreMapSignal] = Map([])
  let p = inventory.pointer_width
  let a = inventory.address_width
  for
    role_binding in [
      ("source_clock", inventory.source_domain.clock, 1),
      ("source_reset", inventory.source_domain.reset.signal, 1),
      ("destination_clock", inventory.destination_domain.clock, 1),
      ("destination_reset", inventory.destination_domain.reset.signal, 1),
      ("source_valid", inventory.source_valid, 1),
      ("source_ready", inventory.source_ready, 1),
      ("destination_ready", inventory.destination_ready, 1),
      ("destination_valid", inventory.destination_valid, 1),
      ("source_transfer", inventory.source_transfer, 1),
      ("destination_transfer", inventory.destination_transfer, 1),
      ("write_binary", inventory.write_binary, p),
      ("write_binary_next", inventory.write_binary_next, p),
      ("write_gray", inventory.write_gray, p),
      ("write_gray_next", inventory.write_gray_next, p),
      ("read_binary", inventory.read_binary, p),
      ("read_binary_next", inventory.read_binary_next, p),
      ("read_gray", inventory.read_gray, p),
      ("read_gray_next", inventory.read_gray_next, p),
      ("full", inventory.full, 1),
      ("full_next", inventory.full_next, 1),
      ("nonempty", inventory.nonempty, 1),
      ("nonempty_next", inventory.nonempty_next, 1),
      ("write_address", inventory.write_address, a),
      ("read_address", inventory.read_address, a),
    ] {
    let (role, name, width) = role_binding
    bind_premap_role(hardware_module, issues, roles, role, name, width)
  }
  for index, name in inventory.read_gray_pipeline {
    bind_premap_role(
      hardware_module,
      issues,
      roles,
      "read_gray_pipeline_\{index}",
      name,
      p,
    )
  }
  for index, name in inventory.write_gray_pipeline {
    bind_premap_role(
      hardware_module,
      issues,
      roles,
      "write_gray_pipeline_\{index}",
      name,
      p,
    )
  }
  for lane in inventory.lanes {
    bind_premap_role(
      hardware_module,
      issues,
      roles,
      "lane_\{lane.index}.source",
      lane.source_payload,
      lane.width,
    )
    bind_premap_role(
      hardware_module,
      issues,
      roles,
      "lane_\{lane.index}.raw",
      lane.raw_read,
      lane.width,
    )
    bind_premap_role(
      hardware_module,
      issues,
      roles,
      "lane_\{lane.index}.visible",
      lane.visible_payload,
      lane.width,
    )
  }
  roles
}

///|
fn check_premap_equations(
  hardware_module : PreMapModule,
  inventory : AsyncFifoRoleInventoryV2,
  roles : Map[String, PreMapSignal],
  issues : Array[AsyncFifoPreMapIssue],
) -> Unit {
  let p = inventory.pointer_width
  let mask = (1 << p) - 1
  premap_check_relation(
    hardware_module,
    issues,
    "source_ready",
    roles[inventory.source_ready],
    [roles[inventory.full]],
    assignment => [!((assignment & 1) == 1)],
  )
  if roles[inventory.destination_valid] != roles[inventory.nonempty] {
    premap_issue(
      issues, "equation.alias", "destination_valid", "nonempty", "different bits",
    )
  }
  premap_check_relation(
    hardware_module,
    issues,
    "source_transfer",
    roles[inventory.source_transfer],
    [roles[inventory.source_valid], roles[inventory.source_ready]],
    assignment => [(assignment & 1) == 1 && ((assignment >> 1) & 1) == 1],
  )
  premap_check_relation(
    hardware_module,
    issues,
    "destination_transfer",
    roles[inventory.destination_transfer],
    [roles[inventory.destination_valid], roles[inventory.destination_ready]],
    assignment => [(assignment & 1) == 1 && ((assignment >> 1) & 1) == 1],
  )
  for
    relation in [
      (
        "write_binary_next",
        inventory.write_binary,
        inventory.write_binary_next,
        inventory.source_transfer,
      ),
      (
        "read_binary_next",
        inventory.read_binary,
        inventory.read_binary_next,
        inventory.destination_transfer,
      ),
    ] {
    let (role, current, next, transfer) = relation
    premap_check_relation(
      hardware_module,
      issues,
      role,
      roles[next],
      [roles[current], roles[transfer]],
      assignment => {
        let value = assignment_word(assignment, 0, p)
        word_bits(
          if ((assignment >> p) & 1) == 1 {
            (value + 1) & mask
          } else {
            value
          },
          p,
        )
      },
    )
  }
  for
    relation in [
      (
        "write_gray_next",
        inventory.write_binary_next,
        inventory.write_gray_next,
      ),
      ("read_gray_next", inventory.read_binary_next, inventory.read_gray_next),
    ] {
    let (role, binary, gray) = relation
    premap_check_relation(
      hardware_module,
      issues,
      role,
      roles[gray],
      [roles[binary]],
      assignment => {
        let value = assignment_word(assignment, 0, p)
        word_bits(value ^ (value >> 1), p)
      },
    )
  }
  let read_last = inventory.read_gray_pipeline[inventory.synchronizer_stages - 1]
  premap_check_relation(
    hardware_module,
    issues,
    "full_next",
    roles[inventory.full_next],
    [roles[inventory.write_gray_next], roles[read_last]],
    assignment => {
      let write = assignment_word(assignment, 0, p)
      let read = assignment_word(assignment, p, p)
      [write == (read ^ (3 << (p - 2)))]
    },
  )
  let write_last = inventory.write_gray_pipeline[inventory.synchronizer_stages -
    1]
  premap_check_relation(
    hardware_module,
    issues,
    "nonempty_next",
    roles[inventory.nonempty_next],
    [roles[inventory.read_gray_next], roles[write_last]],
    assignment => {
      let read = assignment_word(assignment, 0, p)
      let write = assignment_word(assignment, p, p)
      [read != write]
    },
  )
  let write_low = {
    bits: roles[inventory.write_binary].bits[0:inventory.address_width].to_owned(),
  }
  let read_low = {
    bits: roles[inventory.read_binary].bits[0:inventory.address_width].to_owned(),
  }
  if roles[inventory.write_address] != write_low {
    premap_issue(
      issues, "address.selection", "write_address", "write_binary low bits", "mismatch",
    )
  }
  if roles[inventory.read_address] != read_low {
    premap_issue(
      issues, "address.selection", "read_address", "read_binary low bits", "mismatch",
    )
  }
}

///|
fn check_premap_registers(
  hardware_module : PreMapModule,
  inventory : AsyncFifoRoleInventoryV2,
  roles : Map[String, PreMapSignal],
  issues : Array[AsyncFifoPreMapIssue],
) -> Unit {
  for state_role in fifo_state_roles(inventory) {
    let (role, state, next, domain, _) = state_role
    if next != "" {
      let source = domain == "source"
      premap_check_register(
        hardware_module,
        issues,
        role,
        roles[state],
        roles[next],
        roles[if source {
          inventory.source_domain.clock
        } else {
          inventory.destination_domain.clock
        }],
        roles[if source {
          inventory.source_domain.reset.signal
        } else {
          inventory.destination_domain.reset.signal
        }],
      )
    }
  }
  for index, stage in inventory.read_gray_pipeline {
    premap_check_register(
      hardware_module,
      issues,
      "read_gray_pipeline_\{index}",
      roles[stage],
      roles[if index == 0 {
        inventory.read_gray
      } else {
        inventory.read_gray_pipeline[index - 1]
      }],
      roles[inventory.source_domain.clock],
      roles[inventory.source_domain.reset.signal],
    )
  }
  for index, stage in inventory.write_gray_pipeline {
    premap_check_register(
      hardware_module,
      issues,
      "write_gray_pipeline_\{index}",
      roles[stage],
      roles[if index == 0 {
        inventory.write_gray
      } else {
        inventory.write_gray_pipeline[index - 1]
      }],
      roles[inventory.destination_domain.clock],
      roles[inventory.destination_domain.reset.signal],
    )
  }
}
