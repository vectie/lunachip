///|
fn append_optional_artifact(
  output : StringBuilder,
  keyword : String,
  artifact : ArtifactRef?,
) -> Unit {
  match artifact {
    None => output.write_string("\{keyword} none\n")
    Some(value) =>
      output.write_string(
        "\{keyword} artifact \{encode_text(value.name())} sha256 \{value.sha256()}\n",
      )
  }
}

///|
fn append_detail(output : StringBuilder, detail : String?) -> Unit {
  match detail {
    None => output.write_string("DETAIL none\n")
    Some(value) =>
      output.write_string("DETAIL utf8-hex \{encode_text(value)}\n")
  }
}

///|
fn append_bounded_outcome(
  output : StringBuilder,
  outcome : BoundedProofOutcome,
) -> Unit {
  output.write_string("RESULT \{bounded_result_text(outcome)}\n")
  let counterexample = match outcome {
    SafetyCounterexample(artifact) => Some(artifact)
    _ => None
  }
  let witness = match outcome {
    CoverWitness(artifact) => Some(artifact)
    _ => None
  }
  let detail = match outcome {
    BoundedInconclusive(reason) | BoundedToolError(reason) => Some(reason)
    _ => None
  }
  append_optional_artifact(output, "COUNTEREXAMPLE", counterexample)
  append_optional_artifact(output, "WITNESS", witness)
  append_detail(output, detail)
}

///|
fn append_unbounded_outcome(
  output : StringBuilder,
  outcome : UnboundedProofOutcome,
) -> Unit {
  output.write_string("RESULT \{unbounded_result_text(outcome)}\n")
  let counterexample = match outcome {
    UnboundedCounterexample(artifact) => Some(artifact)
    _ => None
  }
  let detail = match outcome {
    UnboundedInconclusive(reason) | UnboundedToolError(reason) => Some(reason)
    _ => None
  }
  append_optional_artifact(output, "COUNTEREXAMPLE", counterexample)
  append_optional_artifact(output, "WITNESS", None)
  append_detail(output, detail)
}

///|
/// Serialize bounded evidence. No code path in this serializer can produce the
/// token `proved`.
pub fn BoundedProofResult::to_canonical_text(
  self : BoundedProofResult,
) -> String {
  let output = StringBuilder()
  output.write_string(
    if self.task().timing_contract() is Some(_) {
      "LUNACHIP-FORMAL-RESULT 2\n"
    } else {
      "LUNACHIP-FORMAL-RESULT 1\n"
    },
  )
  output.write_string("TASK-MANIFEST sha256 \{self.task_sha256()}\n")
  append_bounded_task_body(output, self.task())
  match self.task().timing_contract() {
    Some(contract) => append_timing_contract(output, contract)
    None => ()
  }
  append_bounded_outcome(output, self.outcome())
  output.write_string("END\n")
  output.to_string()
}

///|
pub fn UnboundedProofResult::to_canonical_text(
  self : UnboundedProofResult,
) -> String {
  let output = StringBuilder()
  output.write_string(
    if self.task().timing_contract() is Some(_) {
      "LUNACHIP-FORMAL-RESULT 2\n"
    } else {
      "LUNACHIP-FORMAL-RESULT 1\n"
    },
  )
  output.write_string("TASK-MANIFEST sha256 \{self.task_sha256()}\n")
  append_unbounded_task_body(output, self.task())
  match self.task().timing_contract() {
    Some(contract) => append_timing_contract(output, contract)
    None => ()
  }
  append_unbounded_outcome(output, self.outcome())
  output.write_string("END\n")
  output.to_string()
}

///|
pub fn ProofResultManifest::to_canonical_text(
  self : ProofResultManifest,
) -> String {
  match self {
    BoundedResult(result) => result.to_canonical_text()
    UnboundedResult(result) => result.to_canonical_text()
  }
}

///|
fn read_optional_artifact(
  reader : CanonicalReader,
  keyword : String,
) -> ArtifactRef? raise FormalError {
  let (line, tokens) = reader.tokens("\{keyword} none|artifact")
  match tokens {
    [actual, "none"] if actual == keyword => None
    [actual, "artifact", name, "sha256", digest] if actual == keyword =>
      Some(
        ArtifactRef::checked(
          decode_text(line, name),
          digest,
          role=CounterexampleArtifact,
        ),
      )
    _ =>
      raise InvalidCanonicalLine(
        line~,
        expected="\{keyword} none|artifact utf8-hex sha256 digest",
        actual=tokens.join(" "),
      )
  }
}

///|
fn read_detail(reader : CanonicalReader) -> String? raise FormalError {
  let (line, tokens) = reader.tokens("DETAIL none|utf8-hex")
  match tokens {
    ["DETAIL", "none"] => None
    ["DETAIL", "utf8-hex", encoded] => Some(decode_text(line, encoded))
    _ =>
      raise InvalidCanonicalLine(
        line~,
        expected="DETAIL none|utf8-hex value",
        actual=tokens.join(" "),
      )
  }
}

///|
fn require_absent_artifact(
  line_name : String,
  artifact : ArtifactRef?,
) -> Unit raise FormalError {
  if artifact is Some(_) {
    raise UnexpectedResultArtifact(line_name)
  }
}

///|
fn require_no_detail(detail : String?) -> Unit raise FormalError {
  if detail is Some(_) {
    raise UnexpectedResultDetail
  }
}

///|
fn require_detail(detail : String?) -> String raise FormalError {
  guard detail is Some(value) else { raise MissingResultDetail }
  value
}

///|
fn parse_bounded_result(
  task : BoundedProofTask,
  result_text : String,
  counterexample : ArtifactRef?,
  witness : ArtifactRef?,
  detail : String?,
) -> BoundedProofResult raise FormalError {
  let outcome = match result_text {
    "bounded-pass" => {
      require_absent_artifact("COUNTEREXAMPLE", counterexample)
      require_absent_artifact("WITNESS", witness)
      require_no_detail(detail)
      BoundedPass
    }
    "counterexample" => {
      guard counterexample is Some(artifact) else {
        raise MissingResultArtifact("COUNTEREXAMPLE")
      }
      require_absent_artifact("WITNESS", witness)
      require_no_detail(detail)
      SafetyCounterexample(artifact)
    }
    "cover-witness" => {
      guard witness is Some(artifact) else {
        raise MissingResultArtifact("WITNESS")
      }
      require_absent_artifact("COUNTEREXAMPLE", counterexample)
      require_no_detail(detail)
      CoverWitness(artifact)
    }
    "no-cover-witness-within-bound" => {
      require_absent_artifact("COUNTEREXAMPLE", counterexample)
      require_absent_artifact("WITNESS", witness)
      require_no_detail(detail)
      NoCoverWitnessWithinBound
    }
    "inconclusive" => {
      require_absent_artifact("COUNTEREXAMPLE", counterexample)
      require_absent_artifact("WITNESS", witness)
      BoundedInconclusive(require_detail(detail))
    }
    "tool-error" => {
      require_absent_artifact("COUNTEREXAMPLE", counterexample)
      require_absent_artifact("WITNESS", witness)
      BoundedToolError(require_detail(detail))
    }
    _ =>
      raise ResultModeMismatch(
        mode=bounded_mode_text(task.mode()),
        result=result_text,
      )
  }
  BoundedProofResult::checked(task, outcome)
}

///|
fn parse_unbounded_result(
  task : UnboundedProofTask,
  result_text : String,
  counterexample : ArtifactRef?,
  witness : ArtifactRef?,
  detail : String?,
) -> UnboundedProofResult raise FormalError {
  require_absent_artifact("WITNESS", witness)
  let outcome = match result_text {
    "proved" => {
      require_absent_artifact("COUNTEREXAMPLE", counterexample)
      require_no_detail(detail)
      Proved
    }
    "counterexample" => {
      guard counterexample is Some(artifact) else {
        raise MissingResultArtifact("COUNTEREXAMPLE")
      }
      require_no_detail(detail)
      UnboundedCounterexample(artifact)
    }
    "inconclusive" => {
      require_absent_artifact("COUNTEREXAMPLE", counterexample)
      UnboundedInconclusive(require_detail(detail))
    }
    "tool-error" => {
      require_absent_artifact("COUNTEREXAMPLE", counterexample)
      UnboundedToolError(require_detail(detail))
    }
    _ => raise ResultModeMismatch(mode="prove-safety", result=result_text)
  }
  UnboundedProofResult::checked(task, outcome)
}

///|
fn read_result_version(reader : CanonicalReader) -> Int32 raise FormalError {
  let kind = "LUNACHIP-FORMAL-RESULT"
  let (line, tokens) = reader.tokens("\{kind} version")
  require_tokens(line, tokens, kind, 2, "\{kind} version")
  match tokens[1] {
    "1" => 1
    "2" => 2
    _ => raise UnsupportedCanonicalVersion(kind~, version=tokens[1])
  }
}

///|
/// Strictly parse a result manifest and verify the SHA-256 of its reconstructed
/// canonical task manifest before accepting any result.
pub fn parse_proof_result(
  source : String,
) -> ProofResultManifest raise FormalError {
  let reader = CanonicalReader::new(source)
  let version = read_result_version(reader)
  let (digest_line, digest_tokens) = reader.tokens(
    "TASK-MANIFEST sha256 digest",
  )
  require_tokens(
    digest_line, digest_tokens, "TASK-MANIFEST", 3, "TASK-MANIFEST sha256 digest",
  )
  if digest_tokens[1] != "sha256" {
    raise InvalidCanonicalLine(
      line=digest_line,
      expected="TASK-MANIFEST sha256 digest",
      actual=digest_tokens.join(" "),
    )
  }
  validate_digest(TaskManifest, digest_tokens[2])
  let base_task = read_task_body(reader)
  let task = if version == 2 {
    bind_timing_contract(base_task, read_timing_contract(reader))
  } else {
    base_task
  }
  let actual_digest = sha256_hex(task.to_canonical_text())
  if digest_tokens[2] != actual_digest {
    raise TaskDigestMismatch(expected=digest_tokens[2], actual=actual_digest)
  }
  let (result_line, result_tokens) = reader.tokens("RESULT result-kind")
  require_tokens(result_line, result_tokens, "RESULT", 2, "RESULT result-kind")
  let counterexample = read_optional_artifact(reader, "COUNTEREXAMPLE")
  let witness = read_optional_artifact(reader, "WITNESS")
  let detail = read_detail(reader)
  let result = match task {
    Bounded(task) =>
      BoundedResult(
        parse_bounded_result(
          task,
          result_tokens[1],
          counterexample,
          witness,
          detail,
        ),
      )
    Unbounded(task) =>
      UnboundedResult(
        parse_unbounded_result(
          task,
          result_tokens[1],
          counterexample,
          witness,
          detail,
        ),
      )
  }
  finish_canonical(reader, source, result.to_canonical_text())
  result
}
