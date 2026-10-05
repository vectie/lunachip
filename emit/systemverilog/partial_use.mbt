///|
fn partial_use_range(
  hardware_module : @ir.Module,
  ranges : Array[(Int, Int)?],
  id : @ir.NodeId,
  lower : Int,
  upper : Int,
) -> Unit raise EmitError {
  // Validate the reference before indexing the ordinal-aligned node table.
  let _ = node_at(hardware_module, id)
  let ordinal = id.ordinal()
  ranges[ordinal] = match ranges[ordinal] {
    None => Some((lower, upper))
    Some((old_lower, old_upper)) =>
      Some(
        (
          if old_lower < lower {
            old_lower
          } else {
            lower
          },
          if old_upper > upper {
            old_upper
          } else {
            upper
          },
        ),
      )
  }
}

///|
fn partial_use_full(
  hardware_module : @ir.Module,
  full : Array[Bool],
  id : @ir.NodeId,
) -> Unit raise EmitError {
  let _ = node_at(hardware_module, id)
  full[id.ordinal()] = true
}

///|
fn module_partial_use_ranges(
  hardware_module : @ir.Module,
) -> Array[(Int, Int)?] raise EmitError {
  let ranges : Array[(Int, Int)?] = Array::make(
    hardware_module.nodes().length(),
    None,
  )
  let full = Array::make(hardware_module.nodes().length(), false)
  // Only explicit bit-selection operations establish a partial consumer.
  // Every other dependency is deliberately treated as a full-width use.
  for node in hardware_module.nodes() {
    match node.kind() {
      Slice(value~, msb~, lsb~) =>
        partial_use_range(hardware_module, ranges, value, lsb, msb)
      Truncate(value) =>
        partial_use_range(
          hardware_module,
          ranges,
          value,
          0,
          node.signal_type().width().bits() - 1,
        )
      _ =>
        for
          dependency in reachability_dependencies(hardware_module, node.kind()) {
          partial_use_full(hardware_module, full, dependency)
        }
    }
    // The enabled-register lowering introduces an implicit full-width hold.
    if node.kind() is Register(spec) && spec.enable() is Some(_) {
      partial_use_full(hardware_module, full, node.id())
    }
  }
  for output in hardware_module.outputs() {
    partial_use_full(hardware_module, full, output.driver())
  }
  for memory in hardware_module.memories() {
    for dependency in memory_dependencies(memory) {
      partial_use_full(hardware_module, full, dependency)
    }
    // Read-result hold/collision lowering may refer to the result itself.
    // Keep every memory result conservative, regardless of its policy.
    for read in memory.read_ports() {
      partial_use_full(hardware_module, full, read.result())
    }
  }
  for primitive in hardware_module.cdc_primitives() {
    match primitive {
      AsyncFifo(fifo) =>
        for dependency in async_fifo_dependencies(hardware_module, fifo) {
          partial_use_full(hardware_module, full, dependency)
        }
      _ => ()
    }
  }
  let result : Array[(Int, Int)?] = []
  for node in hardware_module.nodes() {
    let ordinal = node.id().ordinal()
    let width = node.signal_type().width().bits()
    result.push(
      match ranges[ordinal] {
        Some((lower, upper)) if !full[ordinal] &&
          (lower > 0 || upper < width - 1) => Some((lower, upper))
        _ => None
      },
    )
  }
  result
}

///|
fn partial_use_declaration(node : @ir.Node, range : (Int, Int)?) -> String {
  let declaration = "  \{sv_logic_type(node.signal_type())} \{node_name(node.id())};\n"
  match range {
    None => declaration
    Some((lower, upper)) =>
      "  // Explicit Slice/Truncate consumers use \{node_name(node.id())}[\{upper}:\{lower}] only.\n  /* verilator lint_off UNUSEDSIGNAL */\n\{declaration}  /* verilator lint_on UNUSEDSIGNAL */\n"
  }
}
