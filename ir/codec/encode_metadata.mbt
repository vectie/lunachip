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
  // The schema-4 envelope fixes this table position before CDC declarations
  // land. This codec deliberately accepts only the canonical empty table.
  builder.write_string("PRIMITIVES 0\n")
}
