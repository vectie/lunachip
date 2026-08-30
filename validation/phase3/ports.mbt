///|
fn mapping_identifier(
  manifest : @systemverilog.NameManifest,
  kind : @systemverilog.SymbolKind,
  ordinal : Int,
) -> String raise Phase3Error {
  for mapping in manifest.mappings() {
    if mapping.module_ordinal() == manifest.top_module_ordinal() &&
      mapping.kind() == kind &&
      mapping.local_ordinal() == ordinal {
      return mapping.identifier()
    }
  }
  let kind_text = match kind {
    Module => "module"
    Node => "node"
    InputPort => "input"
    OutputPort => "output"
    Memory => "memory"
    AsyncFifoLane => "async-fifo-lane"
  }
  raise MissingPortMapping(kind=kind_text, ordinal~)
}

///|
fn collect_ports(
  hardware_module : @ir.Module,
  manifest : @systemverilog.NameManifest,
) -> ReadOnlyArray[HarnessPort] raise Phase3Error {
  let ports : Array[HarnessPort] = []
  for node in hardware_module.nodes() {
    match node.kind() {
      Input(name) => {
        let width = node.signal_type().width().bits()
        if width > 64 {
          raise UnsupportedPortWidth(name~, width~)
        }
        ports.push({
          source_name: name,
          emitted_name: mapping_identifier(
            manifest,
            InputPort,
            node.id().ordinal(),
          ),
          direction: Input,
          width,
          signal_type: node.signal_type(),
        })
      }
      _ => ()
    }
  }
  for ordinal, output in hardware_module.outputs() {
    let width = output.signal_type().width().bits()
    if width > 64 {
      raise UnsupportedPortWidth(name=output.name(), width~)
    }
    ports.push({
      source_name: output.name(),
      emitted_name: mapping_identifier(manifest, OutputPort, ordinal),
      direction: Output,
      width,
      signal_type: output.signal_type(),
    })
  }
  ports.sort_by((left, right) => {
    let left_rank = if left.signal_type.is_clock() {
      0
    } else if left.direction == Input {
      1
    } else {
      2
    }
    let right_rank = if right.signal_type.is_clock() {
      0
    } else if right.direction == Input {
      1
    } else {
      2
    }
    let rank_order = left_rank.compare(right_rank)
    if rank_order != 0 {
      return rank_order
    }
    compare_port_source(left, right)
  })
  ReadOnlyArray::from_array(ports)
}

///|
fn compare_port_source(left : HarnessPort, right : HarnessPort) -> Int {
  let left_bytes = @utf8.encode(left.source_name)
  let right_bytes = @utf8.encode(right.source_name)
  let shared = if left_bytes.length() < right_bytes.length() {
    left_bytes.length()
  } else {
    right_bytes.length()
  }
  for index in 0..<shared {
    let order = left_bytes[index].compare(right_bytes[index])
    if order != 0 {
      return order
    }
  }
  left_bytes.length().compare(right_bytes.length())
}

///|
fn clock_port(
  ports : ReadOnlyArray[HarnessPort],
) -> HarnessPort raise Phase3Error {
  let mut found : HarnessPort? = None
  for port in ports {
    if port.direction == Input && port.signal_type.is_clock() {
      if found is Some(_) {
        raise MultipleClockPorts
      }
      found = Some(port)
    }
  }
  match found {
    Some(port) => port
    None => raise MissingClockPort
  }
}

///|
fn reset_port(
  ports : ReadOnlyArray[HarnessPort],
) -> HarnessPort raise Phase3Error {
  let mut found : HarnessPort? = None
  for port in ports {
    if port.direction == Input && port.signal_type is Reset {
      if found is Some(_) {
        raise MultipleResetPorts
      }
      found = Some(port)
    }
  }
  match found {
    Some(port) => port
    None => raise MissingResetPort
  }
}

///|
fn output_ports(ports : ReadOnlyArray[HarnessPort]) -> Array[HarnessPort] {
  let outputs : Array[HarnessPort] = []
  for port in ports {
    if port.direction == Output {
      outputs.push(port)
    }
  }
  outputs.sort_by(compare_port_source)
  outputs
}
