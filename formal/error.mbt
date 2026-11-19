///|
/// Stable failures raised while constructing or decoding formal artifacts.
pub(all) suberror FormalError {
  EmptyField(String)
  InvalidDigestLength(role~ : DigestRole, length~ : Int32)
  InvalidDigestSymbol(role~ : DigestRole, index~ : Int32, symbol~ : UInt16)
  InvalidSystemVerilogIdentifier(String)
  InvalidPropertySignal(@property.PropertySignal)
  DuplicateSignalBinding(@property.PropertySignal)
  DuplicateBoundIdentifier(String)
  MissingSignalBinding(@property.PropertySignal)
  DuplicatePropertyId(Int32)
  DuplicatePropertyName(String)
  DuplicateStablePropertyName(String)
  StablePropertyNameMismatch(expected~ : String, actual~ : String)
  EmptyPropertySet
  DuplicateManifestName(kind~ : ManifestNameKind, name~ : String)
  NameUsedAsAssumptionAndProperty(String)
  InvalidBound(Int32)
  InvalidInductionDepth(Int32)
  InvalidGlobalFormalTimestep(Int32)
  EmptyFormalClockSet
  InvalidFormalClockSignal(@property.PropertySignal)
  DuplicateFormalClockDomain(Int32)
  DuplicateFormalClockSignal(@property.PropertySignal)
  InvalidFormalClockDomainId(Int32)
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
  InvalidCanonicalLine(line~ : Int32, expected~ : String, actual~ : String)
  InvalidCanonicalInteger(line~ : Int32, field~ : String, value~ : String)
  InvalidCanonicalText(line~ : Int32, value~ : String)
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

///|
pub extend FormalError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FormalError with Eq::{not_equal, equal}

///|
pub extend DigestRole with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend DigestRole with Eq::{not_equal, equal}

///|
pub extend ManifestNameKind with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ManifestNameKind with Eq::{not_equal, equal}
