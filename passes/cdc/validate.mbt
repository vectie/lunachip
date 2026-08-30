///|
fn dependency_is_allowed(
  analysis : CdcNodeAnalysis,
  destination : @ir.ClockDomainId,
) -> Bool {
  if analysis.provenance().has_asynchronous() {
    return false
  }
  for domain in analysis.provenance().domains() {
    if domain != destination {
      return false
    }
  }
  true
}

///|
fn select_minimum(selected : CdcWitness?, candidate : CdcWitness) -> CdcWitness {
  match selected {
    None => candidate
    Some(current) => minimum_witness(current, candidate)
  }
}

///|
fn unsafe_witness(
  analysis : CdcNodeAnalysis,
  destination : @ir.ClockDomainId,
) -> CdcWitness {
  let mut selected = analysis.asynchronous_witness()
  for item in analysis.domain_witnesses() {
    if item.domain() != destination {
      selected = Some(select_minimum(selected, item.witness()))
    }
  }
  match selected {
    Some(item) => item
    None => abort("unsafe provenance unexpectedly had no violating witness")
  }
}

///|
fn any_witness(analysis : CdcNodeAnalysis) -> CdcWitness {
  let mut selected = analysis.asynchronous_witness()
  for item in analysis.domain_witnesses() {
    selected = Some(select_minimum(selected, item.witness()))
  }
  match selected {
    Some(item) => item
    None => abort("non-neutral provenance unexpectedly had no witness")
  }
}

///|
fn append_sink_node(current : CdcWitness, sink : @ir.NodeId) -> CdcWitness {
  extend_witness(current, sink)
}

///|
fn check_dependency(
  hardware_module : @ir.Module,
  analysis : CdcAnalysis,
  source : @ir.NodeId,
  destination : @ir.ClockDomainId,
  sink : CdcSink,
  sink_node? : @ir.NodeId,
) -> Unit raise CdcError {
  let source_analysis = match analysis.node(source) {
    Some(item) => item
    None => abort("validated dependency node unexpectedly absent")
  }
  if !dependency_is_allowed(source_analysis, destination) {
    let found = unsafe_witness(source_analysis, destination)
    let witness = match sink_node {
      Some(node) => append_sink_node(found, node)
      None => found
    }
    raise UnsafeDependency(
      module_name=hardware_module.name(),
      sink~,
      destination~,
      actual=source_analysis.provenance(),
      witness~,
    )
  }
}

///|
fn output_timing(
  hardware_module : @ir.Module,
  name : String,
) -> @ir.OutputTiming? {
  for binding in hardware_module.output_timings() {
    if binding.output() == name {
      return Some(binding.timing())
    }
  }
  None
}

///|
fn output_timing_matches(
  actual : CdcProvenance,
  declared : @ir.OutputTiming,
) -> Bool {
  match declared {
    Static => actual.is_neutral()
    Asynchronous => actual.has_asynchronous() && actual.domains().is_empty()
    ProducedIn(destination) =>
      !actual.has_asynchronous() &&
      actual.domains().length() == 1 &&
      actual.domains()[0] == destination
  }
}

///|
fn validate_outputs(
  hardware_module : @ir.Module,
  analysis : CdcAnalysis,
) -> Unit raise CdcError {
  let explicit = hardware_module.metadata().declares_port_timing()
  for output in hardware_module.outputs() {
    if output.signal_type().is_clock() {
      continue
    }
    let driver = match analysis.node(output.driver()) {
      Some(item) => item
      None => abort("validated output driver unexpectedly absent")
    }
    if explicit {
      let declared = match output_timing(hardware_module, output.name()) {
        Some(item) => item
        None => raise TimingUnavailable(module_name=hardware_module.name())
      }
      if !output_timing_matches(driver.provenance(), declared) {
        raise OutputTimingMismatch(
          module_name=hardware_module.name(),
          output=output.name(),
          declared~,
          actual=driver.provenance(),
          witness=if driver.provenance().is_neutral() {
            None
          } else {
            Some(
              match declared {
                ProducedIn(destination) => unsafe_witness(driver, destination)
                Static | Asynchronous => any_witness(driver)
              },
            )
          },
        )
      }
    } else if hardware_module.domains().length() == 1 {
      let destination = hardware_module.domains()[0].id()
      if !dependency_is_allowed(driver, destination) {
        raise UnsafeDependency(
          module_name=hardware_module.name(),
          sink=Output(output.name()),
          destination~,
          actual=driver.provenance(),
          witness=unsafe_witness(driver, destination),
        )
      }
    } else if !driver.provenance().domains().is_empty() {
      raise OutputTimingMismatch(
        module_name=hardware_module.name(),
        output=output.name(),
        declared=Asynchronous,
        actual=driver.provenance(),
        witness=Some(any_witness(driver)),
      )
    }
  }
}

///|
/// Validate every current state, memory-control, and output sink. No structural
/// pattern or annotation receives a CDC exemption.
pub fn validate_module(hardware_module : @ir.Module) -> Unit raise CdcError {
  let analysis = analyze_module(hardware_module)
  for node in hardware_module.nodes() {
    match node.kind() {
      Register(spec) => {
        let destination = spec.domain().id()
        check_dependency(
          hardware_module,
          analysis,
          spec.next(),
          destination,
          RegisterNext(node.id()),
          sink_node=node.id(),
        )
        match spec.enable() {
          Some(enable) =>
            check_dependency(
              hardware_module,
              analysis,
              enable,
              destination,
              RegisterEnable(node.id()),
              sink_node=node.id(),
            )
          None => ()
        }
        match spec.reset() {
          Some(reset) if reset.mode() is Synchronous =>
            check_dependency(
              hardware_module,
              analysis,
              reset.signal(),
              destination,
              SynchronousReset(node.id()),
              sink_node=node.id(),
            )
          _ => ()
        }
      }
      _ => ()
    }
  }
  for memory in hardware_module.memories() {
    for port in memory.read_ports() {
      let destination = port.domain().id()
      check_dependency(
        hardware_module,
        analysis,
        port.address(),
        destination,
        MemoryReadAddress(memory=memory.id(), port=port.id()),
      )
      match port.enable() {
        Some(enable) =>
          check_dependency(
            hardware_module,
            analysis,
            enable,
            destination,
            MemoryReadEnable(memory=memory.id(), port=port.id()),
          )
        None => ()
      }
    }
    for port in memory.write_ports() {
      let destination = port.domain().id()
      check_dependency(
        hardware_module,
        analysis,
        port.address(),
        destination,
        MemoryWriteAddress(memory=memory.id(), port=port.id()),
      )
      check_dependency(
        hardware_module,
        analysis,
        port.data(),
        destination,
        MemoryWriteData(memory=memory.id(), port=port.id()),
      )
      match port.enable() {
        Some(enable) =>
          check_dependency(
            hardware_module,
            analysis,
            enable,
            destination,
            MemoryWriteEnable(memory=memory.id(), port=port.id()),
          )
        None => ()
      }
      match port.mask() {
        All => ()
        Granular(signal~, ..) =>
          check_dependency(
            hardware_module,
            analysis,
            signal,
            destination,
            MemoryWriteMask(memory=memory.id(), port=port.id()),
          )
      }
    }
  }
  validate_outputs(hardware_module, analysis)
}

///|
/// Validate every module in canonical design order.
pub fn validate_design(design : @ir.Design) -> Unit raise CdcError {
  for hardware_module in design.modules() {
    validate_module(hardware_module)
  }
}
