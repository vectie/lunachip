///|
/// Checked failures at the formal/SystemVerilog integration boundary.
pub(all) suberror IntegrationError {
  FormalContract(@formal.FormalError)
  EmissionFailed(@rtl.EmitError)
  EmittedDesignMismatch
  EmptyTopModulePath
  TopModulePathMismatch(expected~ : String, actual~ : String)
  EmittedModuleCountMismatch(expected~ : Int, actual~ : Int)
  ManifestModuleCountMismatch(expected~ : Int, actual~ : Int)
  InvalidManifestTopOrdinal(Int)
  ManifestTopMismatch(expected~ : String, actual~ : String)
  MissingModuleMapping(Int)
  DuplicateModuleMapping(Int)
  ModuleMappingMismatch(module_ordinal~ : Int, field~ : String)
  MissingEmittedModule(Int)
  DuplicateEmittedModule(Int)
  EmittedModuleMismatch(module_ordinal~ : Int, field~ : String)
  SignalOutsideTopModulePath(expected~ : String, actual~ : String)
  UnknownTopNode(Int)
  MissingNodeMapping(Int)
  DuplicateNodeMapping(Int)
  InvalidNodeMapping(node~ : Int, field~ : String)
  InvalidNamedMapping(name~ : String, kind~ : String, ordinal~ : Int)
  MissingNamedSignal(path~ : String, name~ : String)
  AmbiguousNamedSignal(path~ : String, name~ : String, matches~ : Int)
  ExpectedClockSignal(@property.PropertySignal)
  ExpectedOneBitSignal(role~ : String, signal~ : @property.PropertySignal)
  MissingEndmodule
  MultipleEndmodule
} derive(Debug, Eq)
