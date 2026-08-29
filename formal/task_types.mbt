///|
/// A named content-addressed artifact used by a formal task or result.
pub struct ArtifactRef {
  name : String
  sha256 : String
} derive(Debug, Eq)

///|
fn valid_artifact_name(name : String) -> Bool {
  if name.is_empty() ||
    name.has_prefix("/") ||
    name.has_suffix("/") ||
    name.contains("\\") ||
    name.contains(":") {
    return false
  }
  for component in name.split("/") {
    if component is "" || component is "." || component is ".." {
      return false
    }
  }
  true
}

///|
pub fn ArtifactRef::checked(
  name : String,
  sha256 : String,
  role? : DigestRole = TargetArtifact,
) -> ArtifactRef raise FormalError {
  if !valid_artifact_name(name) {
    raise InvalidArtifactName(name)
  }
  validate_digest(role, sha256)
  { name, sha256 }
}

///|
pub fn ArtifactRef::name(self : ArtifactRef) -> String {
  self.name
}

///|
pub fn ArtifactRef::sha256(self : ArtifactRef) -> String {
  self.sha256
}

///|
/// Exact external formal tool identity.
pub struct FormalTool {
  name : String
  version : String
} derive(Debug, Eq)

///|
pub fn FormalTool::checked(
  name : String,
  version : String,
) -> FormalTool raise FormalError {
  require_nonempty("tool name", name)
  require_nonempty("tool version", version)
  { name, version }
}

///|
pub fn FormalTool::name(self : FormalTool) -> String {
  self.name
}

///|
pub fn FormalTool::version(self : FormalTool) -> String {
  self.version
}

///|
/// Supported bounded task modes.
pub(all) enum BoundedMode {
  BoundedSafety
  BoundedCover
} derive(Debug, Eq)

///|
/// A strictly positive number of formal clock steps.
pub struct ProofBound(Int) derive(Debug, Eq, Compare)

///|
pub fn ProofBound::checked(cycles : Int) -> ProofBound raise FormalError {
  if cycles <= 0 {
    raise InvalidBound(cycles)
  }
  ProofBound(cycles)
}

///|
pub fn ProofBound::cycles(self : ProofBound) -> Int {
  let ProofBound(cycles) = self
  cycles
}

///|
/// Unbounded safety method declared to the external engine.
pub(all) enum InductionMethod {
  KInduction(Int)
  PropertyDirectedReachability
} derive(Debug, Eq)

///|
pub fn InductionMethod::k_induction(
  depth : Int,
) -> InductionMethod raise FormalError {
  if depth <= 0 {
    raise InvalidInductionDepth(depth)
  }
  KInduction(depth)
}

///|
fn validate_induction(induction : InductionMethod) -> Unit raise FormalError {
  match induction {
    KInduction(depth) => if depth <= 0 { raise InvalidInductionDepth(depth) }
    PropertyDirectedReachability => ()
  }
}

///|
fn canonical_names(
  kind : ManifestNameKind,
  names : ArrayView[String],
) -> ReadOnlyArray[String] raise FormalError {
  let canonical = names.to_owned()
  for name in canonical {
    require_nonempty(
      if kind is AssumptionName {
        "assumption name"
      } else {
        "property name"
      },
      name,
    )
  }
  canonical.sort_by(compare_canonical_text)
  for index, name in canonical {
    if index > 0 && canonical[index - 1] == name {
      raise DuplicateManifestName(kind~, name~)
    }
  }
  ReadOnlyArray::from_array(canonical)
}

///|
fn validate_name_roles(
  assumptions : ReadOnlyArray[String],
  properties : ReadOnlyArray[String],
) -> Unit raise FormalError {
  if properties.is_empty() {
    raise EmptyPropertySet
  }
  for assumption in assumptions {
    for property in properties {
      if assumption == property {
        raise NameUsedAsAssumptionAndProperty(assumption)
      }
    }
  }
}

///|
/// A bounded model-checking or bounded cover task.
pub struct BoundedProofTask {
  name : String
  artifact : ArtifactRef
  tool : FormalTool
  engine : String
  mode : BoundedMode
  bound : ProofBound
  assumptions : ReadOnlyArray[String]
  properties : ReadOnlyArray[String]
} derive(Debug, Eq)

///|
pub fn BoundedProofTask::checked(
  name : String,
  artifact : ArtifactRef,
  tool : FormalTool,
  engine : String,
  mode : BoundedMode,
  bound : ProofBound,
  assumptions : ArrayView[String],
  properties : ArrayView[String],
) -> BoundedProofTask raise FormalError {
  require_nonempty("task name", name)
  require_nonempty("engine", engine)
  let checked_assumptions = canonical_names(AssumptionName, assumptions)
  let checked_properties = canonical_names(PropertyName, properties)
  validate_name_roles(checked_assumptions, checked_properties)
  {
    name,
    artifact,
    tool,
    engine,
    mode,
    bound,
    assumptions: checked_assumptions,
    properties: checked_properties,
  }
}

///|
pub fn BoundedProofTask::name(self : BoundedProofTask) -> String {
  self.name
}

///|
pub fn BoundedProofTask::artifact(self : BoundedProofTask) -> ArtifactRef {
  self.artifact
}

///|
pub fn BoundedProofTask::tool(self : BoundedProofTask) -> FormalTool {
  self.tool
}

///|
pub fn BoundedProofTask::engine(self : BoundedProofTask) -> String {
  self.engine
}

///|
pub fn BoundedProofTask::mode(self : BoundedProofTask) -> BoundedMode {
  self.mode
}

///|
pub fn BoundedProofTask::bound(self : BoundedProofTask) -> ProofBound {
  self.bound
}

///|
pub fn BoundedProofTask::assumptions(
  self : BoundedProofTask,
) -> ReadOnlyArray[String] {
  self.assumptions
}

///|
pub fn BoundedProofTask::properties(
  self : BoundedProofTask,
) -> ReadOnlyArray[String] {
  self.properties
}

///|
/// An unbounded safety task. Cover reachability remains bounded in this
/// initial contract; only safety tasks can produce the `Proved` result type.
pub struct UnboundedProofTask {
  name : String
  artifact : ArtifactRef
  tool : FormalTool
  engine : String
  induction : InductionMethod
  assumptions : ReadOnlyArray[String]
  properties : ReadOnlyArray[String]
} derive(Debug, Eq)

///|
pub fn UnboundedProofTask::checked(
  name : String,
  artifact : ArtifactRef,
  tool : FormalTool,
  engine : String,
  induction : InductionMethod,
  assumptions : ArrayView[String],
  properties : ArrayView[String],
) -> UnboundedProofTask raise FormalError {
  require_nonempty("task name", name)
  require_nonempty("engine", engine)
  validate_induction(induction)
  let checked_assumptions = canonical_names(AssumptionName, assumptions)
  let checked_properties = canonical_names(PropertyName, properties)
  validate_name_roles(checked_assumptions, checked_properties)
  {
    name,
    artifact,
    tool,
    engine,
    induction,
    assumptions: checked_assumptions,
    properties: checked_properties,
  }
}

///|
pub fn UnboundedProofTask::name(self : UnboundedProofTask) -> String {
  self.name
}

///|
pub fn UnboundedProofTask::artifact(self : UnboundedProofTask) -> ArtifactRef {
  self.artifact
}

///|
pub fn UnboundedProofTask::tool(self : UnboundedProofTask) -> FormalTool {
  self.tool
}

///|
pub fn UnboundedProofTask::engine(self : UnboundedProofTask) -> String {
  self.engine
}

///|
pub fn UnboundedProofTask::induction(
  self : UnboundedProofTask,
) -> InductionMethod {
  self.induction
}

///|
pub fn UnboundedProofTask::assumptions(
  self : UnboundedProofTask,
) -> ReadOnlyArray[String] {
  self.assumptions
}

///|
pub fn UnboundedProofTask::properties(
  self : UnboundedProofTask,
) -> ReadOnlyArray[String] {
  self.properties
}

///|
/// Parsed task manifests retain whether their evidence is bounded or capable
/// of an unbounded proof.
pub(all) enum ProofTaskManifest {
  Bounded(BoundedProofTask)
  Unbounded(UnboundedProofTask)
} derive(Debug, Eq)
