///|
const MEMORY_SCHEMA_VERSION : Int = 3

///|
const DOMAIN_SCHEMA_VERSION : Int = 4

///|
fn encode_name(name : String) -> String {
  let bytes = @utf8.encode(name)
  let builder = StringBuilder(size_hint=bytes.length() * 2)
  for byte in bytes {
    let encoded = byte.to_hex()
    if encoded.length() == 1 {
      builder.write_char('0')
    }
    builder.write_string(encoded)
  }
  builder.to_string()
}

///|
fn encoded_name_compare(left : String, right : String) -> Int {
  let left_name = encode_name(left)
  let right_name = encode_name(right)
  let common = left_name.length().min(right_name.length())
  for index in 0..<common {
    let left_code = left_name[index].to_int()
    let right_code = right_name[index].to_int()
    if left_code != right_code {
      return left_code - right_code
    }
  }
  left_name.length() - right_name.length()
}

///|
fn encode_type(signal_type : @ir.SignalType) -> String {
  match signal_type {
    Clock => "clock"
    Reset => "reset"
    Bits(width) => "bits:\{width.bits()}"
    UInt(width) => "uint:\{width.bits()}"
    SInt(width) => "sint:\{width.bits()}"
  }
}

///|
fn write_node(
  builder : StringBuilder,
  node : @ir.Node,
  schema_version : Int,
) -> Unit {
  builder.write_string(
    "NODE \{node.id().ordinal()} \{encode_type(node.signal_type())} ",
  )
  match node.kind() {
    Input(name) => builder.write_string("input \{encode_name(name)}")
    Constant(value) => builder.write_string("const \{value}")
    Add(lhs, rhs) =>
      builder.write_string("add \{lhs.ordinal()} \{rhs.ordinal()}")
    Sub(lhs, rhs) =>
      builder.write_string("sub \{lhs.ordinal()} \{rhs.ordinal()}")
    MulLow(lhs, rhs) =>
      builder.write_string("mul_low \{lhs.ordinal()} \{rhs.ordinal()}")
    MulFull(lhs, rhs) =>
      builder.write_string("mul_full \{lhs.ordinal()} \{rhs.ordinal()}")
    BitAnd(lhs, rhs) =>
      builder.write_string("and \{lhs.ordinal()} \{rhs.ordinal()}")
    BitOr(lhs, rhs) =>
      builder.write_string("or \{lhs.ordinal()} \{rhs.ordinal()}")
    BitXor(lhs, rhs) =>
      builder.write_string("xor \{lhs.ordinal()} \{rhs.ordinal()}")
    BitNot(operand) => builder.write_string("not \{operand.ordinal()}")
    Equal(lhs, rhs) =>
      builder.write_string("eq \{lhs.ordinal()} \{rhs.ordinal()}")
    LessThan(lhs, rhs) =>
      builder.write_string("lt \{lhs.ordinal()} \{rhs.ordinal()}")
    LessEqual(lhs, rhs) =>
      builder.write_string("le \{lhs.ordinal()} \{rhs.ordinal()}")
    ShiftLeft(value~, amount~) =>
      builder.write_string("shl \{value.ordinal()} \{amount.ordinal()}")
    LogicalShiftRight(value~, amount~) =>
      builder.write_string("lshr \{value.ordinal()} \{amount.ordinal()}")
    ArithmeticShiftRight(value~, amount~) =>
      builder.write_string("ashr \{value.ordinal()} \{amount.ordinal()}")
    Slice(value~, msb~, lsb~) =>
      builder.write_string("slice \{value.ordinal()} \{msb} \{lsb}")
    Concat(most_significant~, least_significant~) =>
      builder.write_string(
        "concat \{most_significant.ordinal()} \{least_significant.ordinal()}",
      )
    ZeroExtend(value) => builder.write_string("zext \{value.ordinal()}")
    SignExtend(value) => builder.write_string("sext \{value.ordinal()}")
    Truncate(value) => builder.write_string("trunc \{value.ordinal()}")
    Reinterpret(value) => builder.write_string("reinterpret \{value.ordinal()}")
    Mux(select~, when_true~, when_false~) =>
      builder.write_string(
        "mux \{select.ordinal()} \{when_true.ordinal()} \{when_false.ordinal()}",
      )
    Register(spec) => {
      let domain_reference = if schema_version >= DOMAIN_SCHEMA_VERSION {
        spec.domain().id().ordinal()
      } else {
        spec.domain().clock().ordinal()
      }
      builder.write_string("reg \{domain_reference} \{spec.next().ordinal()} ")
      if schema_version == 1 {
        match spec.initial() {
          None => builder.write_string("none")
          Some(value) => builder.write_string("some \{value}")
        }
      } else if schema_version < DOMAIN_SCHEMA_VERSION {
        match spec.reset() {
          None => builder.write_string("- - ")
          Some(reset) =>
            builder.write_string(
              "\{reset.signal().ordinal()} \{reset.value()} ",
            )
        }
        match spec.enable() {
          None => builder.write_string("- ")
          Some(enable) => builder.write_string("\{enable.ordinal()} ")
        }
        match spec.initial() {
          None => builder.write_string("-")
          Some(value) => builder.write_string("\{value}")
        }
      } else {
        match spec.reset() {
          None => builder.write_string("- - - - ")
          Some(reset) => {
            let mode = match reset.mode() {
              Synchronous => "synchronous"
              Asynchronous => "asynchronous"
            }
            let polarity = match reset.polarity() {
              ActiveHigh => "active_high"
              ActiveLow => "active_low"
            }
            builder.write_string(
              "\{reset.signal().ordinal()} \{reset.value()} \{mode} \{polarity} ",
            )
          }
        }
        match spec.enable() {
          None => builder.write_string("- ")
          Some(enable) => builder.write_string("\{enable.ordinal()} ")
        }
        match spec.initial() {
          None => builder.write_char('-')
          Some(value) => builder.write_string(value.to_string())
        }
      }
    }
    MemoryRead(memory~, port~) =>
      builder.write_string("memread \{memory.ordinal()} \{port.ordinal()}")
  }
  builder.write_char('\n')
}

///|
fn encode_read_write_policy(policy : @ir.MemoryReadWritePolicy) -> String {
  match policy {
    ReadOld => "read_old"
    ReadNew => "read_new"
    NoChange => "no_change"
    Undefined => "undefined"
    Reject => "reject"
  }
}

///|
fn encode_multi_write_policy(policy : @ir.MemoryMultiWritePolicy) -> String {
  match policy {
    Reject => "reject"
    LowerPortIdWins => "lower_port_id_wins"
  }
}

///|
fn encode_bounds_policy(policy : @ir.MemoryBoundsPolicy) -> String {
  match policy {
    Fault => "fault"
    Undefined => "undefined"
  }
}

///|
fn encode_read_enable_behavior(
  behavior : @ir.MemoryReadEnableBehavior,
) -> String {
  match behavior {
    HoldLast => "hold_last"
    Undefined => "undefined"
  }
}

///|
fn write_optional_node(builder : StringBuilder, node : @ir.NodeId?) -> Unit {
  match node {
    None => builder.write_char('-')
    Some(id) => builder.write_string(id.ordinal().to_string())
  }
}

///|
fn write_memory(
  builder : StringBuilder,
  memory : @ir.MemorySpec,
  schema_version : Int,
) -> Unit {
  if schema_version >= DOMAIN_SCHEMA_VERSION {
    builder.write_string(
      "MEMORY \{memory.id().ordinal()} \{encode_name(memory.name())} \{encode_type(memory.element_type())} \{memory.depth().elements()} \{memory.domain().id().ordinal()} \{encode_read_write_policy(memory.read_write_policy())} \{encode_multi_write_policy(memory.multi_write_policy())} \{encode_bounds_policy(memory.bounds_policy())}\n",
    )
  } else {
    builder.write_string(
      "MEMORY \{memory.id().ordinal()} \{encode_name(memory.name())} \{encode_type(memory.element_type())} \{memory.depth().elements()} \{memory.domain().clock().ordinal()} rising \{encode_read_write_policy(memory.read_write_policy())} \{encode_multi_write_policy(memory.multi_write_policy())} \{encode_bounds_policy(memory.bounds_policy())}\n",
    )
  }
  let reads = memory.read_ports()
  builder.write_string("READS \{reads.length()}\n")
  for port in reads {
    if schema_version >= DOMAIN_SCHEMA_VERSION {
      builder.write_string(
        "READ \{port.id().ordinal()} \{encode_name(port.name())} \{port.domain().id().ordinal()} \{port.address().ordinal()} ",
      )
    } else {
      builder.write_string(
        "READ \{port.id().ordinal()} \{encode_name(port.name())} \{port.domain().clock().ordinal()} rising \{port.address().ordinal()} ",
      )
    }
    write_optional_node(builder, port.enable())
    builder.write_string(
      " one \{encode_read_enable_behavior(port.enable_behavior())} \{port.result().ordinal()}\n",
    )
  }
  let writes = memory.write_ports()
  builder.write_string("WRITES \{writes.length()}\n")
  for port in writes {
    if schema_version >= DOMAIN_SCHEMA_VERSION {
      builder.write_string(
        "WRITE \{port.id().ordinal()} \{encode_name(port.name())} \{port.domain().id().ordinal()} \{port.address().ordinal()} \{port.data().ordinal()} ",
      )
    } else {
      builder.write_string(
        "WRITE \{port.id().ordinal()} \{encode_name(port.name())} \{port.domain().clock().ordinal()} rising \{port.address().ordinal()} \{port.data().ordinal()} ",
      )
    }
    write_optional_node(builder, port.enable())
    match port.mask() {
      All => builder.write_string(" all\n")
      Granular(signal~, granularity~) =>
        builder.write_string(
          " granular \{signal.ordinal()} \{granularity.bits()}\n",
        )
    }
  }
  builder.write_string("ENDMEMORY\n")
}

///|
fn write_module(
  builder : StringBuilder,
  hardware_module : @ir.Module,
  schema_version : Int,
) -> Unit {
  builder.write_string("MODULE \{encode_name(hardware_module.name())}\n")
  if schema_version >= DOMAIN_SCHEMA_VERSION {
    let domains = hardware_module.domains()
    builder.write_string("DOMAINS \{domains.length()}\n")
    for domain in domains {
      let edge = match domain.edge() {
        Rising => "rising"
      }
      builder.write_string(
        "DOMAIN \{domain.id().ordinal()} \{domain.clock().ordinal()} \{edge}\n",
      )
    }
  }
  let nodes = hardware_module.nodes()
  builder.write_string("NODES \{nodes.length()}\n")
  for node in nodes {
    write_node(builder, node, schema_version)
  }
  if schema_version >= MEMORY_SCHEMA_VERSION {
    let memories = hardware_module.memories()
    builder.write_string("MEMORIES \{memories.length()}\n")
    for memory in memories {
      write_memory(builder, memory, schema_version)
    }
  }
  let outputs = hardware_module.outputs().iter().to_array()
  outputs.sort_by((left, right) => {
    encoded_name_compare(left.name(), right.name())
  })
  builder.write_string("OUTPUTS \{outputs.length()}\n")
  for output in outputs {
    builder.write_string(
      "OUTPUT \{encode_name(output.name())} \{encode_type(output.signal_type())} \{output.driver().ordinal()}\n",
    )
  }
  builder.write_string("ENDMODULE\n")
}

///|
/// Serialize a validated design to a selected canonical IR schema version.
/// Modules and output ports are ordered by their UTF-8 hex names; nodes stay
/// in validated ordinal order because their identifiers encode dependencies.
/// The result always ends in exactly one newline.
fn serialize_version(design : @ir.Design, schema_version : Int) -> String {
  let builder = StringBuilder()
  builder.write_string("LUNACHIP-IR \{schema_version}\n")
  builder.write_string("DESIGN \{encode_name(design.name())}\n")
  builder.write_string("TOP \{encode_name(design.top_name())}\n")
  let modules = design.modules().iter().to_array()
  modules.sort_by((left, right) => {
    encoded_name_compare(left.name(), right.name())
  })
  builder.write_string("MODULES \{modules.length()}\n")
  for hardware_module in modules {
    write_module(builder, hardware_module, schema_version)
  }
  builder.write_string("END\n")
  builder.to_string()
}

///|
fn requires_schema_three(design : @ir.Design) -> Bool {
  for hardware_module in design.modules() {
    if !hardware_module.memories().is_empty() {
      return true
    }
    for node in hardware_module.nodes() {
      match node.kind() {
        Reinterpret(source) =>
          match hardware_module.node(source) {
            Some(source_node) if source_node.signal_type() is Reset =>
              return true
            _ => ()
          }
        _ => ()
      }
    }
  }
  false
}

///|
fn requires_schema_four(design : @ir.Design) -> Bool {
  for hardware_module in design.modules() {
    if hardware_module.domains().length() > 1 {
      return true
    }
    for node in hardware_module.nodes() {
      match node.kind() {
        Register(spec) =>
          match spec.reset() {
            Some(reset) =>
              if reset.mode() != Synchronous || reset.polarity() != ActiveHigh {
                return true
              }
            None => ()
          }
        _ => ()
      }
    }
  }
  false
}

///|
/// Serialize legacy designs as schema 2 and designs using memories or the
/// schema-3 reset-to-data conversion as schema 3. This conditional migration
/// preserves every existing schema-2 canonical byte.
pub fn serialize(design : @ir.Design) -> String {
  let schema_version = if requires_schema_four(design) {
    DOMAIN_SCHEMA_VERSION
  } else if requires_schema_three(design) {
    MEMORY_SCHEMA_VERSION
  } else {
    2
  }
  serialize_version(design, schema_version)
}

///|
/// Reconstruct schema 1 only for strict canonical validation of legacy input.
/// The decoder creates no reset or enable controls for schema-1 registers.
fn serialize_schema_one(design : @ir.Design) -> String {
  serialize_version(design, 1)
}

///|
/// Compute FNV-1a-64 over the exact UTF-8 bytes returned by `serialize`.
/// This bootstrap digest is deterministic but deliberately non-cryptographic.
pub fn content_digest(design : @ir.Design) -> ContentDigest64 {
  let canonical = @utf8.encode(serialize(design))
  let mut hash = 14695981039346656037UL
  for byte in canonical {
    hash = (hash ^ byte.to_uint64()) * 1099511628211UL
  }
  ContentDigest64(hash)
}
