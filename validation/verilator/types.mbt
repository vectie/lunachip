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
  width : Int
  signal_type : @ir.SignalType
} derive(Debug, Eq)

///|
pub(all) suberror HarnessError {
  MissingEmittedTopModule
  MissingPortMapping(kind~ : String, ordinal~ : Int)
  MissingClockPort
  MultipleClockPorts
  MissingResetPort
  MultipleResetPorts
  UnsupportedPortWidth(name~ : String, width~ : Int)
  InvalidResultTsv(reason~ : String, row~ : Int)
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
  { magic, version, semantic_version }
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
