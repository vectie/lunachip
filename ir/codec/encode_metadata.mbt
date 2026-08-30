///|
fn encode_parameter_value(
  builder : StringBuilder,
  value : @ir.ParameterValue,
) -> Unit {
  match value {
    Boolean(value) =>
      builder.write_string(if value { "boolean true" } else { "boolean false" })
    Signed(value) => builder.write_string("signed \{value}")
    Unsigned(value) => builder.write_string("unsigned \{value}")
    Text(value) => {
      builder.write_string("text ")
      if value.is_empty() {
        builder.write_char('-')
      } else {
        builder.write_string(encode_name(value))
      }
    }
    SignalTypeValue(value) =>
      builder.write_string("signal_type \{encode_type(value)}")
  }
}

///|
fn write_parameters(
  builder : StringBuilder,
  hardware_module : @ir.Module,
) -> Unit {
  let parameters = hardware_module.parameters()
  builder.write_string("PARAMETERS \{parameters.length()}\n")
  for parameter in parameters {
    builder.write_string("PARAMETER \{encode_name(parameter.name())} ")
    encode_parameter_value(builder, parameter.value())
    builder.write_char('\n')
  }
}

///|
fn write_input_timings(
  builder : StringBuilder,
  hardware_module : @ir.Module,
) -> Unit {
  let timings = hardware_module.input_timings()
  builder.write_string("INPUT_TIMINGS \{timings.length()}\n")
  for binding in timings {
    builder.write_string("INPUT_TIMING \{binding.input().ordinal()} ")
    match binding.timing() {
      Asynchronous => builder.write_string("asynchronous")
      SampledIn(domain) =>
        builder.write_string("sampled_in \{domain.ordinal()}")
    }
    builder.write_char('\n')
  }
}

///|
fn write_output_timings(
  builder : StringBuilder,
  hardware_module : @ir.Module,
) -> Unit {
  let timings = hardware_module.output_timings()
  builder.write_string("OUTPUT_TIMINGS \{timings.length()}\n")
  for binding in timings {
    builder.write_string("OUTPUT_TIMING \{encode_name(binding.output())} ")
    match binding.timing() {
      Static => builder.write_string("static")
      Asynchronous => builder.write_string("asynchronous")
      ProducedIn(domain) =>
        builder.write_string("produced_in \{domain.ordinal()}")
    }
    builder.write_char('\n')
  }
}

///|
fn write_aggregate_shape(
  builder : StringBuilder,
  shape : @aggregate.Aggregate[@ir.SignalType],
) -> Unit {
  match shape {
    Leaf(signal_type) =>
      builder.write_string("SHAPE leaf \{encode_type(signal_type)}\n")
    Vector(items) => {
      builder.write_string("SHAPE vector \{items.length()}\n")
      let exemplar = items.at(0) catch {
        _ => abort("validated aggregate vector unexpectedly empty")
      }
      write_aggregate_shape(builder, exemplar)
    }
    Record(fields) => {
      builder.write_string("SHAPE record \{fields.length()}\n")
      for field in fields.fields() {
        builder.write_string("FIELD \{encode_name(field.name())}\n")
        write_aggregate_shape(builder, field.value())
      }
    }
  }
}

///|
fn encode_binding_kind(kind : @ir.AggregateBindingKind) -> String {
  match kind {
    InputPort => "input"
    OutputPort => "output"
    Internal => "internal"
  }
}

///|
fn write_aggregate_binding(
  builder : StringBuilder,
  binding : @ir.AggregateBinding,
) -> Unit {
  builder.write_string(
    "AGGREGATE \{binding.id().ordinal()} \{encode_binding_kind(binding.kind())} \{encode_name(binding.root())}\n",
  )
  write_aggregate_shape(builder, binding.shape())
  let leaves = binding.leaves()
  builder.write_string("ENDPOINTS \{leaves.length()}\n")
  for leaf in leaves {
    builder.write_string("ENDPOINT \{leaf.ordinal()} ")
    match leaf.target() {
      Node(node) => builder.write_string("node \{node.ordinal()}")
      Output(output) => builder.write_string("output \{encode_name(output)}")
    }
    builder.write_char('\n')
  }
  builder.write_string("ENDAGGREGATE\n")
}

///|
fn write_aggregate_bindings(
  builder : StringBuilder,
  hardware_module : @ir.Module,
) -> Unit {
  let bindings = hardware_module.aggregate_bindings()
  builder.write_string("AGGREGATES \{bindings.length()}\n")
  for binding in bindings {
    write_aggregate_binding(builder, binding)
  }
}

///|
fn write_bit_synchronizer(
  builder : StringBuilder,
  spec : @ir.BitSynchronizerPrimitive,
) -> Unit {
  builder.write_string(
    "PRIMITIVE \{spec.id().ordinal()} bit_synchronizer \{encode_name(spec.name())}\n",
  )
  match spec.source_domain() {
    AsynchronousSource =>
      builder.write_string("SOURCE asynchronous \{spec.source().ordinal()}\n")
    SourceDomain(domain) =>
      builder.write_string(
        "SOURCE domain \{domain.ordinal()} \{spec.source().ordinal()}\n",
      )
  }
  builder.write_string("DESTINATION \{spec.destination().ordinal()}\n")
  match spec.reset() {
    None => builder.write_string("RESET none\n")
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
        "RESET \{mode} \{polarity} \{reset.signal().ordinal()} \{reset.value()}\n",
      )
    }
  }
  builder.write_string("STAGES \{spec.stages().length()}\n")
  for index, stage in spec.stages() {
    builder.write_string("STAGE \{index} \{stage.ordinal()}\n")
  }
  builder.write_string("ENDPRIMITIVE\n")
}

///|
fn write_required_reset(
  builder : StringBuilder,
  keyword : String,
  reset : @ir.ResetSpec,
) -> Unit {
  let mode = match reset.mode() {
    Synchronous => "synchronous"
    Asynchronous => "asynchronous"
  }
  let polarity = match reset.polarity() {
    ActiveHigh => "active_high"
    ActiveLow => "active_low"
  }
  builder.write_string(
    "\{keyword} \{mode} \{polarity} \{reset.signal().ordinal()} \{reset.value()}\n",
  )
}

///|
fn write_toggle_handshake(
  builder : StringBuilder,
  spec : @ir.ToggleHandshakePrimitive,
) -> Unit {
  builder.write_string(
    "PRIMITIVE \{spec.id().ordinal()} toggle_handshake \{encode_name(spec.name())}\n",
  )
  builder.write_string("SOURCE_DOMAIN \{spec.source_domain().ordinal()}\n")
  builder.write_string(
    "DESTINATION_DOMAIN \{spec.destination_domain().ordinal()}\n",
  )
  write_required_reset(builder, "SOURCE_RESET", spec.source_reset())
  write_required_reset(builder, "DESTINATION_RESET", spec.destination_reset())
  write_aggregate_shape(builder, spec.payload_shape())
  builder.write_string("SOURCE_VALID \{spec.source_valid().ordinal()}\n")
  builder.write_string("SOURCE_READY \{spec.source_ready().ordinal()}\n")
  builder.write_string("SOURCE_ACCEPT \{spec.source_accept().ordinal()}\n")
  builder.write_string("SOURCE_PAYLOADS \{spec.source_payload().length()}\n")
  for index, source in spec.source_payload() {
    builder.write_string(
      "SOURCE_PAYLOAD \{index} \{source.ordinal()} \{spec.held_payload()[index].ordinal()}\n",
    )
  }
  builder.write_string("REQUEST_TOGGLE \{spec.request_toggle().ordinal()}\n")
  builder.write_string("REQUEST_STAGES \{spec.request_stages().length()}\n")
  for index, stage in spec.request_stages() {
    builder.write_string("REQUEST_STAGE \{index} \{stage.ordinal()}\n")
  }
  builder.write_string("REQUEST_CHANGED \{spec.request_changed().ordinal()}\n")
  builder.write_string(
    "DESTINATION_READY \{spec.destination_ready().ordinal()}\n",
  )
  builder.write_string(
    "DESTINATION_VALID \{spec.destination_valid().ordinal()}\n",
  )
  builder.write_string(
    "DESTINATION_AVAILABLE \{spec.destination_available().ordinal()}\n",
  )
  builder.write_string(
    "DESTINATION_CAPTURE \{spec.destination_capture().ordinal()}\n",
  )
  builder.write_string(
    "DESTINATION_CONSUME \{spec.destination_consume().ordinal()}\n",
  )
  builder.write_string(
    "DESTINATION_PAYLOADS \{spec.destination_payload().length()}\n",
  )
  for index, payload in spec.destination_payload() {
    builder.write_string("DESTINATION_PAYLOAD \{index} \{payload.ordinal()}\n")
  }
  builder.write_string(
    "ACKNOWLEDGE_TOGGLE \{spec.acknowledge_toggle().ordinal()}\n",
  )
  builder.write_string(
    "ACKNOWLEDGE_STAGES \{spec.acknowledge_stages().length()}\n",
  )
  for index, stage in spec.acknowledge_stages() {
    builder.write_string("ACKNOWLEDGE_STAGE \{index} \{stage.ordinal()}\n")
  }
  builder.write_string("ENDPRIMITIVE\n")
}

///|
fn write_async_fifo(
  builder : StringBuilder,
  spec : @ir.AsyncFifoPrimitive,
) -> Unit {
  builder.write_string(
    "PRIMITIVE \{spec.id().ordinal()} async_fifo \{encode_name(spec.name())}\n",
  )
  builder.write_string("SOURCE_DOMAIN \{spec.source_domain().ordinal()}\n")
  builder.write_string(
    "DESTINATION_DOMAIN \{spec.destination_domain().ordinal()}\n",
  )
  builder.write_string("DEPTH \{spec.depth()}\n")
  builder.write_string("POINTER_WIDTH \{spec.pointer_width()}\n")
  builder.write_string("SYNCHRONIZER_STAGES \{spec.synchronizer_stages()}\n")
  match spec.reset_policy() {
    CoordinatedIdle => builder.write_string("RESET_POLICY coordinated_idle\n")
  }
  write_required_reset(builder, "SOURCE_RESET", spec.source_reset())
  write_required_reset(builder, "DESTINATION_RESET", spec.destination_reset())
  write_aggregate_shape(builder, spec.payload_shape())
  builder.write_string("SOURCE_VALID \{spec.source_valid().ordinal()}\n")
  builder.write_string("SOURCE_READY \{spec.source_ready().ordinal()}\n")
  builder.write_string("SOURCE_TRANSFER \{spec.source_transfer().ordinal()}\n")
  builder.write_string("SOURCE_PAYLOADS \{spec.source_payload().length()}\n")
  for index, payload in spec.source_payload() {
    builder.write_string("SOURCE_PAYLOAD \{index} \{payload.ordinal()}\n")
  }
  builder.write_string(
    "DESTINATION_READY \{spec.destination_ready().ordinal()}\n",
  )
  builder.write_string(
    "DESTINATION_VALID \{spec.destination_valid().ordinal()}\n",
  )
  builder.write_string(
    "DESTINATION_TRANSFER \{spec.destination_transfer().ordinal()}\n",
  )
  builder.write_string("DESTINATION_PAYLOADS \{spec.raw_reads().length()}\n")
  for index, raw in spec.raw_reads() {
    builder.write_string(
      "DESTINATION_PAYLOAD \{index} \{raw.ordinal()} \{spec.destination_payload()[index].ordinal()}\n",
    )
  }
  for
    item in [
      ("WRITE_BINARY", spec.write_binary()),
      ("WRITE_BINARY_NEXT", spec.write_binary_next()),
      ("READ_BINARY", spec.read_binary()),
      ("READ_BINARY_NEXT", spec.read_binary_next()),
      ("WRITE_GRAY", spec.write_gray()),
      ("WRITE_GRAY_NEXT", spec.write_gray_next()),
      ("READ_GRAY", spec.read_gray()),
      ("READ_GRAY_NEXT", spec.read_gray_next()),
    ] {
    builder.write_string("\{item.0} \{item.1.ordinal()}\n")
  }
  builder.write_string("READ_GRAY_STAGES \{spec.read_gray_stages().length()}\n")
  for index, stage in spec.read_gray_stages() {
    builder.write_string("READ_GRAY_STAGE \{index} \{stage.ordinal()}\n")
  }
  builder.write_string(
    "WRITE_GRAY_STAGES \{spec.write_gray_stages().length()}\n",
  )
  for index, stage in spec.write_gray_stages() {
    builder.write_string("WRITE_GRAY_STAGE \{index} \{stage.ordinal()}\n")
  }
  for
    item in [
      ("FULL", spec.full()),
      ("FULL_NEXT", spec.full_next()),
      ("NONEMPTY", spec.nonempty()),
      ("NONEMPTY_NEXT", spec.nonempty_next()),
      ("WRITE_ADDRESS", spec.write_address()),
      ("READ_ADDRESS", spec.read_address()),
    ] {
    builder.write_string("\{item.0} \{item.1.ordinal()}\n")
  }
  builder.write_string("ENDPRIMITIVE\n")
}

///|
fn write_cdc_primitives(
  builder : StringBuilder,
  hardware_module : @ir.Module,
) -> Unit {
  let primitives = hardware_module.cdc_primitives()
  builder.write_string("PRIMITIVES \{primitives.length()}\n")
  for primitive in primitives {
    match primitive {
      BitSynchronizer(spec) => write_bit_synchronizer(builder, spec)
      ToggleHandshake(spec) => write_toggle_handshake(builder, spec)
      AsyncFifo(spec) => write_async_fifo(builder, spec)
    }
  }
}

///|
fn write_schema_four_parameters(
  builder : StringBuilder,
  hardware_module : @ir.Module,
) -> Unit {
  write_parameters(builder, hardware_module)
}

///|
fn write_schema_four_post_ground_metadata(
  builder : StringBuilder,
  hardware_module : @ir.Module,
) -> Unit {
  write_input_timings(builder, hardware_module)
  write_output_timings(builder, hardware_module)
  write_aggregate_bindings(builder, hardware_module)
  write_cdc_primitives(builder, hardware_module)
}
