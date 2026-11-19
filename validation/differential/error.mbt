///|
/// Checked failures raised while constructing canonical differential artifacts.
pub(all) suberror DifferentialError {
  EmptySemanticVersion
  InvalidDigestLength(kind~ : DigestKind, length~ : Int32)
  InvalidDigestSymbol(kind~ : DigestKind, index~ : Int32, symbol~ : UInt16)
  EmptyValue
  InvalidValueSymbol(index~ : Int32, symbol~ : Char)
  PlaneWidthMismatch(bits~ : Int32, known~ : Int32)
  InvalidPlaneSymbol(plane~ : String, index~ : Int32, symbol~ : UInt16)
  EmptyTap
  EmptyDomain
  DuplicateObservation(
    event~ : UInt64,
    cycle~ : UInt64,
    phase~ : ObservationPhase,
    tap~ : String
  )
  InconsistentObservationEventCycle(
    event~ : UInt64,
    first_cycle~ : UInt64,
    actual_cycle~ : UInt64
  )
  NonMonotonicObservationCycle(index~ : Int32)
  NonMonotonicStimulus(index~ : Int32)
  InconsistentEventCycle(index~ : Int32)
  DriveAfterBoundary(index~ : Int32)
  DuplicateDrive(event~ : UInt64, cycle~ : UInt64, tap~ : String)
  DuplicateEdge(event~ : UInt64, cycle~ : UInt64, domain~ : String)
  DuplicateSample(event~ : UInt64, cycle~ : UInt64, tap~ : String)
  NonCanonicalDriveOrder(index~ : Int32)
  InputDoesNotFail
  InvalidCanonicalLine(line~ : Int32, expected~ : String, actual~ : String)
  InvalidCanonicalInteger(line~ : Int32, field~ : String, value~ : String)
  InvalidCanonicalText(line~ : Int32, value~ : String)
  UnsupportedCanonicalVersion(version~ : String)
  NonCanonicalArtifact
} derive(Debug, Eq)

///|
pub extend DifferentialError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend DifferentialError with Eq::{not_equal, equal}
