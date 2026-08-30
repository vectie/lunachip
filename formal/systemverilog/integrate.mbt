///|
fn sha256_hex(text : String) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode(text)))
}

///|
fn hex_digit(value : Int) -> Char {
  match value {
    0 => '0'
    1 => '1'
    2 => '2'
    3 => '3'
    4 => '4'
    5 => '5'
    6 => '6'
    7 => '7'
    8 => '8'
    9 => '9'
    10 => 'a'
    11 => 'b'
    12 => 'c'
    13 => 'd'
    14 => 'e'
    _ => 'f'
  }
}

///|
fn utf8_hex(text : String) -> String {
  let output = StringBuilder()
  for byte in @utf8.encode(text) {
    let value = byte.to_int()
    output.write_char(hex_digit(value >> 4))
    output.write_char(hex_digit(value & 15))
  }
  output.to_string()
}

///|
fn splice_property_source(
  module_source : String,
  property_source : String,
) -> String raise IntegrationError {
  let parts = module_source
    .split("\nendmodule\n")
    .map(part => part.to_owned())
    .to_array()
  match parts.length() {
    1 => raise MissingEndmodule
    2 => "\{parts[0]}\n\n\{property_source}endmodule\n\{parts[1]}"
    _ => raise MultipleEndmodule
  }
}

///|
fn formalized_module(
  artifact : @rtl.EmittedModule,
  source : String,
) -> FormalizedModule {
  {
    module_ordinal: artifact.module_ordinal(),
    identifier: artifact.identifier(),
    filename: artifact.filename(),
    source,
    sha256: sha256_hex(source),
  }
}

///|
fn build_source_set_identity(
  top_path : TopModulePath,
  top_ordinal : Int,
  modules : ReadOnlyArray[FormalizedModule],
  canonical_ir_sha256 : String,
  property_manifest_sha256 : String,
  name_manifest_sha256 : String,
) -> String {
  let output = StringBuilder()
  output.write_string("LUNACHIP-FORMAL-SYSTEMVERILOG-SOURCE-SET 1\n")
  output.write_string("TOP \{top_ordinal} \{utf8_hex(top_path.value())}\n")
  output.write_string("CANONICAL-IR sha256 \{canonical_ir_sha256}\n")
  output.write_string("PROPERTY-MANIFEST sha256 \{property_manifest_sha256}\n")
  output.write_string("NAME-MANIFEST sha256 \{name_manifest_sha256}\n")
  output.write_string("MODULES \{modules.length()}\n")
  for ordinal, hardware_module in modules {
    output.write_string(
      "M \{ordinal} \{hardware_module.module_ordinal()} \{utf8_hex(hardware_module.identifier())} \{utf8_hex(hardware_module.filename())} sha256 \{hardware_module.sha256()}\n",
    )
  }
  output.write_string("END\n")
  output.to_string()
}

///|
/// Integrate a formal plan into the exact emitted top-module artifact.
///
/// Every property signal is resolved through `derive_bindings`. The snippet is
/// inserted before the one exact `endmodule` line in the top module; all other
/// module bytes are preserved. The result records both the exact top-file hash
/// and a source-set hash binding every filename/module digest plus the property
/// manifest digest.
pub fn integrate(
  design : @ir.Design,
  emitted : @rtl.EmittedDesign,
  top_path : TopModulePath,
  plan : @formal.FormalPropertyPlan,
) -> FormalizedDesign raise IntegrationError {
  @cdc.validate_design(design) catch {
    error => raise CdcRejected(error)
  }
  require_exact_top_path(design, top_path)
  let canonical_emission = @rtl.emit_design(design) catch {
    error => raise EmissionFailed(error)
  }
  if emitted != canonical_emission {
    raise EmittedDesignMismatch
  }
  let top_ordinal = validate_emission_alignment(design, emitted)
  let bindings = derive_bindings(design, emitted, top_path, plan)
  let property_export = @formal.export_properties(plan, bindings) catch {
    error => raise FormalContract(error)
  }
  let modules : Array[FormalizedModule] = []
  for ordinal in 0..<design.modules().length() {
    let artifact = emitted_module(emitted, ordinal)
    let source = if ordinal == top_ordinal {
      splice_property_source(artifact.source(), property_export.source())
    } else {
      artifact.source()
    }
    modules.push(formalized_module(artifact, source))
  }
  let frozen_modules = ReadOnlyArray::from_array(modules)
  let canonical_ir_sha256 = sha256_hex(@codec.serialize(design))
  let property_manifest_sha256 = sha256_hex(property_export.manifest())
  let name_manifest_sha256 = sha256_hex(emitted.manifest().to_canonical_text())
  let source_set_identity = build_source_set_identity(
    top_path, top_ordinal, frozen_modules, canonical_ir_sha256, property_manifest_sha256,
    name_manifest_sha256,
  )
  let top_module = frozen_modules[top_ordinal]
  let top_artifact = @formal.ArtifactRef::checked(
    top_module.filename(),
    top_module.sha256(),
  ) catch {
    error => raise FormalContract(error)
  }
  {
    top_path,
    top_module_ordinal: top_ordinal,
    modules: frozen_modules,
    property_export,
    top_artifact,
    source_set_identity,
    source_set_sha256: sha256_hex(source_set_identity),
  }
}
