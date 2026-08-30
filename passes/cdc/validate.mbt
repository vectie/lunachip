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
fn primitive_source_matches(
  provenance : CdcProvenance,
  declared : @ir.CdcSourceDomain,
) -> Bool {
  match declared {
    AsynchronousSource =>
      provenance.has_asynchronous() && provenance.domains().is_empty()
    SourceDomain(domain) =>
      !provenance.has_asynchronous() &&
      provenance.domains().length() == 1 &&
      provenance.domains()[0] == domain
  }
}

///|
fn validate_primitive_source(
  hardware_module : @ir.Module,
  analysis : CdcAnalysis,
  primitive : @ir.BitSynchronizerPrimitive,
) -> Unit raise CdcError {
  let source = primitive.source()
  let source_analysis = match analysis.node(source) {
    Some(item) => item
    None => abort("validated primitive source unexpectedly absent")
  }
  if !primitive_source_matches(
      source_analysis.provenance(),
      primitive.source_domain(),
    ) {
    raise PrimitiveSourceMismatch(
      module_name=hardware_module.name(),
      primitive=primitive.id(),
      source~,
      declared=primitive.source_domain(),
      actual=source_analysis.provenance(),
      witness=if source_analysis.provenance().is_neutral() {
        None
      } else {
        Some(any_witness(source_analysis))
      },
    )
  }
}

///|
fn validate_declared_primitive_source(
  hardware_module : @ir.Module,
  analysis : CdcAnalysis,
  primitive : @ir.CdcPrimitiveId,
  source : @ir.NodeId,
  declared : @ir.CdcSourceDomain,
) -> Unit raise CdcError {
  let source_analysis = match analysis.node(source) {
    Some(item) => item
    None => abort("validated primitive source unexpectedly absent")
  }
  if !primitive_source_matches(source_analysis.provenance(), declared) {
    raise PrimitiveSourceMismatch(
      module_name=hardware_module.name(),
      primitive~,
      source~,
      declared~,
      actual=source_analysis.provenance(),
      witness=if source_analysis.provenance().is_neutral() {
        None
      } else {
        Some(any_witness(source_analysis))
      },
    )
  }
}

///|
priv enum PrimitiveRegisterExemption {
  BitSynchronizerStart(@ir.BitSynchronizerPrimitive)
  ToggleRequestStart(@ir.ToggleHandshakePrimitive)
  ToggleAcknowledgeStart(@ir.ToggleHandshakePrimitive)
  TogglePayloadCapture(primitive~ : @ir.ToggleHandshakePrimitive, leaf~ : Int)
  FifoReadGrayStart(@ir.AsyncFifoPrimitive)
  FifoWriteGrayStart(@ir.AsyncFifoPrimitive)
}

///|
fn primitive_register_exemptions(
  hardware_module : @ir.Module,
) -> Array[PrimitiveRegisterExemption?] {
  let starts : Array[PrimitiveRegisterExemption?] = Array::make(
    hardware_module.nodes().length(),
    None,
  )
  for primitive in hardware_module.cdc_primitives() {
    match primitive {
      BitSynchronizer(spec) =>
        starts[spec.stages()[0].ordinal()] = Some(BitSynchronizerStart(spec))
      ToggleHandshake(spec) => {
        starts[spec.request_stages()[0].ordinal()] = Some(
          ToggleRequestStart(spec),
        )
        starts[spec.acknowledge_stages()[0].ordinal()] = Some(
          ToggleAcknowledgeStart(spec),
        )
        for leaf, payload in spec.destination_payload() {
          starts[payload.ordinal()] = Some(
            TogglePayloadCapture(primitive=spec, leaf~),
          )
        }
      }
      AsyncFifo(spec) => {
        starts[spec.read_gray_stages()[0].ordinal()] = Some(
          FifoReadGrayStart(spec),
        )
        starts[spec.write_gray_stages()[0].ordinal()] = Some(
          FifoWriteGrayStart(spec),
        )
      }
    }
  }
  starts
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
fn check_asynchronous_reset(
  hardware_module : @ir.Module,
  analysis : CdcAnalysis,
  source : @ir.NodeId,
  destination : @ir.ClockDomainId,
  register : @ir.NodeId,
) -> Unit raise CdcError {
  let source_analysis = match analysis.node(source) {
    Some(item) => item
    None => abort("validated asynchronous reset unexpectedly absent")
  }
  let provenance = source_analysis.provenance()
  if !provenance.has_asynchronous() || !provenance.domains().is_empty() {
    raise UnsafeAsynchronousReset(
      module_name=hardware_module.name(),
      sink=AsynchronousReset(register),
      destination~,
      actual=provenance,
      witness=if provenance.is_neutral() {
        None
      } else {
        Some(any_witness(source_analysis))
      },
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
/// Validate every current state, memory-control, and output sink. Only stage 0
/// of a structurally checked first-class primitive receives an exemption, and
/// only after its actual source provenance exactly matches its declaration.
pub fn validate_module(hardware_module : @ir.Module) -> Unit raise CdcError {
  let analysis = analyze_module(hardware_module)
  let exemptions = primitive_register_exemptions(hardware_module)
  for primitive in hardware_module.cdc_primitives() {
    match primitive {
      BitSynchronizer(_) => ()
      ToggleHandshake(spec) => {
        check_dependency(
          hardware_module,
          analysis,
          spec.source_valid(),
          spec.source_domain(),
          ToggleSourceValid(spec.id()),
        )
        for leaf, payload in spec.source_payload() {
          check_dependency(
            hardware_module,
            analysis,
            payload,
            spec.source_domain(),
            ToggleSourcePayload(primitive=spec.id(), leaf~),
          )
        }
        check_dependency(
          hardware_module,
          analysis,
          spec.destination_ready(),
          spec.destination_domain(),
          ToggleDestinationReady(spec.id()),
        )
      }
      AsyncFifo(spec) => {
        check_dependency(
          hardware_module,
          analysis,
          spec.source_valid(),
          spec.source_domain(),
          FifoSourceValid(spec.id()),
        )
        check_dependency(
          hardware_module,
          analysis,
          spec.destination_ready(),
          spec.destination_domain(),
          FifoDestinationReady(spec.id()),
        )
        check_dependency(
          hardware_module,
          analysis,
          spec.source_transfer(),
          spec.source_domain(),
          FifoWriteTransfer(spec.id()),
        )
        for leaf, payload in spec.source_payload() {
          check_dependency(
            hardware_module,
            analysis,
            payload,
            spec.source_domain(),
            FifoPayloadWrite(primitive=spec.id(), leaf~),
          )
        }
        for leaf, raw in spec.raw_reads() {
          check_dependency(
            hardware_module,
            analysis,
            raw,
            spec.destination_domain(),
            FifoPrivateRead(primitive=spec.id(), leaf~),
          )
        }
      }
    }
  }
  for node in hardware_module.nodes() {
    match node.kind() {
      Register(spec) => {
        let destination = spec.domain().id()
        match exemptions[node.id().ordinal()] {
          Some(BitSynchronizerStart(primitive)) =>
            validate_primitive_source(hardware_module, analysis, primitive)
          Some(ToggleRequestStart(primitive)) =>
            validate_declared_primitive_source(
              hardware_module,
              analysis,
              primitive.id(),
              primitive.request_toggle(),
              SourceDomain(primitive.source_domain()),
            )
          Some(ToggleAcknowledgeStart(primitive)) =>
            validate_declared_primitive_source(
              hardware_module,
              analysis,
              primitive.id(),
              primitive.acknowledge_toggle(),
              SourceDomain(primitive.destination_domain()),
            )
          Some(TogglePayloadCapture(primitive~, leaf~)) =>
            validate_declared_primitive_source(
              hardware_module,
              analysis,
              primitive.id(),
              primitive.held_payload()[leaf],
              SourceDomain(primitive.source_domain()),
            )
          Some(FifoReadGrayStart(primitive)) =>
            check_dependency(
              hardware_module,
              analysis,
              primitive.read_gray(),
              primitive.destination_domain(),
              FifoPointerStage(
                primitive=primitive.id(),
                side="read_gray_into_source",
              ),
              sink_node=node.id(),
            )
          Some(FifoWriteGrayStart(primitive)) =>
            check_dependency(
              hardware_module,
              analysis,
              primitive.write_gray(),
              primitive.source_domain(),
              FifoPointerStage(
                primitive=primitive.id(),
                side="write_gray_into_destination",
              ),
              sink_node=node.id(),
            )
          None =>
            check_dependency(
              hardware_module,
              analysis,
              spec.next(),
              destination,
              RegisterNext(node.id()),
              sink_node=node.id(),
            )
        }
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
          Some(reset) =>
            match reset.mode() {
              Synchronous =>
                check_dependency(
                  hardware_module,
                  analysis,
                  reset.signal(),
                  destination,
                  SynchronousReset(node.id()),
                  sink_node=node.id(),
                )
              Asynchronous =>
                check_asynchronous_reset(
                  hardware_module,
                  analysis,
                  reset.signal(),
                  destination,
                  node.id(),
                )
            }
          None => ()
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
