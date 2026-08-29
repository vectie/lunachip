///|
/// Stable failures raised while constructing or evaluating a property plan.
pub(all) suberror PropertyError {
  InvalidPropertyId(Int)
  EmptyPropertyName
  EmptySignalPath
  EmptySignalName
  DuplicatePropertyId(Int)
  DuplicatePropertyName(String)
  DuplicateSample(PropertySignal)
  MissingSample(PropertySignal)
  PredicateWidthMismatch(property_id~ : Int, expected~ : Int, actual~ : Int)
} derive(Debug, Eq)

///|
/// A stable property ordinal chosen by the elaborator or caller.
pub struct PropertyId(Int) derive(Debug, Eq, Compare)

///|
/// Construct a non-negative property identifier.
pub fn PropertyId::new(ordinal : Int) -> PropertyId raise PropertyError {
  if ordinal < 0 {
    raise InvalidPropertyId(ordinal)
  }
  PropertyId(ordinal)
}

///|
/// Return the stable property ordinal.
pub fn PropertyId::ordinal(self : PropertyId) -> Int {
  let PropertyId(ordinal) = self
  ordinal
}

///|
/// A canonical reference to the one-bit predicate sampled by a property.
///
/// A named signal is identified by its hierarchy path and local signal name.
/// A node signal is identified by its module path and module-local IR node ID.
/// Keeping the two forms distinct prevents string conventions from aliasing an
/// IR identity.
pub(all) enum PropertySignal {
  Named(path~ : String, name~ : String)
  Node(module_path~ : String, node~ : @ir.NodeId)
} derive(Debug, Eq)

///|
fn PropertySignal::validate(self : PropertySignal) -> Unit raise PropertyError {
  match self {
    Named(path~, name~) => {
      if path.length() == 0 {
        raise EmptySignalPath
      }
      if name.length() == 0 {
        raise EmptySignalName
      }
    }
    Node(module_path~, ..) =>
      if module_path.length() == 0 {
        raise EmptySignalPath
      }
  }
}

///|
/// Construct a checked hierarchy/name signal reference.
pub fn PropertySignal::named(
  path : String,
  name : String,
) -> PropertySignal raise PropertyError {
  if path.length() == 0 {
    raise EmptySignalPath
  }
  if name.length() == 0 {
    raise EmptySignalName
  }
  Named(path~, name~)
}

///|
/// Construct a checked module/node signal reference.
pub fn PropertySignal::node(
  module_path : String,
  node : @ir.NodeId,
) -> PropertySignal raise PropertyError {
  if module_path.length() == 0 {
    raise EmptySignalPath
  }
  Node(module_path~, node~)
}

///|
/// The property operation evaluated at an event boundary.
pub(all) enum PropertyKind {
  Assertion
  Cover
} derive(Debug, Eq)

///|
/// One immutable property declaration.
pub struct PropertySpec {
  id : PropertyId
  name : String
  kind : PropertyKind
  predicate : PropertySignal
} derive(Debug, Eq)

///|
/// Construct a checked property declaration.
pub fn PropertySpec::checked(
  id : PropertyId,
  name : String,
  kind : PropertyKind,
  predicate : PropertySignal,
) -> PropertySpec raise PropertyError {
  if name.length() == 0 {
    raise EmptyPropertyName
  }
  predicate.validate()
  { id, name, kind, predicate }
}

///|
pub fn PropertySpec::id(self : PropertySpec) -> PropertyId {
  self.id
}

///|
pub fn PropertySpec::name(self : PropertySpec) -> String {
  self.name
}

///|
pub fn PropertySpec::kind(self : PropertySpec) -> PropertyKind {
  self.kind
}

///|
pub fn PropertySpec::predicate(self : PropertySpec) -> PropertySignal {
  self.predicate
}

///|
/// The simulator boundary at which a predicate was evaluated.
pub(all) enum ObservationPoint {
  PreEdge
  PostEdge
} derive(Debug, Eq)

///|
/// Stable machine-readable assertion failure categories.
pub(all) enum AssertionFailureReason {
  PredicateFalse
  PredicateUnknown
} derive(Debug, Eq)

///|
/// Return the permanent diagnostic identifier for an assertion outcome.
pub fn AssertionFailureReason::stable_code(
  self : AssertionFailureReason,
) -> String {
  match self {
    PredicateFalse => "LC2001"
    PredicateUnknown => "LC2002"
  }
}

///|
/// Machine-readable assertion failure data.
///
/// `code` is stable across message wording and serialization changes:
/// `LC2001` denotes a known-false predicate and `LC2002` an unknown predicate.
pub struct AssertionFailure {
  reason : AssertionFailureReason
  actual : @semantics.LogicValue
} derive(Debug, Eq)

///|
pub fn AssertionFailure::code(self : AssertionFailure) -> String {
  self.reason.stable_code()
}

///|
pub fn AssertionFailure::reason(
  self : AssertionFailure,
) -> AssertionFailureReason {
  self.reason
}

///|
pub fn AssertionFailure::actual(
  self : AssertionFailure,
) -> @semantics.LogicValue {
  self.actual
}

///|
/// X-aware result of evaluating one property.
///
/// Assertions pass only on known one. Known zero fails with `LC2001`; unknown
/// fails closed with `LC2002`. Cover points hit only on known one. Known zero
/// is a miss and unknown is preserved as inconclusive rather than counted as a
/// hit or silently collapsed into a miss.
pub(all) enum PropertyOutcome {
  AssertionPass
  AssertionFail(AssertionFailure)
  CoverHit
  CoverMiss
  CoverUnknown
} derive(Debug, Eq)

///|
/// One deterministic, cycle-stamped property observation.
pub struct PropertyObservation {
  property_id : PropertyId
  property_name : String
  predicate : PropertySignal
  cycle : UInt64
  boundary : UInt64
  point : ObservationPoint
  outcome : PropertyOutcome
} derive(Debug, Eq)

///|
pub fn PropertyObservation::property_id(
  self : PropertyObservation,
) -> PropertyId {
  self.property_id
}

///|
pub fn PropertyObservation::property_name(self : PropertyObservation) -> String {
  self.property_name
}

///|
pub fn PropertyObservation::predicate(
  self : PropertyObservation,
) -> PropertySignal {
  self.predicate
}

///|
pub fn PropertyObservation::cycle(self : PropertyObservation) -> UInt64 {
  self.cycle
}

///|
pub fn PropertyObservation::boundary(self : PropertyObservation) -> UInt64 {
  self.boundary
}

///|
pub fn PropertyObservation::point(
  self : PropertyObservation,
) -> ObservationPoint {
  self.point
}

///|
pub fn PropertyObservation::outcome(
  self : PropertyObservation,
) -> PropertyOutcome {
  self.outcome
}

///|
/// One signal value supplied for a property evaluation boundary.
pub struct PropertySample {
  signal : PropertySignal
  value : @semantics.LogicValue
} derive(Debug, Eq)

///|
pub fn PropertySample::new(
  signal : PropertySignal,
  value : @semantics.LogicValue,
) -> PropertySample raise PropertyError {
  signal.validate()
  { signal, value }
}

///|
pub fn PropertySample::signal(self : PropertySample) -> PropertySignal {
  self.signal
}

///|
pub fn PropertySample::value(self : PropertySample) -> @semantics.LogicValue {
  self.value
}

///|
/// An immutable property plan in canonical ascending property-ID order.
///
/// The caller owns and passes this plan explicitly. LunaWave does not maintain
/// an ambient process-wide property registry.
pub struct PropertyPlan {
  properties : ReadOnlyArray[PropertySpec]
} derive(Debug, Eq)

///|
pub fn PropertyPlan::properties(
  self : PropertyPlan,
) -> ReadOnlyArray[PropertySpec] {
  self.properties
}
