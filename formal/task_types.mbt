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
  { name, sha256, }
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
  { name, version, }
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
/// The semantic role of an assumption label in a multi-clock formal task.
/// The two sets are disjoint so a runner cannot silently reinterpret a legal
/// transition constraint as progress fairness, or vice versa.
pub(all) enum TimingAssumptionKind {
  LegalTransitionAssumption
  FairnessAssumption
} derive(Debug, Eq)

///|
/// A strictly positive number of global formal-engine timesteps.
pub struct GlobalFormalTimestep(Int) derive(Debug, Eq, Compare)

///|
pub fn GlobalFormalTimestep::checked(
  steps : Int,
) -> GlobalFormalTimestep raise FormalError {
  if steps <= 0 {
    raise InvalidGlobalFormalTimestep(steps)
  }
  GlobalFormalTimestep(steps)
}

///|
pub fn GlobalFormalTimestep::steps(self : GlobalFormalTimestep) -> Int {
  let GlobalFormalTimestep(steps) = self
  steps
}

///|
/// The only supported interpretation of clocks that change on the same
/// global formal timestep. Every active edge observes one shared pre-state and
/// commits atomically, matching LunaWave's multi-clock event contract.
pub(all) enum FormalCoincidencePolicy {
  AtomicGlobalPreState
} derive(Debug, Eq)

///|
/// One exact formal-clock binding. Domain identity and hierarchy/node signal
/// identity remain distinct, and the edge is explicit even though the current
/// IR foundation supports rising edges only.
pub struct FormalClockBinding {
  domain : @ir.ClockDomainId
  signal : @property.PropertySignal
  edge : @ir.ClockEdge
} derive(Debug, Eq)

///|
fn validate_formal_clock_signal(
  signal : @property.PropertySignal,
) -> Unit raise FormalError {
  match signal {
    Named(path~, name~) =>
      ignore(
        @property.PropertySignal::named(path, name) catch {
          _ => raise InvalidFormalClockSignal(signal)
        },
      )
    Node(module_path~, node~) =>
      ignore(
        @property.PropertySignal::node(module_path, node) catch {
          _ => raise InvalidFormalClockSignal(signal)
        },
      )
  }
}

///|
pub fn FormalClockBinding::checked(
  domain : @ir.ClockDomainId,
  signal : @property.PropertySignal,
  edge : @ir.ClockEdge,
) -> FormalClockBinding raise FormalError {
  validate_formal_clock_signal(signal)
  { domain, signal, edge, }
}

///|
pub fn FormalClockBinding::domain(
  self : FormalClockBinding,
) -> @ir.ClockDomainId {
  self.domain
}

///|
pub fn FormalClockBinding::signal(
  self : FormalClockBinding,
) -> @property.PropertySignal {
  self.signal
}

///|
pub fn FormalClockBinding::edge(self : FormalClockBinding) -> @ir.ClockEdge {
  self.edge
}

///|
fn canonical_timing_labels(
  kind : TimingAssumptionKind,
  names : ArrayView[String],
) -> ReadOnlyArray[String] raise FormalError {
  let canonical = names.to_owned()
  for name in canonical {
    require_nonempty("timing assumption label", name)
  }
  canonical.sort_by(compare_canonical_text)
  for index, name in canonical {
    if index > 0 && canonical[index - 1] == name {
      raise DuplicateTimingAssumptionLabel(kind~, name~)
    }
  }
  ReadOnlyArray::from_array(canonical)
}

///|
fn canonical_formal_clocks(
  clocks : ArrayView[FormalClockBinding],
) -> ReadOnlyArray[FormalClockBinding] raise FormalError {
  if clocks.is_empty() {
    raise EmptyFormalClockSet
  }
  let canonical = clocks.to_owned()
  for clock in canonical {
    validate_formal_clock_signal(clock.signal())
  }
  canonical.sort_by(fn(left, right) { left.domain().compare(right.domain()) })
  for index, clock in canonical {
    if index > 0 && canonical[index - 1].domain() == clock.domain() {
      raise DuplicateFormalClockDomain(clock.domain().ordinal())
    }
    for prior in 0..<index {
      if canonical[prior].signal() == clock.signal() {
        raise DuplicateFormalClockSignal(clock.signal())
      }
    }
  }
  ReadOnlyArray::from_array(canonical)
}

///|
/// Version-2 multi-clock task timing contract. Assumption labels are stable
/// exported labels, not source property names.
pub struct FormalTimingContract {
  global_timestep : GlobalFormalTimestep
  clocks : ReadOnlyArray[FormalClockBinding]
  legal_transition_assumptions : ReadOnlyArray[String]
  fairness_assumptions : ReadOnlyArray[String]
  coincidence_policy : FormalCoincidencePolicy
} derive(Debug, Eq)

///|
pub fn FormalTimingContract::checked(
  global_timestep : GlobalFormalTimestep,
  clocks : ArrayView[FormalClockBinding],
  legal_transition_assumptions : ArrayView[String],
  fairness_assumptions : ArrayView[String],
  coincidence_policy : FormalCoincidencePolicy,
) -> FormalTimingContract raise FormalError {
  let checked_clocks = canonical_formal_clocks(clocks)
  let checked_legal = canonical_timing_labels(
    LegalTransitionAssumption,
    legal_transition_assumptions,
  )
  let checked_fairness = canonical_timing_labels(
    FairnessAssumption,
    fairness_assumptions,
  )
  for legal in checked_legal {
    for fairness in checked_fairness {
      if legal == fairness {
        raise TimingAssumptionRoleCollision(legal)
      }
    }
  }
  {
    global_timestep,
    clocks: checked_clocks,
    legal_transition_assumptions: checked_legal,
    fairness_assumptions: checked_fairness,
    coincidence_policy,
  }
}

///|
pub fn FormalTimingContract::global_timestep(
  self : FormalTimingContract,
) -> GlobalFormalTimestep {
  self.global_timestep
}

///|
pub fn FormalTimingContract::clocks(
  self : FormalTimingContract,
) -> ReadOnlyArray[FormalClockBinding] {
  self.clocks
}

///|
pub fn FormalTimingContract::legal_transition_assumptions(
  self : FormalTimingContract,
) -> ReadOnlyArray[String] {
  self.legal_transition_assumptions
}

///|
pub fn FormalTimingContract::fairness_assumptions(
  self : FormalTimingContract,
) -> ReadOnlyArray[String] {
  self.fairness_assumptions
}

///|
pub fn FormalTimingContract::coincidence_policy(
  self : FormalTimingContract,
) -> FormalCoincidencePolicy {
  self.coincidence_policy
}

///|
fn validate_timing_label_set_in_task(
  kind : TimingAssumptionKind,
  labels : ReadOnlyArray[String],
  assumptions : ReadOnlyArray[String],
) -> Unit raise FormalError {
  for label in labels {
    let mut found = false
    for assumption in assumptions {
      if label == assumption {
        found = true
      }
    }
    if !found {
      raise UnknownTimingAssumptionLabel(kind~, name=label)
    }
  }
}

///|
fn validate_timing_labels_in_task(
  contract : FormalTimingContract,
  assumptions : ReadOnlyArray[String],
) -> Unit raise FormalError {
  validate_timing_label_set_in_task(
    LegalTransitionAssumption,
    contract.legal_transition_assumptions(),
    assumptions,
  )
  validate_timing_label_set_in_task(
    FairnessAssumption,
    contract.fairness_assumptions(),
    assumptions,
  )
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
  timing_contract : FormalTimingContract?
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
    timing_contract: None,
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
pub fn BoundedProofTask::with_timing_contract(
  self : BoundedProofTask,
  timing_contract : FormalTimingContract,
) -> BoundedProofTask raise FormalError {
  validate_timing_labels_in_task(timing_contract, self.assumptions)
  { ..self, timing_contract: Some(timing_contract), }
}

///|
pub fn BoundedProofTask::timing_contract(
  self : BoundedProofTask,
) -> FormalTimingContract? {
  self.timing_contract
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
  timing_contract : FormalTimingContract?
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
    timing_contract: None,
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
pub fn UnboundedProofTask::with_timing_contract(
  self : UnboundedProofTask,
  timing_contract : FormalTimingContract,
) -> UnboundedProofTask raise FormalError {
  validate_timing_labels_in_task(timing_contract, self.assumptions)
  { ..self, timing_contract: Some(timing_contract), }
}

///|
pub fn UnboundedProofTask::timing_contract(
  self : UnboundedProofTask,
) -> FormalTimingContract? {
  self.timing_contract
}

///|
/// Parsed task manifests retain whether their evidence is bounded or capable
/// of an unbounded proof.
pub(all) enum ProofTaskManifest {
  Bounded(BoundedProofTask)
  Unbounded(UnboundedProofTask)
} derive(Debug, Eq)

///|
pub extend ArtifactRef with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ArtifactRef with Eq::{not_equal, equal}

///|
pub extend FormalTool with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FormalTool with Eq::{not_equal, equal}

///|
pub extend BoundedMode with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend BoundedMode with Eq::{not_equal, equal}

///|
pub extend ProofBound with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ProofBound with Eq::{not_equal, equal}

///|
pub extend ProofBound with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend InductionMethod with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend InductionMethod with Eq::{not_equal, equal}

///|
pub extend TimingAssumptionKind with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend TimingAssumptionKind with Eq::{not_equal, equal}

///|
pub extend GlobalFormalTimestep with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend GlobalFormalTimestep with Eq::{not_equal, equal}

///|
pub extend GlobalFormalTimestep with Compare::{
  op_lt,
  op_le,
  op_ge,
  compare,
  op_gt,
}

///|
pub extend FormalCoincidencePolicy with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FormalCoincidencePolicy with Eq::{not_equal, equal}

///|
pub extend FormalClockBinding with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FormalClockBinding with Eq::{not_equal, equal}

///|
pub extend FormalTimingContract with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FormalTimingContract with Eq::{not_equal, equal}

///|
pub extend BoundedProofTask with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend BoundedProofTask with Eq::{not_equal, equal}

///|
pub extend UnboundedProofTask with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend UnboundedProofTask with Eq::{not_equal, equal}

///|
pub extend ProofTaskManifest with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ProofTaskManifest with Eq::{not_equal, equal}
