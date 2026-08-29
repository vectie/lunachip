///|
/// Exact canonical path of the design's top module.
pub struct TopModulePath(String) derive(Debug, Eq)

///|
/// Construct a top path only when it exactly matches the canonical design top.
pub fn TopModulePath::checked(
  design : @ir.Design,
  path : String,
) -> TopModulePath raise IntegrationError {
  if path.is_empty() {
    raise EmptyTopModulePath
  }
  if path != design.top_name() {
    raise TopModulePathMismatch(expected=design.top_name(), actual=path)
  }
  TopModulePath(path)
}

///|
pub fn TopModulePath::value(self : TopModulePath) -> String {
  let TopModulePath(path) = self
  path
}

///|
/// One emitted module after property integration. Non-top modules retain their
/// exact original bytes; the top module contains the inserted formal snippet.
pub struct FormalizedModule {
  module_ordinal : Int
  identifier : String
  filename : String
  source : String
  sha256 : String
} derive(Debug, Eq)

///|
pub fn FormalizedModule::module_ordinal(self : FormalizedModule) -> Int {
  self.module_ordinal
}

///|
pub fn FormalizedModule::identifier(self : FormalizedModule) -> String {
  self.identifier
}

///|
pub fn FormalizedModule::filename(self : FormalizedModule) -> String {
  self.filename
}

///|
pub fn FormalizedModule::source(self : FormalizedModule) -> String {
  self.source
}

///|
pub fn FormalizedModule::sha256(self : FormalizedModule) -> String {
  self.sha256
}

///|
/// Content-addressed formal SystemVerilog source set.
pub struct FormalizedDesign {
  top_path : TopModulePath
  top_module_ordinal : Int
  modules : ReadOnlyArray[FormalizedModule]
  property_export : @formal.FormalExport
  top_artifact : @formal.ArtifactRef
  source_set_identity : String
  source_set_sha256 : String
} derive(Debug, Eq)

///|
pub fn FormalizedDesign::top_path(self : FormalizedDesign) -> TopModulePath {
  self.top_path
}

///|
pub fn FormalizedDesign::top_module_ordinal(self : FormalizedDesign) -> Int {
  self.top_module_ordinal
}

///|
pub fn FormalizedDesign::modules(
  self : FormalizedDesign,
) -> ReadOnlyArray[FormalizedModule] {
  self.modules
}

///|
pub fn FormalizedDesign::top_module(
  self : FormalizedDesign,
) -> FormalizedModule {
  self.modules[self.top_module_ordinal]
}

///|
pub fn FormalizedDesign::property_export(
  self : FormalizedDesign,
) -> @formal.FormalExport {
  self.property_export
}

///|
/// Exact content identity of the formalized top `.sv` file.
pub fn FormalizedDesign::top_artifact(
  self : FormalizedDesign,
) -> @formal.ArtifactRef {
  self.top_artifact
}

///|
/// Canonical identity text binding every formalized module filename and digest.
pub fn FormalizedDesign::source_set_identity(self : FormalizedDesign) -> String {
  self.source_set_identity
}

///|
pub fn FormalizedDesign::source_set_sha256(self : FormalizedDesign) -> String {
  self.source_set_sha256
}

///|
/// Construct a proof target for an archived source-set identity artifact.
pub fn FormalizedDesign::source_set_artifact(
  self : FormalizedDesign,
  logical_name : String,
) -> @formal.ArtifactRef raise @formal.FormalError {
  @formal.ArtifactRef::checked(logical_name, self.source_set_sha256)
}
