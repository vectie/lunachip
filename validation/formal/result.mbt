///|
fn evidence_artifact(
  evidence : SbyEvidence,
) -> @formal_core.ArtifactRef raise FormalGateError {
  @formal_core.ArtifactRef::checked(
    evidence.name(),
    sha256_hex(evidence.content()),
    role=CounterexampleArtifact,
  ) catch {
    error => raise FormalContract(error)
  }
}

///|
fn require_evidence(
  task_name : String,
  evidence : SbyEvidence?,
  expected : SbyEvidenceKind,
) -> @formal_core.ArtifactRef raise FormalGateError {
  guard evidence is Some(value) else {
    if expected is CoverWitnessTrace {
      raise MissingCoverWitness(task_name)
    }
    raise MissingCounterexample(task_name)
  }
  if value.kind() != expected {
    raise UnexpectedEvidence(task_name)
  }
  evidence_artifact(value)
}

///|
fn require_no_evidence(
  task_name : String,
  evidence : SbyEvidence?,
) -> Unit raise FormalGateError {
  if evidence is Some(_) {
    raise UnexpectedEvidence(task_name)
  }
}

///|
fn bounded_sby_result(
  task : @formal_core.BoundedProofTask,
  status : String,
  evidence : SbyEvidence?,
) -> @formal_core.ProofResultManifest raise FormalGateError {
  let outcome = match (task.mode(), status) {
    (BoundedSafety, "PASS") => {
      require_no_evidence(task.name(), evidence)
      @formal_core.BoundedPass
    }
    (BoundedSafety, "FAIL") =>
      SafetyCounterexample(
        require_evidence(task.name(), evidence, BaseCounterexampleTrace),
      )
    (BoundedCover, "PASS") =>
      CoverWitness(require_evidence(task.name(), evidence, CoverWitnessTrace))
    (BoundedCover, "FAIL") => {
      require_no_evidence(task.name(), evidence)
      NoCoverWitnessWithinBound
    }
    (_, "UNKNOWN") => {
      require_no_evidence(task.name(), evidence)
      BoundedInconclusive("SBY UNKNOWN")
    }
    (_, "TIMEOUT") => {
      require_no_evidence(task.name(), evidence)
      BoundedInconclusive("SBY TIMEOUT")
    }
    (_, "ERROR") => {
      require_no_evidence(task.name(), evidence)
      BoundedToolError("SBY ERROR")
    }
    _ => raise UnsupportedSbyStatus(status)
  }
  let result = @formal_core.BoundedProofResult::checked(task, outcome) catch {
    error => raise FormalContract(error)
  }
  BoundedResult(result)
}

///|
fn unbounded_sby_result(
  task : @formal_core.UnboundedProofTask,
  status : String,
  evidence : SbyEvidence?,
) -> @formal_core.ProofResultManifest raise FormalGateError {
  let outcome = match status {
    "PASS" => {
      require_no_evidence(task.name(), evidence)
      @formal_core.Proved
    }
    "FAIL" => {
      guard evidence is Some(value) else {
        raise MissingCounterexample(task.name())
      }
      match value.kind() {
        BaseCounterexampleTrace =>
          UnboundedCounterexample(evidence_artifact(value))
        InductionDiagnosticTrace =>
          UnboundedInconclusive(
            "SBY induction-step failure; not a reachable counterexample",
          )
        CoverWitnessTrace => raise UnexpectedEvidence(task.name())
      }
    }
    "UNKNOWN" => {
      match evidence {
        Some(value) if value.kind() is InductionDiagnosticTrace =>
          ignore(evidence_artifact(value))
        Some(_) => raise UnexpectedEvidence(task.name())
        None => ()
      }
      UnboundedInconclusive(
        if evidence is Some(_) {
          "SBY induction-step failure; not a reachable counterexample"
        } else {
          "SBY UNKNOWN"
        },
      )
    }
    "TIMEOUT" => {
      require_no_evidence(task.name(), evidence)
      UnboundedInconclusive("SBY TIMEOUT")
    }
    "ERROR" => {
      require_no_evidence(task.name(), evidence)
      UnboundedToolError("SBY ERROR")
    }
    _ => raise UnsupportedSbyStatus(status)
  }
  let result = @formal_core.UnboundedProofResult::checked(task, outcome) catch {
    error => raise FormalContract(error)
  }
  UnboundedResult(result)
}

///|
/// Map one exact SBY status and optional retained trace into the typed formal
/// result taxonomy. Expected job status is deliberately not an input: evidence
/// mapping records what the tool reported, not what the gate hoped to see.
pub fn map_sby_result(
  task : @formal_core.ProofTaskManifest,
  status_text : String,
  evidence? : SbyEvidence,
) -> MappedSbyResult raise FormalGateError {
  let status_lines = status_text.trim().split("\n").to_array()
  if status_lines.length() != 1 {
    raise UnsupportedSbyStatus(status_text)
  }
  let status_fields = status_lines[0]
    .split(" ")
    .filter(field => !field.is_empty())
    .to_array()
  if status_fields.is_empty() {
    raise UnsupportedSbyStatus(status_text)
  }
  let status = status_fields[0].to_upper().to_owned()
  for index in 1..<status_fields.length() {
    if status_fields[index].is_empty() ||
      !status_fields[index].all(symbol => symbol >= '0' && symbol <= '9') {
      raise UnsupportedSbyStatus(status_text)
    }
  }
  let result = match task {
    Bounded(value) => bounded_sby_result(value, status, evidence)
    Unbounded(value) => unbounded_sby_result(value, status, evidence)
  }
  let retained = match evidence {
    Some(value) => Some(evidence_artifact(value))
    None => None
  }
  { result, evidence: retained, }
}
