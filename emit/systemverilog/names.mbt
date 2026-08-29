///|
fn padded_hex(value : Int, digits : Int) -> String {
  value.to_string(radix=16).pad_start(digits, '0')
}

///|
/// Encode every canonical UTF-8 byte, including ASCII underscores. Unlike lossy
/// sanitization this is injective, so Unicode and spelling-like encodings can
/// never collide. Role and canonical ordinals make every final identifier
/// collision-free even when source names repeat across namespaces.
fn encoded_source_name(name : String) -> String {
  let out = StringBuilder()
  for byte in @utf8.encode(name) {
    out.write_string("_b")
    out.write_string(padded_hex(byte.to_int(), 2))
  }
  out.to_string()
}

///|
fn module_identifier(module_ordinal : Int, name : String) -> String {
  "lc_m\{module_ordinal}\{encoded_source_name(name)}"
}

///|
fn node_identifier(node_ordinal : Int) -> String {
  "lc_n\{node_ordinal}"
}

///|
fn input_identifier(node_ordinal : Int, name : String) -> String {
  "lc_i\{node_ordinal}\{encoded_source_name(name)}"
}

///|
fn output_identifier(output_ordinal : Int, name : String) -> String {
  "lc_o\{output_ordinal}\{encoded_source_name(name)}"
}

///|
fn helper_identifier(operation : String, width : Int) -> String {
  "lc_fn_\{operation}_w\{width}"
}

///|
fn source_name_hex(name : String) -> String {
  if name.is_empty() {
    return "-"
  }
  let parts : Array[String] = []
  for byte in @utf8.encode(name) {
    parts.push(padded_hex(byte.to_int(), 2))
  }
  parts.join("_")
}

///|
fn symbol_kind_text(kind : SymbolKind) -> String {
  match kind {
    Module => "module"
    Node => "node"
    InputPort => "input"
    OutputPort => "output"
  }
}

///|
/// Serialize the mapping without embedding unescaped source text. Source names
/// are canonical UTF-8 bytes in lower-case hexadecimal and round-trip exactly.
pub fn NameManifest::to_canonical_text(self : NameManifest) -> String {
  let out = StringBuilder()
  out.write_string("LUNACHIP-SYSTEMVERILOG-NAMES 1\n")
  out.write_string("TOP \{self.top_module_ordinal}\n")
  out.write_string(
    "REGISTER-INITIALIZATION implicit-four-state-x-reject-explicit\n",
  )
  for mapping in self.mappings {
    out.write_string(
      "MAP \{symbol_kind_text(mapping.kind())} \{mapping.module_ordinal()} \{mapping.local_ordinal()} \{source_name_hex(mapping.source_name())} \{mapping.identifier()}\n",
    )
  }
  out.write_string("END\n")
  out.to_string()
}
