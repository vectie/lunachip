///|
const MAX_AGGREGATE_DEPTH : Int = 64

///|
const MAX_AGGREGATE_LEAVES : Int = 65536

///|
const MAX_CDC_PRIMITIVES : Int = 65536

///|
/// A checked elaboration parameter value. Parameters are canonical metadata;
/// they never become runtime hardware state implicitly.
pub(all) enum ParameterValue {
  Boolean(Bool)
  Signed(Int64)
  Unsigned(UInt64)
  Text(String)
  SignalTypeValue(SignalType)
} derive(Debug, Eq)

///|
/// One exact, typed parameter recorded by a MoonBit module generator.
pub struct ModuleParameter {
  name : String
  value : ParameterValue
} derive(Debug, Eq)

///|
/// Construct a named parameter. Canonical module metadata later sorts all
/// parameters by their UTF-8 bytes and rejects duplicate names.
pub fn ModuleParameter::checked(
  name : String,
  value : ParameterValue,
) -> ModuleParameter raise IrError {
  require_name(name, "parameter")
  { name, value }
}

///|
pub fn ModuleParameter::name(self : ModuleParameter) -> String {
  self.name
}

///|
pub fn ModuleParameter::value(self : ModuleParameter) -> ParameterValue {
  self.value
}

///|
/// Stable module-local identity for aggregate reconstruction metadata.
pub struct AggregateBindingId(Int) derive(Debug, Eq, Compare)

///|
pub fn AggregateBindingId::new(
  ordinal : Int,
) -> AggregateBindingId raise IrError {
  if ordinal < 0 {
    raise InvalidAggregateBindingId(ordinal)
  }
  AggregateBindingId(ordinal)
}

///|
pub fn AggregateBindingId::ordinal(self : AggregateBindingId) -> Int {
  let AggregateBindingId(ordinal) = self
  ordinal
}

///|
/// The semantic role of an aggregate binding.
pub(all) enum AggregateBindingKind {
  InputPort
  OutputPort
  Internal
} derive(Debug, Eq)

///|
/// One exact ground endpoint owned by an aggregate leaf.
pub(all) enum AggregateLeafTarget {
  Node(NodeId)
  Output(String)
} derive(Debug, Eq)

///|
/// One flattened leaf with its retained structural and ground identity.
pub struct AggregateBoundLeaf {
  ordinal : Int
  path : @aggregate.AggregatePath
  signal_type : SignalType
  target : AggregateLeafTarget
} derive(Debug, Eq)

///|
pub fn AggregateBoundLeaf::ordinal(self : AggregateBoundLeaf) -> Int {
  self.ordinal
}

///|
pub fn AggregateBoundLeaf::path(
  self : AggregateBoundLeaf,
) -> @aggregate.AggregatePath {
  self.path
}

///|
pub fn AggregateBoundLeaf::signal_type(self : AggregateBoundLeaf) -> SignalType {
  self.signal_type
}

///|
pub fn AggregateBoundLeaf::target(
  self : AggregateBoundLeaf,
) -> AggregateLeafTarget {
  self.target
}

///|
fn validate_aggregate_shape(
  binding : Int,
  shape : @aggregate.Aggregate[SignalType],
  depth : Int,
) -> Int raise IrError {
  if depth > MAX_AGGREGATE_DEPTH {
    raise AggregateDepthLimitExceeded(
      binding~,
      maximum=MAX_AGGREGATE_DEPTH,
      actual=depth,
    )
  }
  match shape {
    Leaf(_) => 1
    Vector(vector) => {
      let exemplar = vector.at(0) catch {
        _ => abort("validated Vec unexpectedly empty")
      }
      let element_leaves = validate_aggregate_shape(
        binding,
        exemplar,
        depth + 1,
      )
      let length = vector.length()
      if element_leaves > MAX_AGGREGATE_LEAVES / length {
        raise AggregateLeafLimitExceeded(
          binding~,
          maximum=MAX_AGGREGATE_LEAVES,
          minimum=MAX_AGGREGATE_LEAVES + 1,
        )
      }
      for index in 1..<length {
        let item = vector.at(index) catch {
          _ => abort("validated Vec index unexpectedly absent")
        }
        let item_leaves = validate_aggregate_shape(binding, item, depth + 1)
        if item_leaves != element_leaves || item != exemplar {
          raise HeterogeneousAggregateVector(binding~, depth~, index~)
        }
      }
      element_leaves * length
    }
    Record(bundle) => {
      let mut total = 0
      for field in bundle.fields() {
        let child = validate_aggregate_shape(binding, field.value(), depth + 1)
        if child > MAX_AGGREGATE_LEAVES - total {
          raise AggregateLeafLimitExceeded(
            binding~,
            maximum=MAX_AGGREGATE_LEAVES,
            minimum=total + child,
          )
        }
        total += child
      }
      total
    }
  }
}

///|
/// Canonical reconstruction metadata for one aggregate root.
pub struct AggregateBinding {
  id : AggregateBindingId
  kind : AggregateBindingKind
  root : String
  shape : @aggregate.Aggregate[SignalType]
  leaves : ReadOnlyArray[AggregateBoundLeaf]
} derive(Debug, Eq)

///|
/// Validate a recursive shape and bind one endpoint to every flattened leaf.
pub fn AggregateBinding::checked(
  id : AggregateBindingId,
  kind : AggregateBindingKind,
  root : String,
  shape : @aggregate.Aggregate[SignalType],
  endpoints : ArrayView[AggregateLeafTarget],
) -> AggregateBinding raise IrError {
  require_name(root, "aggregate root")
  let binding = id.ordinal()
  let expected = validate_aggregate_shape(binding, shape, 0)
  let actual = endpoints.length()
  if expected != actual {
    raise AggregateEndpointCountMismatch(binding~, expected~, actual~)
  }
  let flattened = shape.flatten()
  let leaves : Array[AggregateBoundLeaf] = []
  for index, leaf in flattened {
    leaves.push({
      ordinal: index,
      path: leaf.path(),
      signal_type: leaf.value(),
      target: endpoints[index],
    })
  }
  { id, kind, root, shape, leaves: ReadOnlyArray::from_array(leaves) }
}

///|
pub fn AggregateBinding::id(self : AggregateBinding) -> AggregateBindingId {
  self.id
}

///|
pub fn AggregateBinding::kind(self : AggregateBinding) -> AggregateBindingKind {
  self.kind
}

///|
pub fn AggregateBinding::root(self : AggregateBinding) -> String {
  self.root
}

///|
pub fn AggregateBinding::shape(
  self : AggregateBinding,
) -> @aggregate.Aggregate[SignalType] {
  self.shape
}

///|
pub fn AggregateBinding::leaves(
  self : AggregateBinding,
) -> ReadOnlyArray[AggregateBoundLeaf] {
  self.leaves
}

///|
fn utf8_bytes_compare(left_bytes : Bytes, right_bytes : Bytes) -> Int {
  let common = left_bytes.length().min(right_bytes.length())
  for index in 0..<common {
    let difference = left_bytes[index].to_int() - right_bytes[index].to_int()
    if difference != 0 {
      return difference
    }
  }
  left_bytes.length() - right_bytes.length()
}

///|
/// Immutable canonical elaboration metadata owned by one module.
pub struct ModuleMetadata {
  parameters : ReadOnlyArray[ModuleParameter]
  aggregate_bindings : ReadOnlyArray[AggregateBinding]
  input_timings : ReadOnlyArray[InputTimingBinding]
  output_timings : ReadOnlyArray[OutputTimingBinding]
  cdc_primitives : ReadOnlyArray[CdcPrimitive]
} derive(Debug, Eq)

///|
/// Return empty metadata for compatibility constructors and ground-only code.
pub fn ModuleMetadata::empty() -> ModuleMetadata {
  {
    parameters: ReadOnlyArray::from_array([]),
    aggregate_bindings: ReadOnlyArray::from_array([]),
    input_timings: ReadOnlyArray::from_array([]),
    output_timings: ReadOnlyArray::from_array([]),
    cdc_primitives: ReadOnlyArray::from_array([]),
  }
}

///|
/// Validate and canonicalize module metadata.
///
/// Parameters are sorted by exact UTF-8 bytes. Binding order is its sequential
/// ID namespace; aggregate roots and all endpoint ownership are unique.
pub fn ModuleMetadata::checked(
  parameters : ArrayView[ModuleParameter],
  aggregate_bindings : ArrayView[AggregateBinding],
) -> ModuleMetadata raise IrError {
  ModuleMetadata::checked_with_timing(parameters, aggregate_bindings, [], [])
}

///|
/// Validate and canonicalize module metadata including explicit port timing.
/// Input bindings sort by node ordinal and output bindings by exact UTF-8 name.
pub fn ModuleMetadata::checked_with_timing(
  parameters : ArrayView[ModuleParameter],
  aggregate_bindings : ArrayView[AggregateBinding],
  input_timings : ArrayView[InputTimingBinding],
  output_timings : ArrayView[OutputTimingBinding],
) -> ModuleMetadata raise IrError {
  ModuleMetadata::checked_complete(
    parameters,
    aggregate_bindings,
    input_timings,
    output_timings,
    [],
  )
}

///|
/// Validate all schema-4 metadata, including first-class CDC declarations.
pub fn ModuleMetadata::checked_complete(
  parameters : ArrayView[ModuleParameter],
  aggregate_bindings : ArrayView[AggregateBinding],
  input_timings : ArrayView[InputTimingBinding],
  output_timings : ArrayView[OutputTimingBinding],
  cdc_primitives : ArrayView[CdcPrimitive],
) -> ModuleMetadata raise IrError {
  if cdc_primitives.length() > MAX_CDC_PRIMITIVES {
    raise CdcPrimitiveLimitExceeded(
      maximum=MAX_CDC_PRIMITIVES,
      actual=cdc_primitives.length(),
    )
  }
  let keyed_parameters = parameters.map(parameter => {
    (@utf8.encode(parameter.name()), parameter)
  })
  keyed_parameters.sort_by((left, right) => utf8_bytes_compare(left.0, right.0))
  let canonical_parameters = keyed_parameters.map(item => item.1)
  for index in 1..<canonical_parameters.length() {
    if canonical_parameters[index - 1].name() ==
      canonical_parameters[index].name() {
      raise DuplicateName(
        kind="parameter",
        name=canonical_parameters[index].name(),
      )
    }
  }
  let canonical_bindings = aggregate_bindings.to_owned()
  let roots : Map[String, Unit] = Map([])
  let nodes : Map[Int, Unit] = Map([])
  let outputs : Map[String, Unit] = Map([])
  for expected, binding in canonical_bindings {
    let actual = binding.id().ordinal()
    if actual != expected {
      raise NonSequentialAggregateBindingId(expected~, actual~)
    }
    if roots.contains(binding.root()) {
      raise DuplicateName(kind="aggregate root", name=binding.root())
    }
    roots[binding.root()] = ()
    for leaf in binding.leaves() {
      match leaf.target() {
        Node(node) => {
          let ordinal = node.ordinal()
          if nodes.contains(ordinal) {
            raise DuplicateAggregateNodeEndpoint(node=ordinal)
          }
          nodes[ordinal] = ()
        }
        Output(output) => {
          if outputs.contains(output) {
            raise DuplicateAggregateOutputEndpoint(output)
          }
          outputs[output] = ()
        }
      }
    }
  }
  let canonical_input_timings = input_timings.to_owned()
  canonical_input_timings.sort_by((left, right) => {
    left.input().ordinal() - right.input().ordinal()
  })
  for index in 1..<canonical_input_timings.length() {
    if canonical_input_timings[index - 1].input() ==
      canonical_input_timings[index].input() {
      raise DuplicateInputTiming(
        input=canonical_input_timings[index].input().ordinal(),
      )
    }
  }
  let keyed_output_timings = output_timings.map(binding => {
    (@utf8.encode(binding.output()), binding)
  })
  keyed_output_timings.sort_by((left, right) => {
    utf8_bytes_compare(left.0, right.0)
  })
  let canonical_output_timings = keyed_output_timings.map(item => item.1)
  for index in 1..<canonical_output_timings.length() {
    if canonical_output_timings[index - 1].output() ==
      canonical_output_timings[index].output() {
      raise DuplicateOutputTiming(canonical_output_timings[index].output())
    }
  }
  let canonical_cdc_primitives = cdc_primitives.to_owned()
  let primitive_names : Map[String, Unit] = Map([])
  let primitive_stages : Map[Int, Unit] = Map([])
  for expected, primitive in canonical_cdc_primitives {
    let actual = primitive.id().ordinal()
    if actual != expected {
      raise NonSequentialCdcPrimitiveId(expected~, actual~)
    }
    if primitive_names.contains(primitive.name()) {
      raise DuplicateCdcPrimitiveName(primitive.name())
    }
    primitive_names[primitive.name()] = ()
    match primitive {
      BitSynchronizer(spec) =>
        for stage in spec.stages() {
          let ordinal = stage.ordinal()
          if primitive_stages.contains(ordinal) {
            raise DuplicateCdcPrimitiveStage(node=ordinal)
          }
          primitive_stages[ordinal] = ()
        }
      ToggleHandshake(spec) =>
        for node in spec.implementation_nodes() {
          let ordinal = node.ordinal()
          if primitive_stages.contains(ordinal) {
            raise ToggleHandshakeDuplicateNode(
              primitive=spec.id().ordinal(),
              node=ordinal,
            )
          }
          primitive_stages[ordinal] = ()
        }
      AsyncFifo(spec) =>
        for node in spec.implementation_nodes() {
          let ordinal = node.ordinal()
          if primitive_stages.contains(ordinal) {
            raise AsyncFifoDuplicateNode(
              primitive=spec.id().ordinal(),
              node=ordinal,
            )
          }
          primitive_stages[ordinal] = ()
        }
    }
  }
  {
    parameters: ReadOnlyArray::from_array(canonical_parameters),
    aggregate_bindings: ReadOnlyArray::from_array(canonical_bindings),
    input_timings: ReadOnlyArray::from_array(canonical_input_timings),
    output_timings: ReadOnlyArray::from_array(canonical_output_timings),
    cdc_primitives: ReadOnlyArray::from_array(canonical_cdc_primitives),
  }
}

///|
pub fn ModuleMetadata::parameters(
  self : ModuleMetadata,
) -> ReadOnlyArray[ModuleParameter] {
  self.parameters
}

///|
pub fn ModuleMetadata::aggregate_bindings(
  self : ModuleMetadata,
) -> ReadOnlyArray[AggregateBinding] {
  self.aggregate_bindings
}

///|
pub fn Module::parameters(self : Module) -> ReadOnlyArray[ModuleParameter] {
  self.metadata().parameters()
}

///|
pub fn Module::aggregate_bindings(
  self : Module,
) -> ReadOnlyArray[AggregateBinding] {
  self.metadata().aggregate_bindings()
}

///|
pub fn ModuleMetadata::input_timings(
  self : ModuleMetadata,
) -> ReadOnlyArray[InputTimingBinding] {
  self.input_timings
}

///|
pub fn ModuleMetadata::output_timings(
  self : ModuleMetadata,
) -> ReadOnlyArray[OutputTimingBinding] {
  self.output_timings
}

///|
pub fn ModuleMetadata::cdc_primitives(
  self : ModuleMetadata,
) -> ReadOnlyArray[CdcPrimitive] {
  self.cdc_primitives
}

///|
pub fn ModuleMetadata::declares_port_timing(self : ModuleMetadata) -> Bool {
  !self.input_timings.is_empty() || !self.output_timings.is_empty()
}

///|
pub fn ModuleMetadata::is_empty(self : ModuleMetadata) -> Bool {
  self.parameters.is_empty() &&
  self.aggregate_bindings.is_empty() &&
  self.input_timings.is_empty() &&
  self.output_timings.is_empty() &&
  self.cdc_primitives.is_empty()
}
