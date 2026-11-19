///|
pub struct FormalGateReceipt {
  execution_manifest_sha256 : String
  runner_exit_status : Int32
  result : @formal_core.ProofResultManifest
  status_artifact : @formal_core.ArtifactRef
  tool_versions_artifact : @formal_core.ArtifactRef
  output_digests_artifact : @formal_core.ArtifactRef
  provenance_artifact : @formal_core.ArtifactRef
  evidence : @formal_core.ArtifactRef?
} derive(Debug, Eq)

///|
pub fn FormalGateReceipt::checked(
  execution_manifest_sha256 : String,
  runner_exit_status : Int32,
  result : @formal_core.ProofResultManifest,
  status_artifact : @formal_core.ArtifactRef,
  tool_versions_artifact : @formal_core.ArtifactRef,
  output_digests_artifact : @formal_core.ArtifactRef,
  provenance_artifact : @formal_core.ArtifactRef,
  evidence : @formal_core.ArtifactRef?,
) -> FormalGateReceipt raise FormalGateError {
  let execution = @formal_core.ArtifactRef::checked(
    "execution.lcfg", execution_manifest_sha256,
  ) catch {
    error => raise FormalContract(error)
  }
  if runner_exit_status < 0 || runner_exit_status > 255 {
    raise UnsupportedSbyStatus("runner exit \{runner_exit_status}")
  }
  {
    execution_manifest_sha256: execution.sha256(),
    runner_exit_status,
    result,
    status_artifact,
    tool_versions_artifact,
    output_digests_artifact,
    provenance_artifact,
    evidence,
  }
}

///|
pub fn FormalGateReceipt::result(
  self : FormalGateReceipt,
) -> @formal_core.ProofResultManifest {
  self.result
}

///|
pub fn FormalGateReceipt::to_canonical_text(self : FormalGateReceipt) -> String {
  let result_text = self.result.to_canonical_text()
  let out = StringBuilder()
  out.write_string("LUNACHIP-PHASE4-FORMAL-RECEIPT 1\n")
  out.write_string(
    "EXECUTION-MANIFEST sha256 \{self.execution_manifest_sha256}\n",
  )
  out.write_string("RUNNER-EXIT \{self.runner_exit_status}\n")
  out.write_string("RESULT sha256 \{sha256_hex(result_text)}\n")
  out.write_string(
    "STATUS \{self.status_artifact.name()} sha256 \{self.status_artifact.sha256()}\n",
  )
  out.write_string(
    "TOOL-VERSIONS \{self.tool_versions_artifact.name()} sha256 \{self.tool_versions_artifact.sha256()}\n",
  )
  out.write_string(
    "OUTPUT-DIGESTS \{self.output_digests_artifact.name()} sha256 \{self.output_digests_artifact.sha256()}\n",
  )
  out.write_string(
    "PROVENANCE \{self.provenance_artifact.name()} sha256 \{self.provenance_artifact.sha256()}\n",
  )
  match self.evidence {
    Some(artifact) =>
      out.write_string(
        "EVIDENCE \{artifact.name()} sha256 \{artifact.sha256()}\n",
      )
    None => out.write_string("EVIDENCE none\n")
  }
  out.write_string("END\n")
  out.to_string()
}

///|
pub fn artifact_from_content(
  name : String,
  content : String,
) -> @formal_core.ArtifactRef raise FormalGateError {
  @formal_core.ArtifactRef::checked(name, sha256_hex(content)) catch {
    error => raise FormalContract(error)
  }
}

///|
pub extend FormalGateReceipt with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FormalGateReceipt with Eq::{not_equal, equal}
