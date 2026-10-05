///|
/// Failures raised when canonical IR cannot be represented by the conservative
/// LunaChip SystemVerilog subset without changing its semantics.
pub(all) suberror EmitError {
  CdcRejected(@cdc.CdcError)
  MissingTopModule(String)
  UnsupportedExplicitRegisterInitial(
    module_name~ : String,
    node~ : Int,
    value~ : UInt64
  )
  DuplicateEmittedIdentifier(module_name~ : String, identifier~ : String)
  InvalidNodeReference(module_name~ : String, node~ : Int)
  InvalidMemoryReference(module_name~ : String, memory~ : Int)
  UnreachableNode(module_name~ : String, node~ : Int)
} derive(Debug, Eq)

///|
/// The semantic role of one emitted-name mapping.
pub(all) enum SymbolKind {
  Module
  Node
  InputPort
  OutputPort
  Memory
  AsyncFifoLane
} derive(Debug, Eq)

///|
/// A stable mapping from a canonical IR identity to one SystemVerilog name.
/// `local_ordinal` is `-1` for a module, a NodeId for nodes and input ports,
/// the canonical output-array index for output ports, a MemoryId for memory,
/// and the owning AsyncFifoRead NodeId for an asynchronous-FIFO lane.
pub struct NameMapping {
  kind : SymbolKind
  module_ordinal : Int
  local_ordinal : Int
  source_name : String
  identifier : String
} derive(Debug, Eq)

///|
pub fn NameMapping::kind(self : NameMapping) -> SymbolKind {
  self.kind
}

///|
pub fn NameMapping::module_ordinal(self : NameMapping) -> Int {
  self.module_ordinal
}

///|
pub fn NameMapping::local_ordinal(self : NameMapping) -> Int {
  self.local_ordinal
}

///|
pub fn NameMapping::source_name(self : NameMapping) -> String {
  self.source_name
}

///|
pub fn NameMapping::identifier(self : NameMapping) -> String {
  self.identifier
}

///|
/// The backend policy for canonical registers without a reset or initial
/// value. Declaration initialization is intentionally omitted, so a four-state
/// simulator observes X while synthesis remains target-independent. Explicit
/// IR initial values are rejected rather than silently discarded.
pub(all) enum RegisterInitializationPolicy {
  ImplicitFourStateXRejectExplicitInitial
} derive(Debug, Eq)

///|
/// Canonical name/source manifest accompanying emitted RTL.
pub struct NameManifest {
  top_module_ordinal : Int
  mappings : ReadOnlyArray[NameMapping]
  initialization_policy : RegisterInitializationPolicy
} derive(Debug, Eq)

///|
pub fn NameManifest::top_module_ordinal(self : NameManifest) -> Int {
  self.top_module_ordinal
}

///|
pub fn NameManifest::mappings(
  self : NameManifest,
) -> ReadOnlyArray[NameMapping] {
  self.mappings
}

///|
pub fn NameManifest::initialization_policy(
  self : NameManifest,
) -> RegisterInitializationPolicy {
  self.initialization_policy
}

///|
/// One lintable file containing exactly one canonical module.
pub struct EmittedModule {
  module_ordinal : Int
  identifier : String
  filename : String
  source : String
} derive(Debug, Eq)

///|
pub fn EmittedModule::module_ordinal(self : EmittedModule) -> Int {
  self.module_ordinal
}

///|
pub fn EmittedModule::identifier(self : EmittedModule) -> String {
  self.identifier
}

///|
pub fn EmittedModule::filename(self : EmittedModule) -> String {
  self.filename
}

///|
pub fn EmittedModule::source(self : EmittedModule) -> String {
  self.source
}

///|
/// Byte-stable SystemVerilog and its canonical emitted-name manifest.
/// `modules` is the strict-lint interface: every artifact contains exactly one
/// module and its filename matches the emitted module identifier. `source` is
/// a deterministic concatenated convenience view.
pub struct EmittedDesign {
  source : String
  modules : ReadOnlyArray[EmittedModule]
  manifest : NameManifest
} derive(Debug, Eq)

///|
pub fn EmittedDesign::source(self : EmittedDesign) -> String {
  self.source
}

///|
pub fn EmittedDesign::modules(
  self : EmittedDesign,
) -> ReadOnlyArray[EmittedModule] {
  self.modules
}

///|
pub fn EmittedDesign::manifest(self : EmittedDesign) -> NameManifest {
  self.manifest
}

///|
pub extend EmitError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend EmitError with Eq::{not_equal, equal}

///|
pub extend SymbolKind with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend SymbolKind with Eq::{not_equal, equal}

///|
pub extend NameMapping with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend NameMapping with Eq::{not_equal, equal}

///|
pub extend RegisterInitializationPolicy with @moonbitlang/core/debug.Debug::{
  to_repr,
}

///|
pub extend RegisterInitializationPolicy with Eq::{not_equal, equal}

///|
pub extend NameManifest with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend NameManifest with Eq::{not_equal, equal}

///|
pub extend EmittedModule with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend EmittedModule with Eq::{not_equal, equal}

///|
pub extend EmittedDesign with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend EmittedDesign with Eq::{not_equal, equal}
