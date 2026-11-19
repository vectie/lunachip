///|
priv struct PreMapGraphDriver {
  cell_index : Int32
  bit_index : Int32
}

///|
priv struct PreMapGraphTrace {
  leaves : Map[Int32, Bool]
  cells : Map[Int32, Bool]
  ambiguous_wires : Map[Int32, Bool]
}

///|
fn premap_wire_set_add_signal(
  wires : Map[Int32, Bool],
  signal : PreMapSignal,
) -> Unit {
  for bit in signal.bits {
    match bit {
      Wire(wire) => wires[wire] = true
      _ => ()
    }
  }
}

///|
fn premap_wire_set(signals : Array[PreMapSignal]) -> Map[Int32, Bool] {
  let wires : Map[Int32, Bool] = Map([])
  for signal in signals {
    premap_wire_set_add_signal(wires, signal)
  }
  wires
}

///|
fn premap_wire_drivers(
  hardware_module : PreMapModule,
  wire : Int32,
) -> Array[PreMapGraphDriver] {
  let drivers : Array[PreMapGraphDriver] = []
  for cell_index, cell in hardware_module.cells {
    for port, direction in cell.directions {
      if direction == "output" {
        guard cell.connections.get(port) is Some(signal) else { continue }
        for bit_index, bit in signal.bits {
          if bit == Wire(wire) {
            drivers.push({ cell_index, bit_index, })
          }
        }
      }
    }
  }
  drivers
}

///|
fn premap_graph_input_at(
  cell : PreMapCell,
  name : String,
  index : Int32,
  out : Array[PreMapBit],
) -> Unit {
  guard cell.connections.get(name) is Some(signal) else { return }
  if index >= 0 && index < signal.bits.length() {
    out.push(signal.bits[index])
  }
}

///|
fn premap_graph_input_all(
  cell : PreMapCell,
  name : String,
  out : Array[PreMapBit],
) -> Unit {
  guard cell.connections.get(name) is Some(signal) else { return }
  for bit in signal.bits {
    out.push(bit)
  }
}

///|
fn premap_graph_dependencies(
  cell : PreMapCell,
  output_index : Int32,
) -> Array[PreMapBit] {
  let dependencies : Array[PreMapBit] = []
  match cell.cell_type {
    "$not" => premap_graph_input_at(cell, "A", output_index, dependencies)
    "$and" | "$xor" => {
      premap_graph_input_at(cell, "A", output_index, dependencies)
      premap_graph_input_at(cell, "B", output_index, dependencies)
    }
    "$reduce_or" | "$reduce_xor" | "$logic_not" =>
      premap_graph_input_all(cell, "A", dependencies)
    "$logic_and" | "$eq" | "$eqx" | "$nex" => {
      premap_graph_input_all(cell, "A", dependencies)
      premap_graph_input_all(cell, "B", dependencies)
    }
    "$mux" => {
      premap_graph_input_at(cell, "A", output_index, dependencies)
      premap_graph_input_at(cell, "B", output_index, dependencies)
      premap_graph_input_all(cell, "S", dependencies)
    }
    "$pmux" => {
      premap_graph_input_at(cell, "A", output_index, dependencies)
      let width = premap_parameter_int(cell, "WIDTH").unwrap_or(0)
      guard cell.connections.get("S") is Some(select) else {
        return dependencies
      }
      for select_index in 0..<select.bits.length() {
        premap_graph_input_at(
          cell,
          "B",
          select_index * width + output_index,
          dependencies,
        )
      }
      premap_graph_input_all(cell, "S", dependencies)
    }
    _ =>
      for port, direction in cell.directions {
        if direction == "input" {
          premap_graph_input_all(cell, port, dependencies)
        }
      }
  }
  dependencies
}

///|
fn premap_graph_trace_bit(
  hardware_module : PreMapModule,
  bit : PreMapBit,
  cutpoints : Map[Int32, Bool],
  trace : PreMapGraphTrace,
  visiting : Map[Int32, Bool],
) -> Unit {
  guard bit is Wire(wire) else { return }
  if cutpoints.contains(wire) {
    trace.leaves[wire] = true
    return
  }
  if visiting.contains(wire) {
    trace.ambiguous_wires[wire] = true
    return
  }
  let drivers = premap_wire_drivers(hardware_module, wire)
  if drivers.length() != 1 {
    trace.ambiguous_wires[wire] = true
    trace.leaves[wire] = true
    return
  }
  let driver = drivers[0]
  let cell = hardware_module.cells[driver.cell_index]
  if cell.cell_type == "$dff" || cell.cell_type == "$mem_v2" {
    trace.leaves[wire] = true
    return
  }
  trace.cells[driver.cell_index] = true
  visiting[wire] = true
  for dependency in premap_graph_dependencies(cell, driver.bit_index) {
    premap_graph_trace_bit(
      hardware_module, dependency, cutpoints, trace, visiting,
    )
  }
  visiting.remove(wire)
}

///|
fn premap_graph_trace(
  hardware_module : PreMapModule,
  target : PreMapSignal,
  cutpoints : Map[Int32, Bool],
) -> PreMapGraphTrace {
  let trace : PreMapGraphTrace = {
    leaves: Map([]),
    cells: Map([]),
    ambiguous_wires: Map([]),
  }
  for bit in target.bits {
    premap_graph_trace_bit(hardware_module, bit, cutpoints, trace, Map([]))
  }
  trace
}

///|
fn premap_graph_cutpoints(hardware_module : PreMapModule) -> Map[Int32, Bool] {
  let cutpoints : Map[Int32, Bool] = Map([])
  for port in hardware_module.ports.values() {
    if port.direction == "input" {
      premap_wire_set_add_signal(cutpoints, port.signal)
    }
  }
  for cell in hardware_module.cells {
    if cell.cell_type == "$dff" {
      match cell.connections.get("Q") {
        Some(signal) => premap_wire_set_add_signal(cutpoints, signal)
        None => ()
      }
    } else if cell.cell_type == "$mem_v2" {
      match cell.connections.get("RD_DATA") {
        Some(signal) => premap_wire_set_add_signal(cutpoints, signal)
        None => ()
      }
    }
  }
  cutpoints
}

///|
fn premap_wire_sets_equal(
  left : Map[Int32, Bool],
  right : Map[Int32, Bool],
) -> Bool {
  left.length() == right.length() && left.keys().all(key => right.contains(key))
}

///|
fn premap_wire_sets_intersect(
  left : Map[Int32, Bool],
  right : Map[Int32, Bool],
) -> Bool {
  left.keys().any(key => right.contains(key))
}

///|
fn premap_wire_set_text(wires : Map[Int32, Bool]) -> String {
  let values = wires.keys().to_array()
  values.sort_by((left, right) => left.compare(right))
  "[\{values.map(value => value.to_string()).join(",")}]"
}

///|
fn premap_check_leaf_contract(
  hardware_module : PreMapModule,
  issues : Array[AsyncFifoPreMapIssue],
  role : String,
  target : PreMapSignal,
  expected_signals : Array[PreMapSignal],
) -> Unit {
  let trace = premap_graph_trace(
    hardware_module,
    target,
    premap_graph_cutpoints(hardware_module),
  )
  let expected = premap_wire_set(expected_signals)
  if !trace.ambiguous_wires.is_empty() {
    premap_issue(
      issues,
      "graph.ambiguous_driver",
      role,
      "single acyclic driver",
      premap_wire_set_text(trace.ambiguous_wires),
    )
  }
  if !premap_wire_sets_equal(trace.leaves, expected) {
    premap_issue(
      issues,
      "graph.cutset",
      role,
      premap_wire_set_text(expected),
      premap_wire_set_text(trace.leaves),
    )
  }
}
