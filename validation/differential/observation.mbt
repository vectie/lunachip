///|
/// Stable observation points within one event/cycle coordinate.
pub(all) enum ObservationPhase {
  InputApplied
  PreEdge
  PostEdge
  Settled
} derive(Debug, Eq)

///|
fn ObservationPhase::rank(self : ObservationPhase) -> Int {
  match self {
    InputApplied => 0
    PreEdge => 1
    PostEdge => 2
    Settled => 3
  }
}

///|
/// Compare canonical identities by UTF-8 bytes, matching the IR, trace, and
/// emitter ordering contract rather than host string/code-unit ordering.
fn compare_utf8(left_bytes : Bytes, right_bytes : Bytes) -> Int {
  let shared_length = if left_bytes.length() < right_bytes.length() {
    left_bytes.length()
  } else {
    right_bytes.length()
  }
  for index in 0..<shared_length {
    let left_byte = left_bytes[index].to_int()
    let right_byte = right_bytes[index].to_int()
    if left_byte != right_byte {
      return left_byte.compare(right_byte)
    }
  }
  left_bytes.length().compare(right_bytes.length())
}

///|
/// One simulator-neutral tap observation.
pub struct Observation {
  event : UInt64
  cycle : UInt64
  phase : ObservationPhase
  tap : String
  tap_utf8 : Bytes
  value : NormalizedValue
} derive(Debug, Eq)

///|
pub fn Observation::checked(
  event : UInt64,
  cycle : UInt64,
  phase : ObservationPhase,
  tap : String,
  value : NormalizedValue,
) -> Observation raise DifferentialError {
  if tap.length() == 0 {
    raise EmptyTap
  }
  { event, cycle, phase, tap, tap_utf8: @utf8.encode(tap), value }
}

///|
pub fn Observation::event(self : Observation) -> UInt64 {
  self.event
}

///|
pub fn Observation::cycle(self : Observation) -> UInt64 {
  self.cycle
}

///|
pub fn Observation::phase(self : Observation) -> ObservationPhase {
  self.phase
}

///|
pub fn Observation::tap(self : Observation) -> String {
  self.tap
}

///|
pub fn Observation::value(self : Observation) -> NormalizedValue {
  self.value
}

///|
fn compare_observation_key(left : Observation, right : Observation) -> Int {
  let event_order = left.event.compare(right.event)
  if event_order != 0 {
    return event_order
  }
  let cycle_order = left.cycle.compare(right.cycle)
  if cycle_order != 0 {
    return cycle_order
  }
  let phase_order = left.phase.rank().compare(right.phase.rank())
  if phase_order != 0 {
    return phase_order
  }
  compare_utf8(left.tap_utf8, right.tap_utf8)
}

///|
/// An immutable canonical result set, sorted by event, cycle, phase, and tap.
pub struct ObservationSet {
  identity : ResultIdentity
  observations : ReadOnlyArray[Observation]
} derive(Debug, Eq)

///|
pub fn ObservationSet::checked(
  identity : ResultIdentity,
  observations : Array[Observation],
) -> ObservationSet raise DifferentialError {
  let sorted = observations.copy()
  sorted.sort_by(compare_observation_key)
  for index in 1..<sorted.length() {
    let previous = sorted[index - 1]
    let current = sorted[index]
    if previous.event == current.event && previous.cycle != current.cycle {
      raise InconsistentObservationEventCycle(
        event=current.event,
        first_cycle=previous.cycle,
        actual_cycle=current.cycle,
      )
    }
    if previous.event != current.event && previous.cycle > current.cycle {
      raise NonMonotonicObservationCycle(index~)
    }
    if compare_observation_key(sorted[index - 1], sorted[index]) == 0 {
      let duplicate = sorted[index]
      raise DuplicateObservation(
        event=duplicate.event,
        cycle=duplicate.cycle,
        phase=duplicate.phase,
        tap=duplicate.tap,
      )
    }
  }
  { identity, observations: ReadOnlyArray::from_array(sorted) }
}

///|
pub fn ObservationSet::identity(self : ObservationSet) -> ResultIdentity {
  self.identity
}

///|
pub fn ObservationSet::observations(
  self : ObservationSet,
) -> ReadOnlyArray[Observation] {
  self.observations
}

///|
/// Stable structured mismatch classes.
pub(all) enum MismatchKind {
  IdentityMismatch(field~ : IdentityField, expected~ : String, actual~ : String)
  MissingActual(Observation)
  ExtraActual(Observation)
  ValueMismatch(
    expected~ : Observation,
    actual~ : Observation,
    difference~ : ValueDifference
  )
} derive(Debug, Eq)

///|
/// The first mismatch in canonical observation order.
pub struct DifferentialMismatch {
  expected_index : Int?
  actual_index : Int?
  kind : MismatchKind
} derive(Debug, Eq)

///|
pub fn DifferentialMismatch::expected_index(
  self : DifferentialMismatch,
) -> Int? {
  self.expected_index
}

///|
pub fn DifferentialMismatch::actual_index(self : DifferentialMismatch) -> Int? {
  self.actual_index
}

///|
pub fn DifferentialMismatch::kind(self : DifferentialMismatch) -> MismatchKind {
  self.kind
}

///|
pub(all) enum Comparison {
  Equal
  Mismatch(DifferentialMismatch)
} derive(Debug, Eq)

///|
/// Stable identity used to ensure reduction preserves the same disagreement.
pub(all) enum MismatchIdentity {
  Identity(field~ : IdentityField, expected~ : String, actual~ : String)
  Missing(
    event~ : UInt64,
    cycle~ : UInt64,
    phase~ : ObservationPhase,
    tap~ : String
  )
  Extra(
    event~ : UInt64,
    cycle~ : UInt64,
    phase~ : ObservationPhase,
    tap~ : String
  )
  Value(
    event~ : UInt64,
    cycle~ : UInt64,
    phase~ : ObservationPhase,
    tap~ : String,
    difference~ : ValueDifference
  )
} derive(Debug, Eq)

///|
pub fn DifferentialMismatch::identity(
  self : DifferentialMismatch,
) -> MismatchIdentity {
  match self.kind {
    IdentityMismatch(field~, expected~, actual~) =>
      Identity(field~, expected~, actual~)
    MissingActual(observation) =>
      Missing(
        event=observation.event,
        cycle=observation.cycle,
        phase=observation.phase,
        tap=observation.tap,
      )
    ExtraActual(observation) =>
      Extra(
        event=observation.event,
        cycle=observation.cycle,
        phase=observation.phase,
        tap=observation.tap,
      )
    ValueMismatch(expected~, difference~, ..) =>
      Value(
        event=expected.event,
        cycle=expected.cycle,
        phase=expected.phase,
        tap=expected.tap,
        difference~,
      )
  }
}

///|
/// Compare canonicalized runs without evaluating any hardware operation.
pub fn compare(
  expected : ObservationSet,
  actual : ObservationSet,
) -> Comparison {
  let expected_design = expected.identity.design
  let actual_design = actual.identity.design
  if expected_design.semantic_version != actual_design.semantic_version {
    return Mismatch({
      expected_index: None,
      actual_index: None,
      kind: IdentityMismatch(
        field=SemanticVersion,
        expected=expected_design.semantic_version,
        actual=actual_design.semantic_version,
      ),
    })
  }
  if expected_design.design_sha256 != actual_design.design_sha256 {
    return Mismatch({
      expected_index: None,
      actual_index: None,
      kind: IdentityMismatch(
        field=DesignSha256,
        expected=expected_design.design_sha256,
        actual=actual_design.design_sha256,
      ),
    })
  }
  if expected.identity.stimulus_sha256 != actual.identity.stimulus_sha256 {
    return Mismatch({
      expected_index: None,
      actual_index: None,
      kind: IdentityMismatch(
        field=StimulusSha256,
        expected=expected.identity.stimulus_sha256,
        actual=actual.identity.stimulus_sha256,
      ),
    })
  }
  let expected_items = expected.observations
  let actual_items = actual.observations
  for expected_index = 0, actual_index = 0; expected_index <
     expected_items.length() ||
     actual_index < actual_items.length(); {
    if expected_index == expected_items.length() {
      return Mismatch({
        expected_index: Some(expected_index),
        actual_index: Some(actual_index),
        kind: ExtraActual(actual_items[actual_index]),
      })
    }
    if actual_index == actual_items.length() {
      return Mismatch({
        expected_index: Some(expected_index),
        actual_index: Some(actual_index),
        kind: MissingActual(expected_items[expected_index]),
      })
    }
    let expected_observation = expected_items[expected_index]
    let actual_observation = actual_items[actual_index]
    let order = compare_observation_key(
      expected_observation, actual_observation,
    )
    if order < 0 {
      return Mismatch({
        expected_index: Some(expected_index),
        actual_index: Some(actual_index),
        kind: MissingActual(expected_observation),
      })
    }
    if order > 0 {
      return Mismatch({
        expected_index: Some(expected_index),
        actual_index: Some(actual_index),
        kind: ExtraActual(actual_observation),
      })
    }
    match expected_observation.value.difference(actual_observation.value) {
      Some(difference) =>
        return Mismatch({
          expected_index: Some(expected_index),
          actual_index: Some(actual_index),
          kind: ValueMismatch(
            expected=expected_observation,
            actual=actual_observation,
            difference~,
          ),
        })
      None => continue expected_index + 1, actual_index + 1
    }
  } nobreak {
    Equal
  }
}
