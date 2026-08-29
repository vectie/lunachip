///|
fn require_exact_top_path(
  design : @ir.Design,
  top_path : TopModulePath,
) -> Unit raise IntegrationError {
  if top_path.value() != design.top_name() {
    raise TopModulePathMismatch(
      expected=design.top_name(),
      actual=top_path.value(),
    )
  }
}

///|
fn module_mapping(
  manifest : @rtl.NameManifest,
  module_ordinal : Int,
) -> @rtl.NameMapping raise IntegrationError {
  let mut found : @rtl.NameMapping? = None
  for mapping in manifest.mappings() {
    if mapping.kind() is Module && mapping.module_ordinal() == module_ordinal {
      if found is Some(_) {
        raise DuplicateModuleMapping(module_ordinal)
      }
      found = Some(mapping)
    }
  }
  guard found is Some(mapping) else {
    raise MissingModuleMapping(module_ordinal)
  }
  mapping
}

///|
fn emitted_module(
  emitted : @rtl.EmittedDesign,
  module_ordinal : Int,
) -> @rtl.EmittedModule raise IntegrationError {
  let mut found : @rtl.EmittedModule? = None
  for artifact in emitted.modules() {
    if artifact.module_ordinal() == module_ordinal {
      if found is Some(_) {
        raise DuplicateEmittedModule(module_ordinal)
      }
      found = Some(artifact)
    }
  }
  guard found is Some(artifact) else {
    raise MissingEmittedModule(module_ordinal)
  }
  artifact
}

///|
fn validate_emission_alignment(
  design : @ir.Design,
  emitted : @rtl.EmittedDesign,
) -> Int raise IntegrationError {
  if emitted.modules().length() != design.modules().length() {
    raise EmittedModuleCountMismatch(
      expected=design.modules().length(),
      actual=emitted.modules().length(),
    )
  }
  let manifest = emitted.manifest()
  let manifest_module_count = manifest
    .mappings()
    .filter(mapping => mapping.kind() is Module)
    .length()
  if manifest_module_count != design.modules().length() {
    raise ManifestModuleCountMismatch(
      expected=design.modules().length(),
      actual=manifest_module_count,
    )
  }
  let top_ordinal = manifest.top_module_ordinal()
  if top_ordinal < 0 || top_ordinal >= design.modules().length() {
    raise InvalidManifestTopOrdinal(top_ordinal)
  }
  for ordinal, hardware_module in design.modules() {
    let mapping = module_mapping(manifest, ordinal)
    if mapping.local_ordinal() != -1 {
      raise ModuleMappingMismatch(module_ordinal=ordinal, field="local ordinal")
    }
    if mapping.source_name() != hardware_module.name() {
      raise ModuleMappingMismatch(module_ordinal=ordinal, field="source name")
    }
    let artifact = emitted_module(emitted, ordinal)
    if artifact.identifier() != mapping.identifier() {
      raise EmittedModuleMismatch(module_ordinal=ordinal, field="identifier")
    }
    if artifact.filename() != "\{mapping.identifier()}.sv" {
      raise EmittedModuleMismatch(module_ordinal=ordinal, field="filename")
    }
  }
  let top_name = design.modules()[top_ordinal].name()
  if top_name != design.top_name() {
    raise ManifestTopMismatch(expected=design.top_name(), actual=top_name)
  }
  top_ordinal
}

///|
fn signal_path(signal : @property.PropertySignal) -> String {
  match signal {
    Named(path~, ..) => path
    Node(module_path~, ..) => module_path
  }
}

///|
fn node_mapping(
  top_module : @ir.Module,
  manifest : @rtl.NameManifest,
  top_ordinal : Int,
  node_id : @ir.NodeId,
) -> @rtl.NameMapping raise IntegrationError {
  let ordinal = node_id.ordinal()
  guard top_module.node(node_id) is Some(node) else {
    raise UnknownTopNode(ordinal)
  }
  let mut found : @rtl.NameMapping? = None
  for mapping in manifest.mappings() {
    if mapping.kind() is Node &&
      mapping.module_ordinal() == top_ordinal &&
      mapping.local_ordinal() == ordinal {
      if found is Some(_) {
        raise DuplicateNodeMapping(ordinal)
      }
      found = Some(mapping)
    }
  }
  guard found is Some(mapping) else { raise MissingNodeMapping(ordinal) }
  let expected_source = match node.kind() {
    Input(name) => name
    _ => ""
  }
  if mapping.source_name() != expected_source {
    raise InvalidNodeMapping(node=ordinal, field="source name")
  }
  mapping
}

///|
fn named_mapping_kind_text(kind : @rtl.SymbolKind) -> String {
  match kind {
    InputPort => "input"
    OutputPort => "output"
    Module => "module"
    Node => "node"
    Memory => "memory"
  }
}

///|
fn validate_named_mapping(
  top_module : @ir.Module,
  mapping : @rtl.NameMapping,
  name : String,
) -> Unit raise IntegrationError {
  match mapping.kind() {
    InputPort => {
      guard top_module.node(
          @ir.NodeId::new(mapping.local_ordinal()) catch {
            _ =>
              raise InvalidNamedMapping(
                name~,
                kind="input",
                ordinal=mapping.local_ordinal(),
              )
          },
        )
        is Some(node) else {
        raise InvalidNamedMapping(
          name~,
          kind="input",
          ordinal=mapping.local_ordinal(),
        )
      }
      match node.kind() {
        Input(actual) if actual == name => ()
        _ =>
          raise InvalidNamedMapping(
            name~,
            kind="input",
            ordinal=mapping.local_ordinal(),
          )
      }
    }
    OutputPort =>
      match top_module.outputs().get(mapping.local_ordinal()) {
        Some(output) if output.name() == name => ()
        _ =>
          raise InvalidNamedMapping(
            name~,
            kind="output",
            ordinal=mapping.local_ordinal(),
          )
      }
    kind =>
      raise InvalidNamedMapping(
        name~,
        kind=named_mapping_kind_text(kind),
        ordinal=mapping.local_ordinal(),
      )
  }
}

///|
fn named_mapping(
  top_module : @ir.Module,
  manifest : @rtl.NameManifest,
  top_ordinal : Int,
  path : String,
  name : String,
) -> @rtl.NameMapping raise IntegrationError {
  let candidates : Array[@rtl.NameMapping] = []
  for mapping in manifest.mappings() {
    if mapping.module_ordinal() == top_ordinal &&
      (mapping.kind() is InputPort || mapping.kind() is OutputPort) &&
      mapping.source_name() == name {
      validate_named_mapping(top_module, mapping, name)
      candidates.push(mapping)
    }
  }
  match candidates.length() {
    0 => raise MissingNamedSignal(path~, name~)
    1 => candidates[0]
    count => raise AmbiguousNamedSignal(path~, name~, matches=count)
  }
}

///|
fn bind_signal(
  top_module : @ir.Module,
  manifest : @rtl.NameManifest,
  top_ordinal : Int,
  top_path : TopModulePath,
  signal : @property.PropertySignal,
) -> @formal.FormalSignalBinding raise IntegrationError {
  let actual_path = signal_path(signal)
  if actual_path != top_path.value() {
    raise SignalOutsideTopModulePath(
      expected=top_path.value(),
      actual=actual_path,
    )
  }
  let mapping = match signal {
    Node(node=node_id, ..) =>
      node_mapping(top_module, manifest, top_ordinal, node_id)
    Named(path~, name~) =>
      named_mapping(top_module, manifest, top_ordinal, path, name)
  }
  @formal.FormalSignalBinding::checked(signal, mapping.identifier()) catch {
    error => raise FormalContract(error)
  }
}

///|
fn signal_type(
  top_module : @ir.Module,
  manifest : @rtl.NameManifest,
  top_ordinal : Int,
  top_path : TopModulePath,
  signal : @property.PropertySignal,
) -> @ir.SignalType raise IntegrationError {
  let actual_path = signal_path(signal)
  if actual_path != top_path.value() {
    raise SignalOutsideTopModulePath(
      expected=top_path.value(),
      actual=actual_path,
    )
  }
  match signal {
    Node(node=node_id, ..) =>
      match top_module.node(node_id) {
        Some(node) => node.signal_type()
        None => raise UnknownTopNode(node_id.ordinal())
      }
    Named(path~, name~) => {
      let mapping = named_mapping(top_module, manifest, top_ordinal, path, name)
      match mapping.kind() {
        InputPort => {
          let node_id = @ir.NodeId::new(mapping.local_ordinal()) catch {
            _ =>
              raise InvalidNamedMapping(
                name~,
                kind="input",
                ordinal=mapping.local_ordinal(),
              )
          }
          match top_module.node(node_id) {
            Some(node) => node.signal_type()
            None =>
              raise InvalidNamedMapping(
                name~,
                kind="input",
                ordinal=mapping.local_ordinal(),
              )
          }
        }
        OutputPort =>
          match top_module.outputs().get(mapping.local_ordinal()) {
            Some(output) => output.signal_type()
            None =>
              raise InvalidNamedMapping(
                name~,
                kind="output",
                ordinal=mapping.local_ordinal(),
              )
          }
        kind =>
          raise InvalidNamedMapping(
            name~,
            kind=named_mapping_kind_text(kind),
            ordinal=mapping.local_ordinal(),
          )
      }
    }
  }
}

///|
fn validate_plan_signal_types(
  top_module : @ir.Module,
  manifest : @rtl.NameManifest,
  top_ordinal : Int,
  top_path : TopModulePath,
  plan : @formal.FormalPropertyPlan,
) -> Unit raise IntegrationError {
  for item in plan.properties() {
    let clock_type = signal_type(
      top_module,
      manifest,
      top_ordinal,
      top_path,
      item.domain().clock(),
    )
    if !clock_type.is_clock() {
      raise ExpectedClockSignal(item.domain().clock())
    }
    let predicate_type = signal_type(
      top_module,
      manifest,
      top_ordinal,
      top_path,
      item.predicate(),
    )
    if predicate_type.is_clock() || predicate_type.width().bits() != 1 {
      raise ExpectedOneBitSignal(role="predicate", signal=item.predicate())
    }
    match item.disable() {
      NeverDisabled => ()
      WhenKnownHighAsynchronous(signal) => {
        let disable_type = signal_type(
          top_module, manifest, top_ordinal, top_path, signal,
        )
        if disable_type.is_clock() || disable_type.width().bits() != 1 {
          raise ExpectedOneBitSignal(role="disable", signal~)
        }
      }
    }
  }
}

///|
fn append_unique_signal(
  signals : Array[@property.PropertySignal],
  signal : @property.PropertySignal,
) -> Unit {
  if !signals.contains(signal) {
    signals.push(signal)
  }
}

///|
fn required_signals(
  plan : @formal.FormalPropertyPlan,
) -> Array[@property.PropertySignal] {
  let signals : Array[@property.PropertySignal] = []
  for item in plan.properties() {
    append_unique_signal(signals, item.domain().clock())
    append_unique_signal(signals, item.predicate())
    match item.disable() {
      NeverDisabled => ()
      WhenKnownHighAsynchronous(signal) => append_unique_signal(signals, signal)
    }
  }
  signals
}

///|
/// Derive the exact bindings required by a formal plan from canonical IR and
/// the emitted name manifest. Named signals resolve only through declared top
/// input/output mappings; node signals resolve only through their NodeId.
pub fn derive_bindings(
  design : @ir.Design,
  emitted : @rtl.EmittedDesign,
  top_path : TopModulePath,
  plan : @formal.FormalPropertyPlan,
) -> ReadOnlyArray[@formal.FormalSignalBinding] raise IntegrationError {
  require_exact_top_path(design, top_path)
  let top_ordinal = validate_emission_alignment(design, emitted)
  let top_module = design.modules()[top_ordinal]
  validate_plan_signal_types(
    top_module,
    emitted.manifest(),
    top_ordinal,
    top_path,
    plan,
  )
  let bindings : Array[@formal.FormalSignalBinding] = []
  for signal in required_signals(plan) {
    bindings.push(
      bind_signal(top_module, emitted.manifest(), top_ordinal, top_path, signal),
    )
  }
  ReadOnlyArray::from_array(bindings)
}
