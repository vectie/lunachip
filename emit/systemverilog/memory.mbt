///|
fn memory_at(
  hardware_module : @ir.Module,
  id : @ir.MemoryId,
) -> @ir.MemorySpec raise EmitError {
  match hardware_module.memories().get(id.ordinal()) {
    Some(memory) => memory
    None =>
      raise InvalidMemoryReference(
        module_name=hardware_module.name(),
        memory=id.ordinal(),
      )
  }
}

///|
fn memory_declarations(memory : @ir.MemorySpec) -> String {
  let out = StringBuilder()
  let element = sv_logic_type(memory.element_type())
  let last = memory.depth().elements() - 1
  out.write_string(
    "  \{element} \{memory_identifier(memory.id().ordinal(), memory.name())} [0:\{last}];\n",
  )
  let known_function = memory_address_known_identifier(memory.id().ordinal())
  let address_width = memory.depth().address_width().bits()
  out.write_string(
    "  function automatic logic \{known_function}(input logic [\{address_width - 1}:0] lc_address);\n",
  )
  out.write_string("`ifdef FORMAL\n")
  out.write_string("    \{known_function} = 1'b1;\n")
  out.write_string("`else\n")
  out.write_string("    \{known_function} = ((^lc_address) !== 1'bx);\n")
  out.write_string("`endif\n")
  out.write_string("  endfunction\n")
  out.to_string()
}

///|
fn port_control(enable : @ir.NodeId?) -> String {
  match enable {
    Some(id) => node_name(id)
    None => "1'b1"
  }
}

///|
fn memory_range_expression(
  memory : @ir.MemorySpec,
  address : @ir.NodeId,
) -> String {
  let depth = memory.depth().elements()
  let width = memory.depth().address_width().bits()
  let known = "\{memory_address_known_identifier(memory.id().ordinal())}(\{node_name(address)})"
  if depth == 1 << width {
    known
  } else {
    "(\{known} && ($unsigned(\{node_name(address)}) < \{width}'d\{depth}))"
  }
}

///|
fn memory_unknown_literal(width : Int32) -> String {
  "\{width}'bx"
}

///|
fn masked_write_expression(
  memory : @ir.MemorySpec,
  port : @ir.MemoryWritePort,
  base : String,
) -> String {
  match port.mask() {
    All => node_name(port.data())
    Granular(signal~, granularity~) => {
      let granule_width = granularity.bits()
      let count = memory.element_type().width().bits() / granule_width
      let parts : Array[String] = []
      for offset in 0..<count {
        let granule = count - offset - 1
        let lsb = granule * granule_width
        let msb = lsb + granule_width - 1
        parts.push(
          "\{node_name(signal)}[\{granule}] ? \{node_name(port.data())}[\{msb}:\{lsb}] : \{base}[\{msb}:\{lsb}]",
        )
      }
      "{\{parts.join(", ")}}"
    }
  }
}

///|
fn resolved_write_expression(
  memory : @ir.MemorySpec,
  target_address : @ir.NodeId,
) -> String {
  let cells = memory_identifier(memory.id().ordinal(), memory.name())
  let target = node_name(target_address)
  let width = memory.element_type().width().bits()
  let resolved : Array[String] = []
  for bit in 0..<width {
    resolved.push("\{cells}[\{target}][\{bit}]")
  }
  let ports = memory.write_ports()
  // Resolve only the addressed word. Low-priority writers are wrapped first,
  // so lower port IDs become the final per-granule writers.
  for offset in 0..<ports.length() {
    let port = ports[ports.length() - offset - 1]
    let same_address = "((\{node_name(port.address())} == \{target}) === 1'b1)"
    let selected = "(\{memory_range_expression(memory, port.address())} && \{port_control(port.enable())} && \{same_address})"
    for bit in 0..<width {
      let old_bit = resolved[bit]
      let data_bit = "\{node_name(port.data())}[\{bit}]"
      let candidate = match port.mask() {
        All => data_bit
        Granular(signal~, granularity~) => {
          let granule = bit / granularity.bits()
          "\{node_name(signal)}[\{granule}] ? \{data_bit} : (\{old_bit})"
        }
      }
      resolved[bit] = "\{selected} ? (\{candidate}) : (\{old_bit})"
    }
  }
  let ordered : Array[String] = []
  for offset in 0..<width {
    ordered.push(resolved[width - offset - 1])
  }
  "{\{ordered.join(", ")}}"
}

///|
fn single_write_read_new_expression(
  memory : @ir.MemorySpec,
  read : @ir.MemoryReadPort,
  write : @ir.MemoryWritePort,
  old_value : String,
) -> String {
  let same_address = "((\{node_name(write.address())} == \{node_name(read.address())}) === 1'b1)"
  let selected = "(\{port_control(write.enable())} & \{same_address})"
  let candidate = masked_write_expression(memory, write, old_value)
  "\{selected} ? (\{candidate}) : \{old_value}"
}

///|
fn collision_expression(
  memory : @ir.MemorySpec,
  read : @ir.MemoryReadPort,
) -> String {
  let terms : Array[String] = []
  for write in memory.write_ports() {
    terms.push(
      "(\{port_control(write.enable())} & ((\{node_name(write.address())} == \{node_name(read.address())}) === 1'b1))",
    )
  }
  if terms.is_empty() {
    "1'b0"
  } else {
    terms.join(" | ")
  }
}

///|
fn memory_read_active_expression(
  memory : @ir.MemorySpec,
  read : @ir.MemoryReadPort,
) -> String {
  let address = node_name(read.address())
  let cells = memory_identifier(memory.id().ordinal(), memory.name())
  let old_value = "\{cells}[\{address}]"
  let active = match memory.read_write_policy() {
    ReadOld | Reject => old_value
    ReadNew =>
      match memory.write_ports().length() {
        0 => old_value
        1 =>
          single_write_read_new_expression(
            memory,
            read,
            memory.write_ports()[0],
            old_value,
          )
        _ => resolved_write_expression(memory, read.address())
      }
    NoChange =>
      "(\{collision_expression(memory, read)}) ? \{node_name(read.result())} : \{old_value}"
    Undefined =>
      "(\{collision_expression(memory, read)}) ? \{memory_unknown_literal(memory.element_type().width().bits())} : \{old_value}"
  }
  if memory_range_expression(memory, read.address()) == "1'b1" {
    active
  } else {
    "(\{memory_range_expression(memory, read.address())}) ? (\{active}) : \{memory_unknown_literal(memory.element_type().width().bits())}"
  }
}

///|
fn emit_single_write_commit(
  out : StringBuilder,
  memory : @ir.MemorySpec,
  write : @ir.MemoryWritePort,
) -> Unit {
  let cells = memory_identifier(memory.id().ordinal(), memory.name())
  let address = node_name(write.address())
  let base = "\{cells}[\{address}]"
  let candidate = masked_write_expression(memory, write, base)
  out.write_string(
    "    if (\{memory_range_expression(memory, write.address())}) \{base} <= \{port_control(write.enable())} ? (\{candidate}) : \{base};\n",
  )
}

///|
fn emit_resolved_write_commits(
  out : StringBuilder,
  memory : @ir.MemorySpec,
) -> Unit {
  let cells = memory_identifier(memory.id().ordinal(), memory.name())
  // Low-priority assignments appear first. Colliding assignments calculate
  // the same resolved value, while the final textual assignment belongs to
  // the highest-priority port.
  let ports = memory.write_ports()
  for offset in 0..<ports.length() {
    let port = ports[ports.length() - offset - 1]
    let address = node_name(port.address())
    out.write_string(
      "    if (\{memory_range_expression(memory, port.address())}) \{cells}[\{address}] <= \{resolved_write_expression(memory, port.address())};\n",
    )
  }
}

///|
fn emit_bounds_assertion(
  out : StringBuilder,
  memory : @ir.MemorySpec,
  role : String,
  port : Int32,
  address : @ir.NodeId,
  enable : @ir.NodeId?,
) -> Unit {
  if memory.bounds_policy() is Fault &&
    memory_range_expression(memory, address) != "1'b1" {
    out.write_string("    if (\{port_control(enable)} !== 1'b0) begin\n")
    out.write_string(
      "      lc_mem\{memory.id().ordinal()}_\{role}\{port}_bounds: assert (\{memory_range_expression(memory, address)} === 1'b1);\n",
    )
    out.write_string("    end\n")
  }
}

///|
fn emit_rejected_write_collision_assertions(
  out : StringBuilder,
  memory : @ir.MemorySpec,
) -> Unit {
  if memory.multi_write_policy() is Reject {
    let ports = memory.write_ports()
    for first in 0..<ports.length() {
      for second in (first + 1)..<ports.length() {
        let lhs = ports[first]
        let rhs = ports[second]
        out.write_string(
          "    if ((\{port_control(lhs.enable())} !== 1'b0) && (\{port_control(rhs.enable())} !== 1'b0) && ((\{node_name(lhs.address())} == \{node_name(rhs.address())}) === 1'b1)) begin\n",
        )
        out.write_string(
          "      lc_mem\{memory.id().ordinal()}_write\{lhs.id().ordinal()}_write\{rhs.id().ordinal()}_collision: assert (1'b0);\n",
        )
        out.write_string("    end\n")
      }
    }
  }
}

///|
fn emit_memory_commit(memory : @ir.MemorySpec) -> String {
  let out = StringBuilder()
  out.write_string(
    "  always_ff @(posedge \{node_name(memory.domain().clock())}) begin\n",
  )
  for read in memory.read_ports() {
    let disabled = match read.enable_behavior() {
      HoldLast => node_name(read.result())
      Undefined => memory_unknown_literal(memory.element_type().width().bits())
    }
    out.write_string(
      "    \{node_name(read.result())} <= \{port_control(read.enable())} ? (\{memory_read_active_expression(memory, read)}) : \{disabled};\n",
    )
    emit_bounds_assertion(
      out,
      memory,
      "read",
      read.id().ordinal(),
      read.address(),
      read.enable(),
    )
  }
  for write in memory.write_ports() {
    emit_bounds_assertion(
      out,
      memory,
      "write",
      write.id().ordinal(),
      write.address(),
      write.enable(),
    )
  }
  emit_rejected_write_collision_assertions(out, memory)
  match memory.write_ports().length() {
    0 => ()
    1 => emit_single_write_commit(out, memory, memory.write_ports()[0])
    _ => emit_resolved_write_commits(out, memory)
  }
  out.write_string("  end\n")
  out.to_string()
}

///|
fn emit_memory(memory : @ir.MemorySpec) -> String {
  emit_memory_commit(memory)
}

///|
fn memory_dependencies(memory : @ir.MemorySpec) -> Array[@ir.NodeId] {
  let dependencies : Array[@ir.NodeId] = [memory.domain().clock()]
  for read in memory.read_ports() {
    dependencies.push(read.address())
    if read.enable() is Some(enable) {
      dependencies.push(enable)
    }
  }
  for write in memory.write_ports() {
    dependencies.push(write.address())
    dependencies.push(write.data())
    if write.enable() is Some(enable) {
      dependencies.push(enable)
    }
    match write.mask() {
      All => ()
      Granular(signal~, ..) => dependencies.push(signal)
    }
  }
  dependencies
}
