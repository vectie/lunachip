///|
pub(all) enum PortDirection {
  Input
  Output
} derive(Debug, Eq)

///|
pub(all) struct HarnessPort {
  source_name : String
  emitted_name : String
  direction : PortDirection
  width : Int32
  signal_type : @ir.SignalType
} derive(Debug, Eq)

///|
pub(all) suberror HarnessError {
  MissingEmittedTopModule
  MissingPortMapping(kind~ : String, ordinal~ : Int32)
  MissingClockPort
  MultipleClockPorts
  MissingResetPort
  MultipleResetPorts
  UnsupportedPortWidth(name~ : String, width~ : Int32)
  InvalidAtomicResultPrefix(reason~ : String)
  InvalidAtomicHarnessFilename(String)
  MissingAtomicStimulusPort(String)
  AtomicStimulusPortWidthMismatch(
    name~ : String,
    expected~ : Int32,
    actual~ : Int32
  )
  InvalidAtomicStimulusClockPort(String)
  AtomicPortSignalWidthMismatch(name~ : String, port~ : Int32, signal~ : Int32)
  DuplicateAtomicPortName(String)
  MissingAtomicClockDomain(String)
  InvalidAtomicOutputName(String)
  DuplicateAtomicOutputName(String)
  InvalidResultTsv(reason~ : String, row~ : Int32)
} derive(Debug, Eq)

///|
/// Selects whether all active clocks in one schema-v2 event are evaluated as
/// one atomic batch or deliberately split for a negative bridge fixture.
pub(all) enum AtomicHarnessEdgeMode {
  AtomicEdges
  SequentialEdges
} derive(Debug, Eq)

///|
/// Checked failures in the versioned Verilator stimulus boundary. These stay
/// distinct from simulator and replay errors because the external harness is
/// an independently versioned interoperability contract.
pub(all) suberror StimulusContractError {
  InvalidStimulusIdentifier(kind~ : String, name~ : String)
  InvalidStimulusTimebase(UInt64)
  EmptyStimulusDomains
  InvalidStimulusDomainId(Int32)
  DuplicateStimulusDomainId(Int32)
  NonCanonicalStimulusDomainOrder(previous~ : Int32, actual~ : Int32)
  DuplicateStimulusClockPort(String)
  EmptyAtomicStimulusEvent
  DuplicateAtomicStimulusDrive(String)
  DuplicateAtomicStimulusDomain(Int32)
  UnknownAtomicStimulusDomain(Int32)
  NonMonotonicAtomicStimulusTime(previous~ : UInt64, actual~ : UInt64)
  NonMonotonicAtomicStimulusBoundary(previous~ : UInt64, actual~ : UInt64)
  UnknownVerilatorStimulusValue(name~ : String)
  InvalidStimulusLine(line~ : Int32, expected~ : String, actual~ : String)
  InvalidStimulusInteger(line~ : Int32, field~ : String, value~ : String)
  UnsupportedStimulusVersion(String)
  NonCanonicalStimulus
} derive(Debug, Eq)

///|
pub struct ResultProtocol {
  magic : String
  version : String
  semantic_version : String
} derive(Debug, Eq)

///|
pub fn ResultProtocol::checked(
  magic : String,
  version : String,
  semantic_version : String,
) -> ResultProtocol raise HarnessError {
  if magic.length() == 0 || magic.contains("\t") || magic.contains("\n") {
    raise InvalidResultTsv(reason="invalid protocol magic", row=0)
  }
  if version.length() == 0 || version.contains("\t") || version.contains("\n") {
    raise InvalidResultTsv(reason="invalid protocol version", row=0)
  }
  if semantic_version.length() == 0 {
    raise InvalidResultTsv(reason="empty semantic version", row=0)
  }
  { magic, version, semantic_version, }
}

///|
pub fn ResultProtocol::magic(self : ResultProtocol) -> String {
  self.magic
}

///|
pub fn ResultProtocol::version(self : ResultProtocol) -> String {
  self.version
}

///|
pub fn ResultProtocol::semantic_version(self : ResultProtocol) -> String {
  self.semantic_version
}

///|
pub extend PortDirection with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend PortDirection with Eq::{not_equal, equal}

///|
pub extend HarnessPort with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend HarnessPort with Eq::{not_equal, equal}

///|
pub extend HarnessError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend HarnessError with Eq::{not_equal, equal}

///|
pub extend AtomicHarnessEdgeMode with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AtomicHarnessEdgeMode with Eq::{not_equal, equal}

///|
pub extend StimulusContractError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend StimulusContractError with Eq::{not_equal, equal}

///|
pub extend ResultProtocol with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ResultProtocol with Eq::{not_equal, equal}
