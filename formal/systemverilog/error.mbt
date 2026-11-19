///|
/// Checked failures at the formal/SystemVerilog integration boundary.
pub(all) suberror IntegrationError {
  CdcRejected(@cdc.CdcError)
  FormalContract(@formal.FormalError)
  EmissionFailed(@rtl.EmitError)
  EmittedDesignMismatch
  EmptyTopModulePath
  TopModulePathMismatch(expected~ : String, actual~ : String)
  EmittedModuleCountMismatch(expected~ : Int32, actual~ : Int32)
  ManifestModuleCountMismatch(expected~ : Int32, actual~ : Int32)
  InvalidManifestTopOrdinal(Int32)
  ManifestTopMismatch(expected~ : String, actual~ : String)
  MissingModuleMapping(Int32)
  DuplicateModuleMapping(Int32)
  ModuleMappingMismatch(module_ordinal~ : Int32, field~ : String)
  MissingEmittedModule(Int32)
  DuplicateEmittedModule(Int32)
  EmittedModuleMismatch(module_ordinal~ : Int32, field~ : String)
  SignalOutsideTopModulePath(expected~ : String, actual~ : String)
  UnknownTopNode(Int32)
  MissingNodeMapping(Int32)
  DuplicateNodeMapping(Int32)
  InvalidNodeMapping(node~ : Int32, field~ : String)
  InvalidNamedMapping(name~ : String, kind~ : String, ordinal~ : Int32)
  MissingNamedSignal(path~ : String, name~ : String)
  AmbiguousNamedSignal(path~ : String, name~ : String, matches~ : Int32)
  ExpectedClockSignal(@property.PropertySignal)
  ExpectedOneBitSignal(role~ : String, signal~ : @property.PropertySignal)
  MissingEndmodule
  MultipleEndmodule
} derive(Debug, Eq)

///|
pub extend IntegrationError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend IntegrationError with Eq::{not_equal, equal}
