///|
fn node_at(
  hardware_module : @ir.Module,
  id : @ir.NodeId,
) -> @ir.Node raise EmitError {
  match hardware_module.node(id) {
    Some(node) => node
    None =>
      raise InvalidNodeReference(
        module_name=hardware_module.name(),
        node=id.ordinal(),
      )
  }
}

///|
fn sv_logic_type(signal_type : @ir.SignalType) -> String {
  let width = signal_type.width().bits()
  let signed = signal_type is SInt(_)
  if width == 1 {
    if signed {
      "logic signed"
    } else {
      "logic"
    }
  } else if signed {
    "logic signed [\{width - 1}:0]"
  } else {
    "logic [\{width - 1}:0]"
  }
}

///|
fn literal(signal_type : @ir.SignalType, value : UInt64) -> String {
  let width = signal_type.width().bits()
  "\{width}'h\{value.to_string(radix=16)}"
}

///|
fn zero_literal(width : Int) -> String {
  "\{width}'h0"
}

///|
fn node_name(id : @ir.NodeId) -> String {
  node_identifier(id.ordinal())
}

///|
fn helper_kind_for_node(
  hardware_module : @ir.Module,
  node : @ir.Node,
) -> HelperSpec? raise EmitError {
  let width = match node.kind() {
    MulFull(left, _) =>
      node_at(hardware_module, left).signal_type().width().bits()
    _ => node.signal_type().width().bits()
  }
  match node.kind() {
    AsyncFifoRead(..) => None
    Add(_, _) => Some({ kind: AddHelper, width })
    Sub(_, _) => Some({ kind: SubHelper, width })
    Equal(left, _) =>
      Some({
        kind: EqualHelper,
        width: node_at(hardware_module, left).signal_type().width().bits(),
      })
    LessThan(left, _) | LessEqual(left, _) => {
      let operand_type = node_at(hardware_module, left).signal_type()
      Some({
        kind: if operand_type is SInt(_) {
          LessSignedHelper
        } else {
          LessUnsignedHelper
        },
        width: operand_type.width().bits(),
      })
    }
    _ => None
  }
}

///|
fn module_helpers(
  hardware_module : @ir.Module,
) -> Array[HelperSpec] raise EmitError {
  let helpers : Array[HelperSpec] = []
  for node in hardware_module.nodes() {
    if helper_kind_for_node(hardware_module, node) is Some(spec) &&
      !helpers.contains(spec) {
      helpers.push(spec)
    }
  }
  helpers
}

///|
fn input_port_lines(hardware_module : @ir.Module) -> Array[String] {
  let lines : Array[String] = []
  for node in hardware_module.nodes() {
    match node.kind() {
      Input(name) =>
        lines.push(
          "input \{sv_logic_type(node.signal_type())} \{input_identifier(node.id().ordinal(), name)}",
        )
      _ => ()
    }
  }
  for index, output in hardware_module.outputs() {
    lines.push(
      "output \{sv_logic_type(output.signal_type())} \{output_identifier(index, output.name())}",
    )
  }
  lines
}

///|
fn emit_port_list(hardware_module : @ir.Module) -> String {
  let ports = input_port_lines(hardware_module)
  if ports.is_empty() {
    return ""
  }
  let out = StringBuilder()
  for index, port in ports {
    let suffix = if index + 1 == ports.length() { "" } else { "," }
    out.write_string("  \{port}\{suffix}\n")
  }
  out.to_string()
}

///|
fn multiply_expression(
  hardware_module : @ir.Module,
  node : @ir.Node,
  left : @ir.NodeId,
  right : @ir.NodeId,
  full : Bool,
) -> String raise EmitError {
  let operand = node_at(hardware_module, left)
  let width = operand.signal_type().width().bits()
  let a = node_name(left)
  let b = node_name(right)
  let zero_test = "((\{a} == \{zero_literal(width)}) || (\{b} == \{zero_literal(width)}))"
  let product = if full {
    if operand.signal_type() is SInt(_) {
      "($signed({{\{width}{\{a}[\{width - 1}]}}, \{a}}) * $signed({{\{width}{\{b}[\{width - 1}]}}, \{b}}))"
    } else {
      "({\{zero_literal(width)}, \{a}} * {\{zero_literal(width)}, \{b}})"
    }
  } else {
    "(\{a} * \{b})"
  }
  "\{zero_test} ? \{zero_literal(node.signal_type().width().bits())} : \{product}"
}

///|
fn combinational_expression(
  hardware_module : @ir.Module,
  node : @ir.Node,
) -> String raise EmitError {
  let result_width = node.signal_type().width().bits()
  match node.kind() {
    AsyncFifoRead(primitive~, leaf~) =>
      "\{async_fifo_lane_identifier(primitive.ordinal(), leaf)}[\{async_fifo_read_address(hardware_module, primitive)}]"
    Constant(value) => literal(node.signal_type(), value)
    Add(left, right) =>
      "\{helper_identifier("add", result_width)}(\{node_name(left)}, \{node_name(right)})"
    Sub(left, right) =>
      "\{helper_identifier("sub", result_width)}(\{node_name(left)}, \{node_name(right)})"
    MulLow(left, right) =>
      multiply_expression(hardware_module, node, left, right, false)
    MulFull(left, right) =>
      multiply_expression(hardware_module, node, left, right, true)
    BitAnd(left, right) => "\{node_name(left)} & \{node_name(right)}"
    BitOr(left, right) => "\{node_name(left)} | \{node_name(right)}"
    BitXor(left, right) => "\{node_name(left)} ^ \{node_name(right)}"
    BitNot(operand) => "~\{node_name(operand)}"
    Equal(left, right) => {
      let width = node_at(hardware_module, left).signal_type().width().bits()
      "\{helper_identifier("eq", width)}(\{node_name(left)}, \{node_name(right)})"
    }
    LessThan(left, right) => {
      let operand_type = node_at(hardware_module, left).signal_type()
      let operation = if operand_type is SInt(_) { "lt_s" } else { "lt_u" }
      "\{helper_identifier(operation, operand_type.width().bits())}(\{node_name(left)}, \{node_name(right)})"
    }
    LessEqual(left, right) => {
      let operand_type = node_at(hardware_module, left).signal_type()
      let operation = if operand_type is SInt(_) { "lt_s" } else { "lt_u" }
      "~\{helper_identifier(operation, operand_type.width().bits())}(\{node_name(right)}, \{node_name(left)})"
    }
    ShiftLeft(value~, amount~) => "\{node_name(value)} << \{node_name(amount)}"
    LogicalShiftRight(value~, amount~) =>
      "$unsigned(\{node_name(value)}) >> \{node_name(amount)}"
    ArithmeticShiftRight(value~, amount~) =>
      "$signed(\{node_name(value)}) >>> \{node_name(amount)}"
    Slice(value~, msb~, lsb~) => "\{node_name(value)}[\{msb}:\{lsb}]"
    Concat(most_significant~, least_significant~) =>
      "{\{node_name(most_significant)}, \{node_name(least_significant)}}"
    ZeroExtend(value) => {
      let source_width = node_at(hardware_module, value)
        .signal_type()
        .width()
        .bits()
      "{\{zero_literal(result_width - source_width)}, \{node_name(value)}}"
    }
    SignExtend(value) => {
      let source_width = node_at(hardware_module, value)
        .signal_type()
        .width()
        .bits()
      "{{\{result_width - source_width}{\{node_name(value)}[\{source_width - 1}]}}, \{node_name(value)}}"
    }
    Truncate(value) => "\{node_name(value)}[\{result_width - 1}:0]"
    Reinterpret(value) => node_name(value)
    Mux(select~, when_true~, when_false~) =>
      "\{node_name(select)} ? \{node_name(when_true)} : \{node_name(when_false)}"
    Input(_) | Register(_) | MemoryRead(..) => ""
  }
}

///|
fn register_next_expression(node : @ir.Node, spec : @ir.RegisterSpec) -> String {
  let next = node_name(spec.next())
  let held = match spec.enable() {
    None => next
    Some(enable) => "\{node_name(enable)} ? \{next} : \{node_name(node.id())}"
  }
  match spec.reset() {
    None => held
    Some(reset) => {
      let asserted = match reset.polarity() {
        ActiveHigh => node_name(reset.signal())
        ActiveLow => "!\{node_name(reset.signal())}"
      }
      "\{asserted} ? \{literal(node.signal_type(), reset.value())} : (\{held})"
    }
  }
}

///|
fn register_sensitivity(spec : @ir.RegisterSpec) -> String {
  let clock = "posedge \{node_name(spec.domain().clock())}"
  match spec.reset() {
    Some(reset) if reset.mode() is Asynchronous => {
      let edge = match reset.polarity() {
        ActiveHigh => "posedge"
        ActiveLow => "negedge"
      }
      "\{clock} or \{edge} \{node_name(reset.signal())}"
    }
    _ => clock
  }
}

///|
fn emit_module_source(
  hardware_module : @ir.Module,
  module_ordinal : Int,
) -> String raise EmitError {
  let out = StringBuilder()
  out.write_string(
    "module \{module_identifier(module_ordinal, hardware_module.name())} (\n",
  )
  out.write_string(emit_port_list(hardware_module))
  out.write_string(");\n\n")
  for node in hardware_module.nodes() {
    out.write_string(
      "  \{sv_logic_type(node.signal_type())} \{node_name(node.id())};\n",
    )
  }
  for memory in hardware_module.memories() {
    out.write_string(memory_declarations(memory))
  }
  for primitive in hardware_module.cdc_primitives() {
    match primitive {
      AsyncFifo(fifo) =>
        out.write_string(async_fifo_declarations(hardware_module, fifo))
      _ => ()
    }
  }
  if !hardware_module.nodes().is_empty() ||
    !hardware_module.memories().is_empty() ||
    !hardware_module.cdc_primitives().is_empty() {
    out.write_string("\n")
  }
  for helper in module_helpers(hardware_module) {
    out.write_string(emit_helper(helper))
  }
  for node in hardware_module.nodes() {
    match node.kind() {
      Input(name) =>
        out.write_string(
          "  assign \{node_name(node.id())} = \{input_identifier(node.id().ordinal(), name)};\n",
        )
      Register(spec) => {
        out.write_string("  always_ff @(\{register_sensitivity(spec)}) begin\n")
        out.write_string(
          "    \{node_name(node.id())} <= \{register_next_expression(node, spec)};\n",
        )
        out.write_string("  end\n")
      }
      MemoryRead(..) => ()
      _ =>
        out.write_string(
          "  assign \{node_name(node.id())} = \{combinational_expression(hardware_module, node)};\n",
        )
    }
  }
  for memory in hardware_module.memories() {
    out.write_string(emit_memory(memory))
  }
  for primitive in hardware_module.cdc_primitives() {
    match primitive {
      AsyncFifo(fifo) =>
        out.write_string(emit_async_fifo(hardware_module, fifo))
      _ => ()
    }
  }
  for index, output in hardware_module.outputs() {
    out.write_string(
      "  assign \{output_identifier(index, output.name())} = \{node_name(output.driver())};\n",
    )
  }
  out.write_string("endmodule\n")
  out.to_string()
}

///|
fn emit_module_artifact(
  hardware_module : @ir.Module,
  module_ordinal : Int,
) -> EmittedModule raise EmitError {
  let identifier = module_identifier(module_ordinal, hardware_module.name())
  let out = StringBuilder()
  out.write_string("`default_nettype none\n")
  out.write_string(
    if module_has_async_fifo(hardware_module) {
      "// LunaChip conservative SystemVerilog-2017 backend v3\n"
    } else if hardware_module.memories().is_empty() {
      "// LunaChip conservative SystemVerilog-2017 backend v1\n"
    } else {
      "// LunaChip conservative SystemVerilog-2017 backend v2\n"
    },
  )
  out.write_string(
    "// Uninitialized registers intentionally have no initializer.\n\n",
  )
  if !hardware_module.memories().is_empty() {
    out.write_string(
      "// Memory cells and read results intentionally have no initializer.\n\n",
    )
  }
  if module_has_async_fifo(hardware_module) {
    out.write_string(
      "// FIFO lane cells intentionally have no initializer.\n\n",
    )
  }
  out.write_string(emit_module_source(hardware_module, module_ordinal))
  out.write_string("\n`default_nettype wire\n")
  {
    module_ordinal,
    identifier,
    filename: "\{identifier}.sv",
    source: out.to_string(),
  }
}

///|
fn append_mapping_checked(
  mappings : Array[NameMapping],
  identifiers : Array[String],
  mapping : NameMapping,
  module_name : String,
) -> Unit raise EmitError {
  if identifiers.contains(mapping.identifier) {
    raise DuplicateEmittedIdentifier(
      module_name~,
      identifier=mapping.identifier,
    )
  }
  identifiers.push(mapping.identifier)
  mappings.push(mapping)
}

///|
fn build_manifest(
  design : @ir.Design,
  top_module_ordinal : Int,
) -> NameManifest raise EmitError {
  let mappings : Array[NameMapping] = []
  for module_ordinal, hardware_module in design.modules() {
    let identifiers : Array[String] = []
    append_mapping_checked(
      mappings,
      identifiers,
      {
        kind: Module,
        module_ordinal,
        local_ordinal: -1,
        source_name: hardware_module.name(),
        identifier: module_identifier(module_ordinal, hardware_module.name()),
      },
      hardware_module.name(),
    )
    for node in hardware_module.nodes() {
      let source_name = match node.kind() {
        Input(name) => name
        _ => ""
      }
      append_mapping_checked(
        mappings,
        identifiers,
        {
          kind: Node,
          module_ordinal,
          local_ordinal: node.id().ordinal(),
          source_name,
          identifier: node_name(node.id()),
        },
        hardware_module.name(),
      )
      match node.kind() {
        Input(name) =>
          append_mapping_checked(
            mappings,
            identifiers,
            {
              kind: InputPort,
              module_ordinal,
              local_ordinal: node.id().ordinal(),
              source_name: name,
              identifier: input_identifier(node.id().ordinal(), name),
            },
            hardware_module.name(),
          )
        _ => ()
      }
    }
    for output_ordinal, output in hardware_module.outputs() {
      append_mapping_checked(
        mappings,
        identifiers,
        {
          kind: OutputPort,
          module_ordinal,
          local_ordinal: output_ordinal,
          source_name: output.name(),
          identifier: output_identifier(output_ordinal, output.name()),
        },
        hardware_module.name(),
      )
    }
    for memory in hardware_module.memories() {
      append_mapping_checked(
        mappings,
        identifiers,
        {
          kind: Memory,
          module_ordinal,
          local_ordinal: memory.id().ordinal(),
          source_name: memory.name(),
          identifier: memory_identifier(memory.id().ordinal(), memory.name()),
        },
        hardware_module.name(),
      )
    }
    for primitive in hardware_module.cdc_primitives() {
      match primitive {
        AsyncFifo(fifo) =>
          for leaf, raw_read in fifo.raw_reads() {
            append_mapping_checked(
              mappings,
              identifiers,
              {
                kind: AsyncFifoLane,
                module_ordinal,
                local_ordinal: raw_read.ordinal(),
                source_name: fifo.name(),
                identifier: async_fifo_lane_identifier(
                  fifo.id().ordinal(),
                  leaf,
                ),
              },
              hardware_module.name(),
            )
          }
        _ => ()
      }
    }
  }
  {
    top_module_ordinal,
    mappings: ReadOnlyArray::from_array(mappings),
    initialization_policy: ImplicitFourStateXRejectExplicitInitial,
  }
}

///|
/// Emit every module in canonical design order as conservative synthesizable
/// SystemVerilog-2017. The input is already validated canonical IR; this pass
/// adds backend capability checks and never repairs or guesses semantics.
pub fn emit_design(design : @ir.Design) -> EmittedDesign raise EmitError {
  @cdc.validate_design(design) catch {
    error => raise CdcRejected(error)
  }
  let mut top_module_ordinal = -1
  for module_ordinal, hardware_module in design.modules() {
    if hardware_module.name() == design.top_name() {
      top_module_ordinal = module_ordinal
    }
    validate_module_capabilities(hardware_module)
  }
  if top_module_ordinal < 0 {
    raise MissingTopModule(design.top_name())
  }
  let out = StringBuilder()
  let modules : Array[EmittedModule] = []
  let has_memory = design
    .modules()
    .any(hardware_module => !hardware_module.memories().is_empty())
  let has_fifo = design.modules().any(module_has_async_fifo)
  out.write_string("`default_nettype none\n")
  out.write_string(
    if has_fifo {
      "// LunaChip conservative SystemVerilog-2017 backend v3\n"
    } else if has_memory {
      "// LunaChip conservative SystemVerilog-2017 backend v2\n"
    } else {
      "// LunaChip conservative SystemVerilog-2017 backend v1\n"
    },
  )
  out.write_string(
    "// Uninitialized registers intentionally have no initializer.\n\n",
  )
  if has_memory {
    out.write_string(
      "// Memory cells and read results intentionally have no initializer.\n\n",
    )
  }
  if has_fifo {
    out.write_string(
      "// FIFO lane cells intentionally have no initializer.\n\n",
    )
  }
  for module_ordinal, hardware_module in design.modules() {
    if module_ordinal > 0 {
      out.write_string("\n")
    }
    out.write_string(emit_module_source(hardware_module, module_ordinal))
    modules.push(emit_module_artifact(hardware_module, module_ordinal))
  }
  out.write_string("\n`default_nettype wire\n")
  {
    source: out.to_string(),
    modules: ReadOnlyArray::from_array(modules),
    manifest: build_manifest(design, top_module_ordinal),
  }
}
