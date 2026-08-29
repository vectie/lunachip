///|
/// Checked failures raised while constructing canonical differential artifacts.
pub(all) suberror DifferentialError {
  EmptySemanticVersion
  InvalidDigestLength(kind~ : DigestKind, length~ : Int)
  InvalidDigestSymbol(kind~ : DigestKind, index~ : Int, symbol~ : UInt16)
  EmptyValue
  InvalidValueSymbol(index~ : Int, symbol~ : Char)
  PlaneWidthMismatch(bits~ : Int, known~ : Int)
  InvalidPlaneSymbol(plane~ : String, index~ : Int, symbol~ : UInt16)
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
  NonMonotonicObservationCycle(index~ : Int)
  NonMonotonicStimulus(index~ : Int)
  InconsistentEventCycle(index~ : Int)
  DriveAfterBoundary(index~ : Int)
  DuplicateDrive(event~ : UInt64, cycle~ : UInt64, tap~ : String)
  DuplicateEdge(event~ : UInt64, cycle~ : UInt64, domain~ : String)
  DuplicateSample(event~ : UInt64, cycle~ : UInt64, tap~ : String)
  NonCanonicalDriveOrder(index~ : Int)
  InputDoesNotFail
  InvalidCanonicalLine(line~ : Int, expected~ : String, actual~ : String)
  InvalidCanonicalInteger(line~ : Int, field~ : String, value~ : String)
  InvalidCanonicalText(line~ : Int, value~ : String)
  UnsupportedCanonicalVersion(version~ : String)
  NonCanonicalArtifact
} derive(Debug, Eq)
