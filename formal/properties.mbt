///|
/// The formal role of a one-bit predicate.
pub(all) enum FormalPropertyKind {
  Assertion
  Assumption
  Cover
} derive(Debug, Eq)

///|
/// An explicit sampling domain for a formal property.
///
/// The current conservative backend supports rising-edge, pre-state sampling.
/// Keeping this as an owned type prevents a caller from silently relying on an
/// ambient clock or on post-edge procedural ordering.
pub struct ObservationDomain {
  clock : @property.PropertySignal
} derive(Debug, Eq)

///|
/// Construct the current supported rising-edge, pre-state observation domain.
pub fn ObservationDomain::rising_pre_edge(
  clock : @property.PropertySignal,
) -> ObservationDomain raise FormalError {
  validate_property_signal(clock)
  { clock, }
}

///|
pub fn ObservationDomain::clock(
  self : ObservationDomain,
) -> @property.PropertySignal {
  self.clock
}

///|
/// Return the LunaWave boundary corresponding to SVA clocked sampling.
pub fn ObservationDomain::point(
  _self : ObservationDomain,
) -> @property.ObservationPoint {
  PreEdge
}

///|
/// Return the canonical observation-domain spelling used in manifests.
pub fn ObservationDomain::canonical_name(_self : ObservationDomain) -> String {
  "rising-pre-edge"
}

///|
/// Explicit disable semantics for a formal property.
///
/// `WhenKnownHighAsynchronous` maps to SVA `disable iff (signal === 1'b1)`.
/// Unknown never disables the property, and the disable expression is sampled
/// with SVA's asynchronous disable semantics rather than edge-synchronously.
pub(all) enum DisableBehavior {
  NeverDisabled
  WhenKnownHighAsynchronous(@property.PropertySignal)
} derive(Debug, Eq)

///|
pub fn DisableBehavior::when_known_high_asynchronous(
  signal : @property.PropertySignal,
) -> DisableBehavior raise FormalError {
  validate_property_signal(signal)
  WhenKnownHighAsynchronous(signal)
}

///|
fn validate_property_signal(
  signal : @property.PropertySignal,
) -> Unit raise FormalError {
  match signal {
    Named(path~, name~) =>
      if path.is_empty() || name.is_empty() {
        raise InvalidPropertySignal(signal)
      }
    Node(module_path~, ..) =>
      if module_path.is_empty() {
        raise InvalidPropertySignal(signal)
      }
  }
}

///|
/// One checked property ready for formal export.
pub struct FormalProperty {
  id : @property.PropertyId
  name : String
  kind : FormalPropertyKind
  predicate : @property.PropertySignal
  domain : ObservationDomain
  disable : DisableBehavior
} derive(Debug, Eq)

///|
pub fn FormalProperty::checked(
  id : @property.PropertyId,
  name : String,
  kind : FormalPropertyKind,
  predicate : @property.PropertySignal,
  domain : ObservationDomain,
  disable : DisableBehavior,
) -> FormalProperty raise FormalError {
  require_nonempty("property name", name)
  validate_property_signal(predicate)
  validate_property_signal(domain.clock())
  match disable {
    NeverDisabled => ()
    WhenKnownHighAsynchronous(signal) => validate_property_signal(signal)
  }
  { id, name, kind, predicate, domain, disable, }
}

///|
/// Lift a LunaWave assertion or cover declaration into the formal domain.
pub fn FormalProperty::from_wave(
  spec : @property.PropertySpec,
  domain : ObservationDomain,
  disable : DisableBehavior,
) -> FormalProperty raise FormalError {
  let kind = match spec.kind() {
    Assertion => FormalPropertyKind::Assertion
    Cover => Cover
  }
  FormalProperty::checked(
    spec.id(),
    spec.name(),
    kind,
    spec.predicate(),
    domain,
    disable,
  )
}

///|
/// Construct an assumption using the same stable ID and signal vocabulary as
/// LunaWave properties. Assumptions constrain formal environments and are not
/// silently treated as simulation assertions.
pub fn FormalProperty::assumption(
  id : @property.PropertyId,
  name : String,
  predicate : @property.PropertySignal,
  domain : ObservationDomain,
  disable : DisableBehavior,
) -> FormalProperty raise FormalError {
  FormalProperty::checked(id, name, Assumption, predicate, domain, disable)
}

///|
pub fn FormalProperty::id(self : FormalProperty) -> @property.PropertyId {
  self.id
}

///|
pub fn FormalProperty::name(self : FormalProperty) -> String {
  self.name
}

///|
/// Return the exact stable SystemVerilog label derived for this property.
pub fn FormalProperty::stable_name(self : FormalProperty) -> String {
  property_identifier(self)
}

///|
pub fn FormalProperty::kind(self : FormalProperty) -> FormalPropertyKind {
  self.kind
}

///|
pub fn FormalProperty::predicate(
  self : FormalProperty,
) -> @property.PropertySignal {
  self.predicate
}

///|
pub fn FormalProperty::domain(self : FormalProperty) -> ObservationDomain {
  self.domain
}

///|
pub fn FormalProperty::disable(self : FormalProperty) -> DisableBehavior {
  self.disable
}

///|
fn compare_formal_property(
  left : FormalProperty,
  right : FormalProperty,
) -> Int {
  left.id().compare(right.id())
}

///|
/// An immutable formal plan in ascending stable property-ID order.
pub struct FormalPropertyPlan {
  properties : ReadOnlyArray[FormalProperty]
} derive(Debug, Eq)

///|
pub fn FormalPropertyPlan::checked(
  declared : ArrayView[FormalProperty],
) -> FormalPropertyPlan raise FormalError {
  if declared.is_empty() {
    raise EmptyPropertySet
  }
  let properties = declared.to_owned()
  properties.sort_by(compare_formal_property)
  for index, item in properties {
    if index > 0 && properties[index - 1].id() == item.id() {
      raise DuplicatePropertyId(item.id().ordinal())
    }
    for previous in 0..<index {
      if properties[previous].name() == item.name() {
        raise DuplicatePropertyName(item.name())
      }
    }
  }
  { properties: ReadOnlyArray::from_array(properties), }
}

///|
pub fn FormalPropertyPlan::properties(
  self : FormalPropertyPlan,
) -> ReadOnlyArray[FormalProperty] {
  self.properties
}

///|
/// A checked binding from canonical property signal identity to a conservative
/// SystemVerilog identifier already emitted in the containing module.
pub struct FormalSignalBinding {
  signal : @property.PropertySignal
  identifier : String
} derive(Debug, Eq)

///|
fn is_ascii_letter(value : UInt16) -> Bool {
  (value >= 'a' && value <= 'z') || (value >= 'A' && value <= 'Z')
}

///|
fn validate_sv_identifier(identifier : String) -> Unit raise FormalError {
  if !identifier.has_prefix("lc_") || identifier.length() <= 3 {
    raise InvalidSystemVerilogIdentifier(identifier)
  }
  for index in 0..<identifier.length() {
    let value = identifier[index]
    let valid = if index == 0 {
      is_ascii_letter(value) || value == '_'
    } else {
      is_ascii_letter(value) || (value >= '0' && value <= '9') || value == '_'
    }
    if !valid {
      raise InvalidSystemVerilogIdentifier(identifier)
    }
  }
}

///|
pub fn FormalSignalBinding::checked(
  signal : @property.PropertySignal,
  identifier : String,
) -> FormalSignalBinding raise FormalError {
  validate_property_signal(signal)
  validate_sv_identifier(identifier)
  { signal, identifier, }
}

///|
pub fn FormalSignalBinding::signal(
  self : FormalSignalBinding,
) -> @property.PropertySignal {
  self.signal
}

///|
pub fn FormalSignalBinding::identifier(self : FormalSignalBinding) -> String {
  self.identifier
}

///|
fn property_identifier(property : FormalProperty) -> String {
  "lc_p\{property.id().ordinal()}_b\{encode_text(property.name())}"
}

///|
fn resolve_binding(
  bindings : ArrayView[FormalSignalBinding],
  signal : @property.PropertySignal,
) -> String raise FormalError {
  let mut found : String? = None
  for binding in bindings {
    if binding.signal() == signal {
      if found is Some(_) {
        raise DuplicateSignalBinding(signal)
      }
      found = Some(binding.identifier())
    }
  }
  guard found is Some(identifier) else { raise MissingSignalBinding(signal) }
  identifier
}

///|
fn validate_bindings(
  bindings : ArrayView[FormalSignalBinding],
) -> Unit raise FormalError {
  for index, binding in bindings {
    for previous in 0..<index {
      if bindings[previous].signal() == binding.signal() {
        raise DuplicateSignalBinding(binding.signal())
      }
      if bindings[previous].identifier() == binding.identifier() {
        raise DuplicateBoundIdentifier(binding.identifier())
      }
    }
  }
}

///|
pub extend FormalPropertyKind with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FormalPropertyKind with Eq::{not_equal, equal}

///|
pub extend ObservationDomain with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ObservationDomain with Eq::{not_equal, equal}

///|
pub extend DisableBehavior with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend DisableBehavior with Eq::{not_equal, equal}

///|
pub extend FormalProperty with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FormalProperty with Eq::{not_equal, equal}

///|
pub extend FormalPropertyPlan with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FormalPropertyPlan with Eq::{not_equal, equal}

///|
pub extend FormalSignalBinding with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FormalSignalBinding with Eq::{not_equal, equal}
