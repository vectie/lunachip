///|
/// A deterministic one-minimal failing stimulus sequence.
///
/// `predicate_calls` includes the initial verification call. One-minimal means
/// removing any one remaining action makes the supplied predicate false.
pub struct ReductionResult {
  fixture : StimulusSequence
  predicate_calls : Int32
} derive(Debug, Eq)

///|
pub fn ReductionResult::fixture(self : ReductionResult) -> StimulusSequence {
  self.fixture
}

///|
pub fn ReductionResult::predicate_calls(self : ReductionResult) -> Int32 {
  self.predicate_calls
}

///|
fn sequence_without_range(
  sequence : StimulusSequence,
  start : Int32,
  end : Int32,
) -> StimulusSequence {
  let items : Array[Stimulus] = []
  for item_index, item in sequence.stimuli {
    if item_index < start || item_index >= end {
      items.push(item)
    }
  }
  try! StimulusSequence::checked(sequence.identity, sequence.seed, items)
}

///|
/// Reduce a failing sequence using an internal caller-provided predicate.
///
/// The reducer deliberately does not simulate or interpret an action. It uses
/// deterministic delta debugging over contiguous chunks, refining down to
/// individual actions. Chunks are always tried from the beginning, so a
/// deterministic predicate produces byte-identical output. The public entry
/// point below supplies the stable mismatch-identity check.
fn reduce_where(
  sequence : StimulusSequence,
  fails : (StimulusSequence) -> Bool,
) -> ReductionResult raise DifferentialError {
  let mut calls = 1
  if !fails(sequence) {
    raise InputDoesNotFail
  }
  let mut current = sequence
  let mut granularity = 2
  while current.stimuli.length() > 0 {
    let length = current.stimuli.length()
    let chunk_size = (length + granularity - 1) / granularity
    let mut reduced = false
    for start = 0; start < length; start = start + chunk_size {
      let end = if start + chunk_size < length {
        start + chunk_size
      } else {
        length
      }
      let candidate = sequence_without_range(current, start, end)
      calls += 1
      if fails(candidate) {
        current = candidate
        granularity = if granularity > 2 { granularity - 1 } else { 2 }
        reduced = true
        break
      }
    }
    if !reduced {
      if granularity >= length {
        break
      }
      granularity = if granularity * 2 < length {
        granularity * 2
      } else {
        length
      }
    }
  }
  { fixture: current, predicate_calls: calls, }
}

///|
/// Reduce only while an independent re-run reproduces `target` exactly.
pub fn reduce_mismatch(
  sequence : StimulusSequence,
  target : MismatchIdentity,
  reproduce : (StimulusSequence) -> Comparison,
) -> ReductionResult raise DifferentialError {
  reduce_where(sequence, fn(candidate) {
    match reproduce(candidate) {
      Mismatch(mismatch) => mismatch.identity() == target
      Equal => false
    }
  })
}

///|
pub extend ReductionResult with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ReductionResult with Eq::{not_equal, equal}
