///|
/// Outcomes possible for bounded evidence.
///
/// Deliberately, this type has no `Proved` constructor. `BoundedPass` means
/// only that no counterexample was found through the recorded finite bound.
pub(all) enum BoundedProofOutcome {
  BoundedPass
  SafetyCounterexample(ArtifactRef)
  CoverWitness(ArtifactRef)
  NoCoverWitnessWithinBound
  BoundedInconclusive(String)
  BoundedToolError(String)
} derive(Debug, Eq)

///|
fn bounded_result_text(outcome : BoundedProofOutcome) -> String {
  match outcome {
    BoundedPass => "bounded-pass"
    SafetyCounterexample(_) => "counterexample"
    CoverWitness(_) => "cover-witness"
    NoCoverWitnessWithinBound => "no-cover-witness-within-bound"
    BoundedInconclusive(_) => "inconclusive"
    BoundedToolError(_) => "tool-error"
  }
}

///|
fn validate_bounded_outcome(
  mode : BoundedMode,
  outcome : BoundedProofOutcome,
) -> Unit raise FormalError {
  let mode_matches = match (mode, outcome) {
    (BoundedSafety, BoundedPass | SafetyCounterexample(_)) => true
    (BoundedCover, CoverWitness(_) | NoCoverWitnessWithinBound) => true
    (_, BoundedInconclusive(_) | BoundedToolError(_)) => true
    _ => false
  }
  if !mode_matches {
    raise ResultModeMismatch(
      mode=bounded_mode_text(mode),
      result=bounded_result_text(outcome),
    )
  }
  match outcome {
    BoundedInconclusive(reason) | BoundedToolError(reason) =>
      require_nonempty("result detail", reason)
    SafetyCounterexample(artifact) =>
      validate_digest(CounterexampleArtifact, artifact.sha256())
    CoverWitness(artifact) =>
      validate_digest(CounterexampleArtifact, artifact.sha256())
    _ => ()
  }
}

///|
/// A bounded result whose task and outcome are mode-checked before it becomes
/// serializable.
pub struct BoundedProofResult {
  task : BoundedProofTask
  task_sha256 : String
  outcome : BoundedProofOutcome
} derive(Debug, Eq)

///|
pub fn BoundedProofResult::checked(
  task : BoundedProofTask,
  outcome : BoundedProofOutcome,
) -> BoundedProofResult raise FormalError {
  validate_bounded_outcome(task.mode(), outcome)
  { task, task_sha256: sha256_hex(task.to_canonical_text()), outcome, }
}

///|
pub fn BoundedProofResult::task(self : BoundedProofResult) -> BoundedProofTask {
  self.task
}

///|
pub fn BoundedProofResult::task_sha256(self : BoundedProofResult) -> String {
  self.task_sha256
}

///|
pub fn BoundedProofResult::outcome(
  self : BoundedProofResult,
) -> BoundedProofOutcome {
  self.outcome
}

///|
/// Outcomes possible only for an unbounded safety task.
pub(all) enum UnboundedProofOutcome {
  Proved
  UnboundedCounterexample(ArtifactRef)
  UnboundedInconclusive(String)
  UnboundedToolError(String)
} derive(Debug, Eq)

///|
fn unbounded_result_text(outcome : UnboundedProofOutcome) -> String {
  match outcome {
    Proved => "proved"
    UnboundedCounterexample(_) => "counterexample"
    UnboundedInconclusive(_) => "inconclusive"
    UnboundedToolError(_) => "tool-error"
  }
}

///|
fn validate_unbounded_outcome(
  outcome : UnboundedProofOutcome,
) -> Unit raise FormalError {
  match outcome {
    UnboundedCounterexample(artifact) =>
      validate_digest(CounterexampleArtifact, artifact.sha256())
    UnboundedInconclusive(reason) | UnboundedToolError(reason) =>
      require_nonempty("result detail", reason)
    Proved => ()
  }
}

///|
/// An unbounded safety result. This is the only serializable result type that
/// can contain `Proved`.
pub struct UnboundedProofResult {
  task : UnboundedProofTask
  task_sha256 : String
  outcome : UnboundedProofOutcome
} derive(Debug, Eq)

///|
pub fn UnboundedProofResult::checked(
  task : UnboundedProofTask,
  outcome : UnboundedProofOutcome,
) -> UnboundedProofResult raise FormalError {
  validate_unbounded_outcome(outcome)
  { task, task_sha256: sha256_hex(task.to_canonical_text()), outcome, }
}

///|
pub fn UnboundedProofResult::task(
  self : UnboundedProofResult,
) -> UnboundedProofTask {
  self.task
}

///|
pub fn UnboundedProofResult::task_sha256(self : UnboundedProofResult) -> String {
  self.task_sha256
}

///|
pub fn UnboundedProofResult::outcome(
  self : UnboundedProofResult,
) -> UnboundedProofOutcome {
  self.outcome
}

///|
/// Parsed result manifests preserve the bounded/unbounded evidence boundary.
pub(all) enum ProofResultManifest {
  BoundedResult(BoundedProofResult)
  UnboundedResult(UnboundedProofResult)
} derive(Debug, Eq)

///|
pub extend BoundedProofOutcome with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend BoundedProofOutcome with Eq::{not_equal, equal}

///|
pub extend BoundedProofResult with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend BoundedProofResult with Eq::{not_equal, equal}

///|
pub extend UnboundedProofOutcome with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend UnboundedProofOutcome with Eq::{not_equal, equal}

///|
pub extend UnboundedProofResult with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend UnboundedProofResult with Eq::{not_equal, equal}

///|
pub extend ProofResultManifest with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ProofResultManifest with Eq::{not_equal, equal}
