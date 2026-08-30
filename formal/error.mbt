///|
/// Stable failures raised while constructing or decoding formal artifacts.
pub(all) suberror FormalError {
  EmptyField(String)
  InvalidDigestLength(role~ : DigestRole, length~ : Int)
  InvalidDigestSymbol(role~ : DigestRole, index~ : Int, symbol~ : UInt16)
  InvalidSystemVerilogIdentifier(String)
  InvalidPropertySignal(@property.PropertySignal)
  DuplicateSignalBinding(@property.PropertySignal)
  DuplicateBoundIdentifier(String)
  MissingSignalBinding(@property.PropertySignal)
  DuplicatePropertyId(Int)
  DuplicatePropertyName(String)
  DuplicateStablePropertyName(String)
  StablePropertyNameMismatch(expected~ : String, actual~ : String)
  EmptyPropertySet
  DuplicateManifestName(kind~ : ManifestNameKind, name~ : String)
  NameUsedAsAssumptionAndProperty(String)
  InvalidBound(Int)
  InvalidInductionDepth(Int)
  InvalidGlobalFormalTimestep(Int)
  EmptyFormalClockSet
  InvalidFormalClockSignal(@property.PropertySignal)
  DuplicateFormalClockDomain(Int)
  DuplicateFormalClockSignal(@property.PropertySignal)
  InvalidFormalClockDomainId(Int)
  UnknownFormalClockEdge(String)
  UnknownCoincidencePolicy(String)
  DuplicateTimingAssumptionLabel(kind~ : TimingAssumptionKind, name~ : String)
  UnknownTimingAssumptionLabel(kind~ : TimingAssumptionKind, name~ : String)
  TimingAssumptionRoleCollision(String)
  InvalidArtifactName(String)
  ResultModeMismatch(mode~ : String, result~ : String)
  UnexpectedResultArtifact(String)
  MissingResultArtifact(String)
  UnexpectedResultDetail
  MissingResultDetail
  InvalidCanonicalLine(line~ : Int, expected~ : String, actual~ : String)
  InvalidCanonicalInteger(line~ : Int, field~ : String, value~ : String)
  InvalidCanonicalText(line~ : Int, value~ : String)
  UnsupportedCanonicalVersion(kind~ : String, version~ : String)
  NonCanonicalArtifact
  TaskDigestMismatch(expected~ : String, actual~ : String)
} derive(Debug, Eq)

///|
/// The semantic role of a SHA-256 value in a formal artifact.
pub(all) enum DigestRole {
  TargetArtifact
  TaskManifest
  CounterexampleArtifact
} derive(Debug, Eq)

///|
/// Namespace used while checking canonical assumption/property name lists.
pub(all) enum ManifestNameKind {
  AssumptionName
  PropertyName
} derive(Debug, Eq)
