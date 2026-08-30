///|
fn encode_aggregate_name_part(value : String) -> String {
  let bytes = @utf8.encode(value)
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
/// Encode one aggregate leaf as an injective versioned physical port name.
///
/// The root and every field use lowercase UTF-8 hex. Field and vector-index
/// segments have distinct tags, so names never depend on separator parsing.
pub fn aggregate_leaf_name(
  root : String,
  path : @aggregate.AggregatePath,
) -> String raise @ir.IrError {
  if root.is_empty() {
    raise EmptyName(kind="aggregate root")
  }
  let builder = StringBuilder()
  builder.write_string("__lcagg1_")
  builder.write_string(encode_aggregate_name_part(root))
  for segment in path.segments() {
    match segment {
      Field(name) => {
        builder.write_string("_f")
        builder.write_string(encode_aggregate_name_part(name))
      }
      Index(index) => builder.write_string("_i\{index}")
    }
  }
  builder.to_string()
}

///|
fn ModuleBuilder::require_unique_aggregate_root(
  self : ModuleBuilder,
  root : String,
) -> Unit raise WireError {
  for binding in self.aggregate_bindings {
    if binding.root() == root {
      raise DuplicateAggregateBinding(root)
    }
  }
}

///|
fn[A, B] same_aggregate_layout(
  left : @aggregate.Aggregate[A],
  right : @aggregate.Aggregate[B],
) -> Bool {
  match (left, right) {
    (Leaf(_), Leaf(_)) => true
    (Vector(left_items), Vector(right_items)) => {
      if left_items.length() != right_items.length() {
        return false
      }
      for index in 0..<left_items.length() {
        let left_item = left_items.at(index) catch {
          _ => abort("validated aggregate vector unexpectedly empty")
        }
        let right_item = right_items.at(index) catch {
          _ => abort("validated aggregate vector unexpectedly empty")
        }
        if !same_aggregate_layout(left_item, right_item) {
          return false
        }
      }
      true
    }
    (Record(left_fields), Record(right_fields)) => {
      if left_fields.length() != right_fields.length() {
        return false
      }
      let left_items = left_fields.fields()
      let right_items = right_fields.fields()
      for index in 0..<left_items.length() {
        if left_items[index].name() != right_items[index].name() ||
          !same_aggregate_layout(
            left_items[index].value(),
            right_items[index].value(),
          ) {
          return false
        }
      }
      true
    }
    _ => false
  }
}

///|
fn signal_aggregate_shape(
  aggregate : @aggregate.Aggregate[Signal],
) -> @aggregate.Aggregate[@ir.SignalType] raise {
  match aggregate {
    Leaf(signal) => @aggregate.Aggregate::leaf(signal.signal_type)
    Vector(items) => {
      let shapes : Array[@aggregate.Aggregate[@ir.SignalType]] = []
      for item in items.items() {
        shapes.push(signal_aggregate_shape(item))
      }
      @aggregate.Aggregate::vector(shapes)
    }
    Record(fields) => {
      let shapes : Array[(String, @aggregate.Aggregate[@ir.SignalType])] = []
      for field in fields.fields() {
        shapes.push((field.name(), signal_aggregate_shape(field.value())))
      }
      @aggregate.Aggregate::record(shapes)
    }
  }
}

///|
/// Lower a typed aggregate input to deterministic ground input nodes.
///
/// When `timing` is supplied, it is applied to every non-clock leaf. Omitting
/// it preserves legacy behavior and records no inferred timing.
pub fn ModuleBuilder::aggregate_input(
  self : ModuleBuilder,
  root : String,
  shape : @aggregate.Aggregate[@ir.SignalType],
  timing? : @ir.InputTiming,
) -> @aggregate.Aggregate[Signal] raise {
  self.require_open()
  self.require_unique_aggregate_root(root)
  let flattened = shape.flatten()
  let names = flattened.map(leaf => aggregate_leaf_name(root, leaf.path()))
  let first_node = self.nodes.length()
  let endpoints : Array[@ir.AggregateLeafTarget] = []
  for index in 0..<flattened.length() {
    endpoints.push(Node(@ir.NodeId::new(first_node + index)))
  }
  let binding = @ir.AggregateBinding::checked(
    @ir.AggregateBindingId::new(self.aggregate_bindings.length()),
    InputPort,
    root,
    shape,
    endpoints,
  )
  let signals : Array[Signal] = []
  for index, leaf in flattened {
    let signal = self.input(names[index], leaf.value())
    signals.push(signal)
  }
  let lowered = shape.reconstruct_like(signals)
  self.aggregate_bindings.push(binding)
  if timing is Some(declared) {
    for signal in signals {
      if !signal.signal_type.is_clock() {
        self.input_timing(signal, declared)
      }
    }
  }
  lowered
}

///|
/// Lower a typed aggregate output to deterministic ground output sinks.
///
/// When `timing` is supplied, it is applied to every non-clock leaf.
pub fn ModuleBuilder::aggregate_output(
  self : ModuleBuilder,
  root : String,
  shape : @aggregate.Aggregate[@ir.SignalType],
  timing? : @ir.OutputTiming,
) -> @aggregate.Aggregate[Output] raise {
  self.require_open()
  self.require_unique_aggregate_root(root)
  let flattened = shape.flatten()
  let names = flattened.map(leaf => aggregate_leaf_name(root, leaf.path()))
  let endpoints = names.map(name => @ir.AggregateLeafTarget::Output(name))
  let binding = @ir.AggregateBinding::checked(
    @ir.AggregateBindingId::new(self.aggregate_bindings.length()),
    OutputPort,
    root,
    shape,
    endpoints,
  )
  let outputs : Array[Output] = []
  for index, leaf in flattened {
    outputs.push(self.output(names[index], leaf.value()))
  }
  let lowered = shape.reconstruct_like(outputs)
  self.aggregate_bindings.push(binding)
  if timing is Some(declared) {
    for output in outputs {
      if !output.signal_type.is_clock() {
        self.output_timing(output, declared)
      }
    }
  }
  lowered
}

///|
/// Connect two aggregates only when their exact field/vector layout and every
/// ground signal type match. Validation is completed before any sink mutates.
pub fn ModuleBuilder::connect_aggregate(
  self : ModuleBuilder,
  outputs : @aggregate.Aggregate[Output],
  drivers : @aggregate.Aggregate[Signal],
) -> Unit raise {
  self.require_open()
  if !same_aggregate_layout(outputs, drivers) {
    raise AggregateShapeMismatch
  }
  let output_leaves = outputs.flatten()
  let driver_leaves = drivers.flatten()
  for index in 0..<output_leaves.length() {
    let output = output_leaves[index].value()
    let driver = driver_leaves[index].value()
    if !physical_equal(self.owner, output.owner) {
      raise ForeignOutput
    }
    self.require_signal(driver)
    let owned = self.outputs.get(output.index)
    guard owned is Some(owned) && owned.name == output.name else {
      raise ForeignOutput
    }
    if self.drivers[output.index] is Some(_) {
      raise DuplicateDriver(output.name)
    }
    if output.signal_type != driver.signal_type {
      let expected = output.signal_type.width().bits()
      let actual = driver.signal_type.width().bits()
      if expected != actual {
        raise @ir.IrError::WidthMismatch(
          operation="connect_aggregate",
          expected~,
          actual~,
        )
      }
      raise @ir.IrError::TypeMismatch(operation="connect_aggregate")
    }
  }
  for index in 0..<output_leaves.length() {
    self.connect(output_leaves[index].value(), driver_leaves[index].value())
  }
}

///|
/// Retain debug reconstruction metadata for an aggregate of internal signals.
pub fn ModuleBuilder::bind_internal_aggregate(
  self : ModuleBuilder,
  root : String,
  signals : @aggregate.Aggregate[Signal],
) -> Unit raise {
  self.require_open()
  self.require_unique_aggregate_root(root)
  let flattened = signals.flatten()
  for leaf in flattened {
    self.require_signal(leaf.value())
  }
  let shape = signal_aggregate_shape(signals)
  let endpoints = flattened.map(leaf => {
    @ir.AggregateLeafTarget::Node(leaf.value().id)
  })
  self.aggregate_bindings.push(
    @ir.AggregateBinding::checked(
      @ir.AggregateBindingId::new(self.aggregate_bindings.length()),
      Internal,
      root,
      shape,
      endpoints,
    ),
  )
}
