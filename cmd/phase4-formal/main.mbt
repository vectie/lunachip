///|
fn checked_new_directory(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    fail("refusing to overwrite existing output: \{path}")
  }
  @fs.create_dir(path)
}

///|
fn materialize_artifacts(
  id : String,
  artifacts : ReadOnlyArray[@gate.FormalBundleArtifact],
  root : String,
) -> Unit raise {
  let directory = root + "/" + id
  checked_new_directory(directory)
  for artifact in artifacts {
    @fs.write_string_to_file(directory + "/" + artifact.path, artifact.content)
  }
}

///|
fn generate(root : String) -> Unit raise {
  checked_new_directory(root)
  for bundle in @gate.standard_fifo_formal_bundles() {
    materialize_artifacts(bundle.fixture().id(), bundle.artifacts(), root)
  }
}

///|
fn generate_synchronizers(root : String) -> Unit raise {
  checked_new_directory(root)
  for bundle in @gate.standard_synchronizer_formal_bundles() {
    materialize_artifacts(bundle.fixture().id(), bundle.artifacts(), root)
  }
}

///|
fn generate_toggle_handshakes(root : String) -> Unit raise {
  checked_new_directory(root)
  for bundle in @gate.standard_toggle_formal_bundles() {
    materialize_artifacts(bundle.fixture().id(), bundle.artifacts(), root)
  }
}

///|
fn evidence_kind(text : String) -> @gate.SbyEvidenceKind raise {
  match text {
    "base" => BaseCounterexampleTrace
    "induction" => InductionDiagnosticTrace
    "cover" => CoverWitnessTrace
    _ => fail("unknown evidence kind: \{text}")
  }
}

///|
fn proof_task_name(task : @formal_core.ProofTaskManifest) -> String {
  match task {
    Bounded(value) => value.name()
    Unbounded(value) => value.name()
  }
}

///|
fn proof_task_artifact(
  task : @formal_core.ProofTaskManifest,
) -> @formal_core.ArtifactRef {
  match task {
    Bounded(value) => value.artifact()
    Unbounded(value) => value.artifact()
  }
}

///|
fn digest(name : String, content : String) -> String raise {
  @gate.artifact_from_content(name, content).sha256()
}

///|
struct OutputDigestRecord {
  path : String
  sha256 : String
}

///|
fn lowercase_hex_digit(symbol : Char) -> Bool {
  (symbol >= '0' && symbol <= '9') || (symbol >= 'a' && symbol <= 'f')
}

///|
fn safe_relative_path(path : String) -> Bool {
  !path.is_empty() &&
  !path.has_prefix("/") &&
  !path.has_suffix("/") &&
  !path.contains("\\") &&
  !path.contains(":") &&
  path.split("/").all(part => part != "" && part != "." && part != "..")
}

///|
fn parse_output_digests(
  text : String,
) -> ReadOnlyArray[OutputDigestRecord] raise {
  if !text.has_suffix("\n") {
    fail("output digest manifest must end in exactly one LF")
  }
  let lines = text.split("\n").to_array()
  if lines.length() < 2 || lines[lines.length() - 1] != "" {
    fail("output digest manifest is empty or malformed")
  }
  let records : Array[OutputDigestRecord] = []
  for index in 0..<(lines.length() - 1) {
    let line = lines[index]
    if line.length() < 67 || line[64] != ' ' || line[65] != ' ' {
      fail("invalid output digest record syntax")
    }
    let hash = line[0:64].to_owned()
    if !hash.all(lowercase_hex_digit) {
      fail("output digest must be 64 lowercase hexadecimal digits")
    }
    let path = line[66:].to_owned()
    if !safe_relative_path(path) {
      fail("unsafe output digest path: \{path}")
    }
    if records.any(record => record.path == path) {
      fail("duplicate output digest path: \{path}")
    }
    records.push({ path, sha256: hash })
  }
  ReadOnlyArray::from_array(records)
}

///|
fn require_output_digest(
  records : ReadOnlyArray[OutputDigestRecord],
  path : String,
  expected : String,
) -> Unit raise {
  let matches = records.filter(record => record.path == path)
  if matches.length() != 1 || matches[0].sha256 != expected {
    fail("output digest mismatch for \{path}")
  }
}

///|
fn verify_regenerated_bundle(
  bundle : String,
  source_set : String,
) -> Unit raise {
  for artifact in @gate.regenerate_formal_artifacts(source_set) {
    let path = bundle + "/" + artifact.path()
    if !@fs.path_exists(path) {
      fail("regenerated formal artifact is missing: \{artifact.path()}")
    }
    if @fs.read_file_to_string(path) != artifact.content() {
      fail(
        "formal artifact differs from canonical regeneration: \{artifact.path()}",
      )
    }
  }
}

///|
fn verify_bundle(bundle : String, task_name : String) -> Unit raise {
  let task_file = bundle + "/" + task_name + ".lcft"
  let execution_file = bundle + "/" + task_name + ".lcfg"
  for
    path in [
      task_file,
      execution_file,
      bundle + "/properties.lcfp",
      bundle + "/source-set.lcfs",
      bundle + "/design.lcir",
      bundle + "/job.json",
    ] {
    if !@fs.path_exists(path) {
      fail("missing bound formal artifact: \{path}")
    }
  }
  let task_text = @fs.read_file_to_string(task_file)
  let task = @formal_core.parse_proof_task(task_text)
  if proof_task_name(task) != task_name {
    fail("task filename/name mismatch")
  }
  let property_text = @fs.read_file_to_string(bundle + "/properties.lcfp")
  let properties = @formal_core.parse_formal_property_manifest(property_text)
  @gate.verify_task_property_binding(task, properties)
  let (tool, engine, mode_line, claim_line, bound_line) = match task {
    Bounded(value) => {
      let (mode, claim) = match value.mode() {
        BoundedSafety => ("MODE bmc", "CLAIM bounded-safety-up-to-bound")
        BoundedCover => ("MODE cover", "CLAIM reachability-within-bound")
      }
      (
        value.tool(),
        value.engine(),
        mode,
        claim,
        "BOUND \{value.bound().cycles()}",
      )
    }
    Unbounded(value) => {
      let induction_depth = match value.induction() {
        KInduction(depth) => depth
        PropertyDirectedReachability =>
          fail("locked runner supports k-induction only")
      }
      (
        value.tool(),
        value.engine(),
        "MODE prove",
        "CLAIM unbounded-safety-if-base-and-induction-pass",
        "BOUND \{induction_depth}",
      )
    }
  }
  if tool.name() != "Yosys/SymbiYosys/Bitwuzla" ||
    tool.version() != "Yosys 0.68; SBY v0.68; Bitwuzla 0.9.1" ||
    engine != "smtbmc-bitwuzla" {
    fail("task tool or engine is not the locked Phase 4 identity")
  }
  let harness = @fs.read_file_to_string(bundle + "/formal-harness.sv")
  for property in properties.properties() {
    let label = property.stable_name() + ":"
    let occurrences = harness.split(label).length() - 1
    if occurrences != 1 {
      fail(
        "formal harness must contain each stable property label exactly once",
      )
    }
  }
  let source_set = @fs.read_file_to_string(bundle + "/source-set.lcfs")
  verify_regenerated_bundle(bundle, source_set)
  let target = proof_task_artifact(task)
  if target.name() != "source-set.lcfs" ||
    target.sha256() != digest("source-set.lcfs", source_set) {
    fail("task does not bind the exact source set")
  }
  let design_text = @fs.read_file_to_string(bundle + "/design.lcir")
  let design = @ir_codec.parse(design_text)
  if @ir_codec.serialize(design) != design_text {
    fail("non-canonical bound IR")
  }
  let source_lines = source_set.split("\n").to_array()
  for
    line in [
      "ADDRESS-KNOWNNESS two-state-formal-all-binary",
      "IR design.lcir sha256 \{digest("design.lcir", design_text)}",
      "PROPERTIES properties.lcfp sha256 \{digest("properties.lcfp", property_text)}",
    ] {
    if !source_lines.contains(line) {
      fail("source-set binding mismatch: \{line}")
    }
  }
  let job_text = @fs.read_file_to_string(bundle + "/job.json")
  let execution = @fs.read_file_to_string(execution_file)
  let execution_lines = execution.split("\n").to_array()
  let required_lines = [
    "TASK \{task_name} sha256 \{digest("task.lcft", task_text)}",
    "JOB job.json sha256 \{digest("job.json", job_text)}",
    "PROPERTIES properties.lcfp sha256 \{digest("properties.lcfp", property_text)}",
    "SOURCE-SET source-set.lcfs sha256 \{target.sha256()}",
    "ENGINE smtbmc",
    "SOLVER bitwuzla",
    "MULTICLOCK on",
    "ADDRESS-KNOWNNESS two-state-formal-all-binary",
    mode_line,
    claim_line,
    bound_line,
    "RUNNER scripts/phase4-yosys-run.sh oci formal \{task_name} BUNDLE OUTPUT",
  ]
  for line in required_lines {
    if !execution_lines.contains(line) {
      fail("execution manifest binding mismatch: \{line}")
    }
  }
  let (selected_assumptions, selected_properties) = match task {
    Bounded(value) => (value.assumptions(), value.properties())
    Unbounded(value) => (value.assumptions(), value.properties())
  }
  for
    line in [
      "SELECTED-ASSUMPTIONS \{selected_assumptions.length()}",
      "SELECTED-PROPERTIES \{selected_properties.length()}",
    ] {
    if !execution_lines.contains(line) {
      fail("execution property-selection mismatch: \{line}")
    }
  }
  for index, label in selected_assumptions {
    let line = "A \{index} \{label}"
    if !execution_lines.contains(line) {
      fail("execution assumption-selection mismatch: \{line}")
    }
  }
  for index, label in selected_properties {
    let line = "P \{index} \{label}"
    if !execution_lines.contains(line) {
      fail("execution property-selection mismatch: \{line}")
    }
  }
  let failure_lines = execution_lines.filter(line => {
    line.has_prefix("EXPECTED-FAILURE ")
  })
  if failure_lines.length() != 1 {
    fail("execution manifest must declare exactly one expected failure")
  }
  let failure_line = failure_lines[0].to_owned()
  let failure_label = failure_line["EXPECTED-FAILURE ".length():].to_owned()
  if failure_label != "none" {
    let task_properties = match task {
      Bounded(value) => value.properties()
      Unbounded(value) => value.properties()
    }
    if !task_properties.contains(failure_label) {
      fail("expected failure label is not selected by the task")
    }
  }
  println("formal bundle binding verified: \{task_name}")
}

///|
fn collect(args : Array[String]) -> Unit raise {
  guard args
    is [
      _,
      "collect",
      task_file,
      status_file,
      kind,
      evidence_name,
      evidence_file,
      versions_file,
      outputs_file,
      provenance_file,
      execution_file,
      exit_text,
      result_file,
      receipt_file,
    ] else {
    fail("invalid collect arguments")
  }
  let task_text = @fs.read_file_to_string(task_file)
  let task = @formal_core.parse_proof_task(task_text)
  if exit_text != "0" {
    fail("collector only accepts the successful locked runner boundary")
  }
  let execution_text = @fs.read_file_to_string(execution_file)
  let expected_task_line = "TASK \{proof_task_name(task)} sha256 \{digest("task.lcft", task_text)}"
  if !execution_text.split("\n").contains(expected_task_line) {
    fail("execution manifest does not bind collected task")
  }
  let evidence = if kind == "none" {
    if evidence_name != "-" || evidence_file != "-" {
      fail("none evidence must use canonical dash placeholders")
    }
    None
  } else {
    let checked_kind = evidence_kind(kind)
    let valid_name = match checked_kind {
      BaseCounterexampleTrace =>
        evidence_name.has_suffix("/trace.vcd") || evidence_name is "trace.vcd"
      InductionDiagnosticTrace =>
        evidence_name.has_suffix("/trace_induct.vcd") ||
        evidence_name is "trace_induct.vcd"
      CoverWitnessTrace =>
        evidence_name.contains("trace") && evidence_name.has_suffix(".vcd")
    }
    if !valid_name {
      fail("evidence name/kind mismatch")
    }
    Some(
      @gate.SbyEvidence::checked(
        checked_kind,
        evidence_name,
        @fs.read_file_to_string(evidence_file),
      ),
    )
  }
  let status_text = @fs.read_file_to_string(status_file)
  let mapped = match evidence {
    Some(value) => @gate.map_sby_result(task, status_text, evidence=value)
    None => @gate.map_sby_result(task, status_text)
  }
  let result_text = mapped.result().to_canonical_text()
  let status = @gate.artifact_from_content(
    "sby/status",
    @fs.read_file_to_string(status_file),
  )
  let versions = @gate.artifact_from_content(
    "tool-versions.txt",
    @fs.read_file_to_string(versions_file),
  )
  let outputs = @gate.artifact_from_content(
    "outputs.sha256",
    @fs.read_file_to_string(outputs_file),
  )
  let provenance_text = @fs.read_file_to_string(provenance_file)
  let lock_manifest = "sha256:10433156fa7d19e5e15d09dd0dc348faf981325a8685af92f3864c2a25aa1775"
  let lock_config = "sha256:5a4191a1b674e2ca9eff5af1929f0fd217c95cce45a641259ce09274ecdde44a"
  let provenance_lines = provenance_text.split("\n").to_array()
  if provenance_lines.length() != 6 || provenance_lines[5] != "" {
    fail("runner provenance must be the exact five-line locked record")
  }
  let expected_provenance = [
    "LOCK toolchain/yosys/lock.json sha256 \{digest("toolchain/yosys/lock.json", @fs.read_file_to_string("toolchain/yosys/lock.json"))}",
    "RUNNER scripts/phase4-yosys-run.sh sha256 \{digest("scripts/phase4-yosys-run.sh", @fs.read_file_to_string("scripts/phase4-yosys-run.sh"))}",
    "OCI-IMAGE ghcr.io/zubax/zubax-fpga-toolchain-oss@\{lock_manifest}",
    "OCI-CONFIG \{lock_config}",
  ]
  for line in expected_provenance {
    if !provenance_lines.contains(line) {
      fail("runner provenance identity mismatch: \{line}")
    }
  }
  let observed = provenance_lines[4]
  if observed != "OBSERVED-IMAGE-ID \{lock_manifest}" &&
    observed != "OBSERVED-IMAGE-ID \{lock_config}" {
    fail("runner provenance observed image identity is not locked")
  }
  let provenance = @gate.artifact_from_content(
    "provenance.txt", provenance_text,
  )
  let output_digests = @fs.read_file_to_string(outputs_file)
  let digest_records = parse_output_digests(output_digests)
  let work_prefix = proof_task_name(task) + "-work/"
  require_output_digest(digest_records, work_prefix + "status", status.sha256())
  require_output_digest(digest_records, "tool-versions.txt", versions.sha256())
  require_output_digest(digest_records, "provenance.txt", provenance.sha256())
  match mapped.evidence() {
    Some(value) =>
      require_output_digest(
        digest_records,
        work_prefix + value.name(),
        value.sha256(),
      )
    None => ()
  }
  let receipt = @gate.FormalGateReceipt::checked(
    @gate.artifact_from_content("execution.lcfg", execution_text).sha256(),
    @strconv.from_str(exit_text),
    mapped.result(),
    status,
    versions,
    outputs,
    provenance,
    mapped.evidence(),
  )
  @fs.write_string_to_file(result_file, result_text)
  @fs.write_string_to_file(receipt_file, receipt.to_canonical_text())
}

///|
fn main raise {
  let args = @env.args()
  match args {
    [_, "generate", root] => generate(root)
    [_, "generate-synchronizers", root] => generate_synchronizers(root)
    [_, "generate-toggle-handshakes", root] => generate_toggle_handshakes(root)
    [_, "verify", bundle, task] => verify_bundle(bundle, task)
    [_, "collect", ..] => collect(args)
    _ =>
      fail(
        "usage: phase4-formal generate OUT_ROOT | phase4-formal generate-synchronizers OUT_ROOT | phase4-formal generate-toggle-handshakes OUT_ROOT | phase4-formal verify BUNDLE TASK | phase4-formal collect TASK STATUS KIND EVIDENCE_NAME EVIDENCE_FILE VERSIONS OUTPUTS PROVENANCE EXECUTION EXIT RESULT RECEIPT",
      )
  }
}
