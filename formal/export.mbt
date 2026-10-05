///|
/// One canonical mapping in a formal-property export.
pub struct ExportedProperty {
  id : @property.PropertyId
  source_name : String
  stable_name : String
  kind : FormalPropertyKind
} derive(Debug, Eq)

///|
pub fn ExportedProperty::id(self : ExportedProperty) -> @property.PropertyId {
  self.id
}

///|
pub fn ExportedProperty::source_name(self : ExportedProperty) -> String {
  self.source_name
}

///|
pub fn ExportedProperty::stable_name(self : ExportedProperty) -> String {
  self.stable_name
}

///|
pub fn ExportedProperty::kind(self : ExportedProperty) -> FormalPropertyKind {
  self.kind
}

///|
/// A deterministic property snippet intended for insertion immediately before
/// the containing module's `endmodule`, plus its canonical manifest.
pub struct FormalExport {
  source : String
  property_manifest : FormalPropertyManifest
  properties : ReadOnlyArray[ExportedProperty]
} derive(Debug, Eq)

///|
pub fn FormalExport::source(self : FormalExport) -> String {
  self.source
}

///|
pub fn FormalExport::manifest(self : FormalExport) -> String {
  self.property_manifest.to_canonical_text()
}

///|
pub fn FormalExport::property_manifest(
  self : FormalExport,
) -> FormalPropertyManifest {
  self.property_manifest
}

///|
pub fn FormalExport::properties(
  self : FormalExport,
) -> ReadOnlyArray[ExportedProperty] {
  self.properties
}

///|
fn formal_kind_text(kind : FormalPropertyKind) -> String {
  match kind {
    Assertion => "assert"
    Assumption => "assume"
    Cover => "cover"
  }
}

///|
fn signal_manifest_text(signal : @property.PropertySignal) -> String {
  match signal {
    Named(path~, name~) => "named \{encode_text(path)} \{encode_text(name)}"
    Node(module_path~, node~) =>
      "node \{encode_text(module_path)} \{node.ordinal()}"
  }
}

///|
fn disable_source(
  disable : DisableBehavior,
  bindings : ArrayView[FormalSignalBinding],
) -> String raise FormalError {
  match disable {
    NeverDisabled => ""
    WhenKnownHighAsynchronous(signal) => {
      let identifier = resolve_binding(bindings, signal)
      " disable iff ((\{identifier}) === 1'b1)"
    }
  }
}

///|
fn disable_manifest_text(disable : DisableBehavior) -> String {
  match disable {
    NeverDisabled => "never"
    WhenKnownHighAsynchronous(signal) =>
      "known-high-asynchronous \{signal_manifest_text(signal)}"
  }
}

///|
/// Export assertion, assumption, and cover properties with stable labels.
///
/// Predicates pass or hit only when case-equal to known one. A disable signal
/// suppresses a property only when case-equal to known one, so unknown does not
/// silently disable checking. Every signal is resolved from an explicit
/// canonical binding; there is no name guessing.
pub fn export_properties(
  plan : FormalPropertyPlan,
  bindings : ArrayView[FormalSignalBinding],
) -> FormalExport raise FormalError {
  validate_bindings(bindings)
  let source = StringBuilder()
  let exported : Array[ExportedProperty] = []
  source.write_string("`ifdef FORMAL\n")
  source.write_string(
    "  // LunaChip formal semantics: rising-pre-edge; known-high asynchronous disable.\n",
  )
  for property in plan.properties() {
    let stable_name = property_identifier(property)
    for previous in exported {
      if previous.stable_name() == stable_name {
        raise DuplicateStablePropertyName(stable_name)
      }
    }
    let clock = resolve_binding(bindings, property.domain().clock())
    let predicate = resolve_binding(bindings, property.predicate())
    let operation = formal_kind_text(property.kind())
    source.write_string(
      "  \{stable_name}: \{operation} property (@(posedge \{clock})\{disable_source(property.disable(), bindings)} ((\{predicate}) === 1'b1));\n",
    )
    exported.push({
      id: property.id(),
      source_name: property.name(),
      stable_name,
      kind: property.kind(),
    })
  }
  source.write_string("`endif\n")
  {
    source: source.to_string(),
    property_manifest: FormalPropertyManifest::from_plan(plan),
    properties: ReadOnlyArray::from_array(exported),
  }
}

///|
pub extend ExportedProperty with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ExportedProperty with Eq::{not_equal, equal}

///|
pub extend FormalExport with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FormalExport with Eq::{not_equal, equal}

///|
/// Export the same typed property plan using the clocked immediate syntax
/// accepted by the locked Phase 4 Yosys frontend.
///
/// These are single-point predicates, so testing the known-high disable at the
/// observation edge has the same sampled truth as the concurrent export. The
/// manifest deliberately remains unchanged: task identity binds the property
/// contract, while source-set identity binds this concrete backend rendering.
pub fn export_yosys_clocked_properties(
  plan : FormalPropertyPlan,
  bindings : ArrayView[FormalSignalBinding],
) -> FormalExport raise FormalError {
  validate_bindings(bindings)
  let source = StringBuilder()
  let exported : Array[ExportedProperty] = []
  source.write_string("`ifdef FORMAL\n")
  source.write_string(
    "  // LunaChip/Yosys formal semantics: rising-pre-edge; known-high sampled disable.\n",
  )
  for property in plan.properties() {
    let stable_name = property_identifier(property)
    for previous in exported {
      if previous.stable_name() == stable_name {
        raise DuplicateStablePropertyName(stable_name)
      }
    }
    let clock = resolve_binding(bindings, property.domain().clock())
    let predicate = resolve_binding(bindings, property.predicate())
    let operation = formal_kind_text(property.kind())
    source.write_string("  always @(posedge \{clock}) begin\n")
    match property.disable() {
      NeverDisabled =>
        source.write_string(
          "    \{stable_name}: \{operation} ((\{predicate}) === 1'b1);\n",
        )
      WhenKnownHighAsynchronous(signal) => {
        let disable = resolve_binding(bindings, signal)
        source.write_string("    if (!((\{disable}) === 1'b1)) begin\n")
        source.write_string(
          "      \{stable_name}: \{operation} ((\{predicate}) === 1'b1);\n",
        )
        source.write_string("    end\n")
      }
    }
    source.write_string("  end\n")
    exported.push({
      id: property.id(),
      source_name: property.name(),
      stable_name,
      kind: property.kind(),
    })
  }
  source.write_string("`endif\n")
  {
    source: source.to_string(),
    property_manifest: FormalPropertyManifest::from_plan(plan),
    properties: ReadOnlyArray::from_array(exported),
  }
}
