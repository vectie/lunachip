///|
fn compare_property(left : PropertySpec, right : PropertySpec) -> Int32 {
  left.id().compare(right.id())
}

///|
/// Construct an immutable plan and canonicalize declarations by property ID.
/// IDs and names must both be unique.
pub fn PropertyPlan::checked(
  declared : ArrayView[PropertySpec],
) -> PropertyPlan raise PropertyError {
  let properties = declared.to_owned()
  properties.sort_by(compare_property)
  for index, property in properties {
    if index > 0 && properties[index - 1].id() == property.id() {
      raise DuplicatePropertyId(property.id().ordinal())
    }
    for previous in 0..<index {
      if properties[previous].name() == property.name() {
        raise DuplicatePropertyName(property.name())
      }
    }
  }
  { properties: ReadOnlyArray::from_array(properties), }
}

///|
fn find_sample(
  samples : ArrayView[PropertySample],
  signal : PropertySignal,
) -> @semantics.LogicValue? raise PropertyError {
  let mut found : @semantics.LogicValue? = None
  for sample in samples {
    if sample.signal() == signal {
      if found is Some(_) {
        raise DuplicateSample(signal)
      }
      found = Some(sample.value())
    }
  }
  found
}

///|
fn assertion_outcome(value : @semantics.LogicValue) -> PropertyOutcome {
  if !value.is_fully_known() {
    AssertionFail({ reason: PredicateUnknown, actual: value, })
  } else if value.value_bits() == 0UL {
    AssertionFail({ reason: PredicateFalse, actual: value, })
  } else {
    AssertionPass
  }
}

///|
fn cover_outcome(value : @semantics.LogicValue) -> PropertyOutcome {
  if !value.is_fully_known() {
    CoverUnknown
  } else if value.value_bits() == 0UL {
    CoverMiss
  } else {
    CoverHit
  }
}

///|
/// Evaluate every property at one settled simulator boundary.
///
/// Samples may be supplied in any order. Results always follow canonical
/// ascending property-ID order and retain the caller's cycle, boundary, and
/// pre/post-edge point. Extra samples are allowed so callers can pass a wider
/// simulator snapshot; missing or duplicate referenced samples are checked
/// errors. Every predicate must be exactly one bit wide.
pub fn PropertyPlan::evaluate(
  self : PropertyPlan,
  cycle : UInt64,
  boundary : UInt64,
  point : ObservationPoint,
  samples : ArrayView[PropertySample],
) -> ReadOnlyArray[PropertyObservation] raise PropertyError {
  let observations : Array[PropertyObservation] = []
  for property in self.properties {
    guard find_sample(samples, property.predicate()) is Some(value) else {
      raise MissingSample(property.predicate())
    }
    if value.width() != 1 {
      raise PredicateWidthMismatch(
        property_id=property.id().ordinal(),
        expected=1,
        actual=value.width(),
      )
    }
    let outcome = match property.kind() {
      Assertion => assertion_outcome(value)
      Cover => cover_outcome(value)
    }
    observations.push({
      property_id: property.id(),
      property_name: property.name(),
      predicate: property.predicate(),
      cycle,
      boundary,
      point,
      outcome,
    })
  }
  ReadOnlyArray::from_array(observations)
}
