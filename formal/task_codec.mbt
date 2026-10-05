///|
fn bounded_mode_text(mode : BoundedMode) -> String {
  match mode {
    BoundedSafety => "bmc-safety"
    BoundedCover => "bounded-cover"
  }
}

///|
fn induction_text(induction : InductionMethod) -> String {
  match induction {
    KInduction(depth) => "k-induction \{depth}"
    PropertyDirectedReachability => "pdr"
  }
}

///|
fn append_name_lists(
  output : StringBuilder,
  assumptions : ReadOnlyArray[String],
  properties : ReadOnlyArray[String],
) -> Unit {
  output.write_string("ASSUMPTIONS \{assumptions.length()}\n")
  for ordinal, name in assumptions {
    output.write_string("A \{ordinal} \{encode_text(name)}\n")
  }
  output.write_string("PROPERTIES \{properties.length()}\n")
  for ordinal, name in properties {
    output.write_string("P \{ordinal} \{encode_text(name)}\n")
  }
}

///|
fn append_common_task_fields(
  output : StringBuilder,
  name : String,
  artifact : ArtifactRef,
  tool : FormalTool,
  engine : String,
) -> Unit {
  output.write_string("TASK \{encode_text(name)}\n")
  output.write_string(
    "ARTIFACT \{encode_text(artifact.name())} sha256 \{artifact.sha256()}\n",
  )
  output.write_string(
    "TOOL \{encode_text(tool.name())} \{encode_text(tool.version())}\n",
  )
  output.write_string("ENGINE \{encode_text(engine)}\n")
}

///|
fn append_bounded_task_body(
  output : StringBuilder,
  task : BoundedProofTask,
) -> Unit {
  append_common_task_fields(
    output,
    task.name(),
    task.artifact(),
    task.tool(),
    task.engine(),
  )
  output.write_string("CLASS bounded\n")
  output.write_string("MODE \{bounded_mode_text(task.mode())}\n")
  output.write_string("BOUND \{task.bound().cycles()}\n")
  append_name_lists(output, task.assumptions(), task.properties())
}

///|
fn append_unbounded_task_body(
  output : StringBuilder,
  task : UnboundedProofTask,
) -> Unit {
  append_common_task_fields(
    output,
    task.name(),
    task.artifact(),
    task.tool(),
    task.engine(),
  )
  output.write_string("CLASS unbounded\n")
  output.write_string("MODE prove-safety\n")
  output.write_string("INDUCTION \{induction_text(task.induction())}\n")
  append_name_lists(output, task.assumptions(), task.properties())
}

///|
fn coincidence_policy_text(policy : FormalCoincidencePolicy) -> String {
  match policy {
    AtomicGlobalPreState => "atomic-global-pre-state"
  }
}

///|
fn append_timing_labels(
  output : StringBuilder,
  heading : String,
  item : String,
  labels : ReadOnlyArray[String],
) -> Unit {
  output.write_string("\{heading} \{labels.length()}\n")
  for ordinal, label in labels {
    output.write_string("\{item} \{ordinal} \{encode_text(label)}\n")
  }
}

///|
fn append_timing_contract(
  output : StringBuilder,
  contract : FormalTimingContract,
) -> Unit {
  output.write_string("GLOBAL-TIMESTEP \{contract.global_timestep().steps()}\n")
  output.write_string(
    "COINCIDENCE \{coincidence_policy_text(contract.coincidence_policy())}\n",
  )
  output.write_string("CLOCKS \{contract.clocks().length()}\n")
  for ordinal, clock in contract.clocks() {
    let edge = match clock.edge() {
      Rising => "rising"
    }
    output.write_string(
      "C \{ordinal} \{clock.domain().ordinal()} \{edge} \{signal_manifest_text(clock.signal())}\n",
    )
  }
  append_timing_labels(
    output,
    "LEGAL-TRANSITIONS",
    "L",
    contract.legal_transition_assumptions(),
  )
  append_timing_labels(output, "FAIRNESS", "F", contract.fairness_assumptions())
}

///|
/// Serialize a byte-stable bounded proof-task manifest.
pub fn BoundedProofTask::to_canonical_text(self : BoundedProofTask) -> String {
  let output = StringBuilder()
  output.write_string(
    if self.timing_contract() is Some(_) {
      "LUNACHIP-FORMAL-TASK 2\n"
    } else {
      "LUNACHIP-FORMAL-TASK 1\n"
    },
  )
  append_bounded_task_body(output, self)
  match self.timing_contract() {
    Some(contract) => append_timing_contract(output, contract)
    None => ()
  }
  output.write_string("END\n")
  output.to_string()
}

///|
/// Serialize a byte-stable unbounded proof-task manifest.
pub fn UnboundedProofTask::to_canonical_text(
  self : UnboundedProofTask,
) -> String {
  let output = StringBuilder()
  output.write_string(
    if self.timing_contract() is Some(_) {
      "LUNACHIP-FORMAL-TASK 2\n"
    } else {
      "LUNACHIP-FORMAL-TASK 1\n"
    },
  )
  append_unbounded_task_body(output, self)
  match self.timing_contract() {
    Some(contract) => append_timing_contract(output, contract)
    None => ()
  }
  output.write_string("END\n")
  output.to_string()
}

///|
pub fn ProofTaskManifest::to_canonical_text(self : ProofTaskManifest) -> String {
  match self {
    Bounded(task) => task.to_canonical_text()
    Unbounded(task) => task.to_canonical_text()
  }
}

///|
fn read_text_field(
  reader : CanonicalReader,
  keyword : String,
  description : String,
) -> String raise FormalError {
  let (line, tokens) = reader.tokens(description)
  require_tokens(line, tokens, keyword, 2, description)
  decode_text(line, tokens[1])
}

///|
fn read_artifact(reader : CanonicalReader) -> ArtifactRef raise FormalError {
  let (line, tokens) = reader.tokens("ARTIFACT name sha256 digest")
  require_tokens(line, tokens, "ARTIFACT", 4, "ARTIFACT utf8-hex sha256 digest")
  if tokens[2] != "sha256" {
    raise InvalidCanonicalLine(
      line~,
      expected="ARTIFACT utf8-hex sha256 digest",
      actual=tokens.join(" "),
    )
  }
  ArtifactRef::checked(
    decode_text(line, tokens[1]),
    tokens[3],
    role=TargetArtifact,
  )
}

///|
fn read_tool(reader : CanonicalReader) -> FormalTool raise FormalError {
  let (line, tokens) = reader.tokens("TOOL name version")
  require_tokens(line, tokens, "TOOL", 3, "TOOL name-hex version-hex")
  FormalTool::checked(
    decode_text(line, tokens[1]),
    decode_text(line, tokens[2]),
  )
}

///|
fn read_names(
  reader : CanonicalReader,
  heading : String,
  item : String,
  field : String,
) -> Array[String] raise FormalError {
  let (line, tokens) = reader.tokens("\{heading} count")
  require_tokens(line, tokens, heading, 2, "\{heading} count")
  let count = parse_int(line, field, tokens[1])
  if count < 0 {
    raise InvalidCanonicalInteger(line~, field~, value=tokens[1])
  }
  let names : Array[String] = []
  for ordinal in 0..<count {
    let (item_line, item_tokens) = reader.tokens("\{item} ordinal name")
    require_tokens(item_line, item_tokens, item, 3, "\{item} ordinal utf8-hex")
    let actual = parse_int(item_line, "\{field} ordinal", item_tokens[1])
    if actual != ordinal {
      raise InvalidCanonicalLine(
        line=item_line,
        expected="\{item} ordinal \{ordinal}",
        actual=item_tokens.join(" "),
      )
    }
    names.push(decode_text(item_line, item_tokens[2]))
  }
  names
}

///|
fn read_task_version(reader : CanonicalReader) -> Int raise FormalError {
  let kind = "LUNACHIP-FORMAL-TASK"
  let (line, tokens) = reader.tokens("\{kind} version")
  require_tokens(line, tokens, kind, 2, "\{kind} version")
  match tokens[1] {
    "1" => 1
    "2" => 2
    _ => raise UnsupportedCanonicalVersion(kind~, version=tokens[1])
  }
}

///|
fn read_clock_binding(
  reader : CanonicalReader,
  expected_ordinal : Int,
) -> FormalClockBinding raise FormalError {
  let (line, tokens) = reader.tokens("C ordinal domain edge signal")
  let fields : LineTokenReader = { line, tokens, cursor: 0, }
  fields.expect("C")
  let ordinal = parse_int(line, "clock ordinal", fields.take("clock ordinal"))
  if ordinal != expected_ordinal {
    raise InvalidCanonicalLine(
      line~,
      expected="clock ordinal \{expected_ordinal}",
      actual=tokens.join(" "),
    )
  }
  let domain_ordinal = parse_int(
    line,
    "clock domain ID",
    fields.take("clock domain ID"),
  )
  let domain = @ir.ClockDomainId::new(domain_ordinal) catch {
    _ => raise InvalidFormalClockDomainId(domain_ordinal)
  }
  let edge_text = fields.take("clock edge")
  let edge = match edge_text {
    "rising" => @ir.Rising
    _ => raise UnknownFormalClockEdge(edge_text)
  }
  let signal = read_property_signal(fields)
  fields.finish("C ordinal domain rising named|node signal")
  FormalClockBinding::checked(domain, signal, edge)
}

///|
fn read_clock_bindings(
  reader : CanonicalReader,
) -> Array[FormalClockBinding] raise FormalError {
  let (line, tokens) = reader.tokens("CLOCKS count")
  require_tokens(line, tokens, "CLOCKS", 2, "CLOCKS count")
  let count = parse_int(line, "clock count", tokens[1])
  if count < 0 {
    raise InvalidCanonicalInteger(line~, field="clock count", value=tokens[1])
  }
  let clocks : Array[FormalClockBinding] = []
  for ordinal in 0..<count {
    clocks.push(read_clock_binding(reader, ordinal))
  }
  clocks
}

///|
fn read_timing_contract(
  reader : CanonicalReader,
) -> FormalTimingContract raise FormalError {
  let (step_line, step_tokens) = reader.tokens("GLOBAL-TIMESTEP steps")
  require_tokens(
    step_line, step_tokens, "GLOBAL-TIMESTEP", 2, "GLOBAL-TIMESTEP positive-steps",
  )
  let timestep = GlobalFormalTimestep::checked(
    parse_int(step_line, "global formal timestep", step_tokens[1]),
  )
  let (policy_line, policy_tokens) = reader.tokens("COINCIDENCE policy")
  require_tokens(
    policy_line, policy_tokens, "COINCIDENCE", 2, "COINCIDENCE policy",
  )
  let policy = match policy_tokens[1] {
    "atomic-global-pre-state" => AtomicGlobalPreState
    unknown => raise UnknownCoincidencePolicy(unknown)
  }
  let clocks = read_clock_bindings(reader)
  let legal = read_names(
    reader, "LEGAL-TRANSITIONS", "L", "legal-transition assumption count",
  )
  let fairness = read_names(
    reader, "FAIRNESS", "F", "fairness assumption count",
  )
  FormalTimingContract::checked(timestep, clocks, legal, fairness, policy)
}

///|
fn bind_timing_contract(
  task : ProofTaskManifest,
  contract : FormalTimingContract,
) -> ProofTaskManifest raise FormalError {
  match task {
    Bounded(task) => Bounded(task.with_timing_contract(contract))
    Unbounded(task) => Unbounded(task.with_timing_contract(contract))
  }
}

///|
fn read_task_body(
  reader : CanonicalReader,
) -> ProofTaskManifest raise FormalError {
  let name = read_text_field(reader, "TASK", "TASK utf8-hex")
  let artifact = read_artifact(reader)
  let tool = read_tool(reader)
  let engine = read_text_field(reader, "ENGINE", "ENGINE utf8-hex")
  let (class_line, class_tokens) = reader.tokens("CLASS bounded|unbounded")
  require_tokens(
    class_line, class_tokens, "CLASS", 2, "CLASS bounded|unbounded",
  )
  let (mode_line, mode_tokens) = reader.tokens("MODE formal-mode")
  require_tokens(mode_line, mode_tokens, "MODE", 2, "MODE formal-mode")
  match class_tokens[1] {
    "bounded" => {
      let mode = match mode_tokens[1] {
        "bmc-safety" => BoundedSafety
        "bounded-cover" => BoundedCover
        _ =>
          raise InvalidCanonicalLine(
            line=mode_line,
            expected="MODE bmc-safety|bounded-cover",
            actual=mode_tokens.join(" "),
          )
      }
      let (bound_line, bound_tokens) = reader.tokens("BOUND cycles")
      require_tokens(bound_line, bound_tokens, "BOUND", 2, "BOUND cycles")
      let bound = ProofBound::checked(
        parse_int(bound_line, "bound", bound_tokens[1]),
      )
      let assumptions = read_names(
        reader, "ASSUMPTIONS", "A", "assumption count",
      )
      let properties = read_names(reader, "PROPERTIES", "P", "property count")
      Bounded(
        BoundedProofTask::checked(
          name, artifact, tool, engine, mode, bound, assumptions, properties,
        ),
      )
    }
    "unbounded" => {
      if mode_tokens[1] != "prove-safety" {
        raise InvalidCanonicalLine(
          line=mode_line,
          expected="MODE prove-safety",
          actual=mode_tokens.join(" "),
        )
      }
      let (method_line, method_tokens) = reader.tokens("INDUCTION method")
      if method_tokens.length() < 2 || method_tokens[0] != "INDUCTION" {
        raise InvalidCanonicalLine(
          line=method_line,
          expected="INDUCTION k-induction depth|pdr",
          actual=method_tokens.join(" "),
        )
      }
      let induction = match method_tokens {
        ["INDUCTION", "pdr"] => PropertyDirectedReachability
        ["INDUCTION", "k-induction", depth] =>
          InductionMethod::k_induction(
            parse_int(method_line, "induction depth", depth),
          )
        _ =>
          raise InvalidCanonicalLine(
            line=method_line,
            expected="INDUCTION k-induction depth|pdr",
            actual=method_tokens.join(" "),
          )
      }
      let assumptions = read_names(
        reader, "ASSUMPTIONS", "A", "assumption count",
      )
      let properties = read_names(reader, "PROPERTIES", "P", "property count")
      Unbounded(
        UnboundedProofTask::checked(
          name, artifact, tool, engine, induction, assumptions, properties,
        ),
      )
    }
    _ =>
      raise InvalidCanonicalLine(
        line=class_line,
        expected="CLASS bounded|unbounded",
        actual=class_tokens.join(" "),
      )
  }
}

///|
/// Strictly parse a proof-task manifest. Reordered fields, noncanonical list
/// order, extra whitespace, trailing records, and noncanonical encodings fail.
pub fn parse_proof_task(source : String) -> ProofTaskManifest raise FormalError {
  let reader = CanonicalReader::new(source)
  let version = read_task_version(reader)
  let base_task = read_task_body(reader)
  let task = if version == 2 {
    bind_timing_contract(base_task, read_timing_contract(reader))
  } else {
    base_task
  }
  finish_canonical(reader, source, task.to_canonical_text())
  task
}
