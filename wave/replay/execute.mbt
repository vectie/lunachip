///|
fn resolve_tap(
  hardware_module : @ir.Module,
  simulator : @sim.Simulator,
  tap : @trace.TraceSignal,
) -> @wave.LogicValue raise {
  if tap.path() != hardware_module.name() {
    raise UnknownTap(path=tap.path(), name=tap.name())
  }
  let mut found : @wave.LogicValue? = None
  for output in hardware_module.outputs() {
    if output.name() == tap.name() {
      found = Some(simulator.output(output.name()))
    }
  }
  for node in hardware_module.nodes() {
    match node.kind() {
      Input(name) if name == tap.name() => {
        if found is Some(_) {
          raise AmbiguousTap(path=tap.path(), name=tap.name())
        }
        found = Some(simulator.value(node.id()))
      }
      _ => ()
    }
  }
  guard found is Some(value) else {
    raise UnknownTap(path=tap.path(), name=tap.name())
  }
  if value.width() != tap.width() {
    raise TapWidthMismatch(
      path=tap.path(),
      name=tap.name(),
      expected=tap.width(),
      actual=value.width(),
    )
  }
  value
}

///|
fn replay_samples(
  hardware_module : @ir.Module,
  simulator : @sim.Simulator,
  taps : ArrayView[@trace.TraceSignal],
) -> Array[@trace.TraceSample] raise {
  let samples : Array[@trace.TraceSample] = []
  for tap in taps {
    samples.push(
      @trace.TraceSample::new(
        tap.path(),
        tap.name(),
        resolve_tap(hardware_module, simulator, tap),
      ),
    )
  }
  samples
}

///|
fn stop_reached(
  stop : StopCondition,
  stimulus_boundary : UInt64?,
  simulator : @sim.Simulator,
) -> Bool raise {
  match stop {
    AfterBoundary(target) =>
      match stimulus_boundary {
        Some(boundary) => boundary >= target
        None => false
      }
    AtCycle(target) => simulator.cycle().value() >= target
    AtTime(target) => simulator.time().value() >= target
    AtDomainEdge(domain~, count~) =>
      simulator.domain_edge_count(domain) >= count
    OutputEquals(name~, value~) => {
      let actual = simulator.output(name)
      actual == value
    }
  }
}

///|
fn drive_event_name(inputs : ReadOnlyArray[NamedInput]) -> String {
  let names : Array[String] = []
  for input in inputs {
    names.push(input.name())
  }
  names.join(",")
}

///|
/// Execute a validated bundle with LunaWave and return its exact trace digest.
///
/// A full initial frame is always recorded. Each simultaneous drive settles
/// only after every named input is applied, and each edge uses LunaWave's
/// simultaneous register commit. Declared stimulus cycles describe the
/// simulator cycle immediately before the action and are checked at runtime.
fn execute_schema1(bundle : ReplayBundle) -> ReplayResult raise {
  let design = @codec.parse(bundle.canonical_ir())
  guard design.top_module() is Some(hardware_module) else {
    raise MissingTopModule
  }
  let simulator = @sim.Simulator::prepare(hardware_module)
  let recorder = @trace.TraceRecorder::new(bundle.taps())
  let mut trace_boundary = 0UL
  recorder.record(
    simulator.cycle().value(),
    trace_boundary,
    Initial,
    replay_samples(hardware_module, simulator, bundle.taps()),
  )
  let mut reached = stop_reached(bundle.stop(), None, simulator)
  for stimulus in bundle.stimuli() {
    if reached {
      break
    }
    let actual_cycle = simulator.cycle().value()
    if stimulus.cycle() != actual_cycle {
      raise ScheduledCycleMismatch(
        boundary=stimulus.boundary(),
        expected=actual_cycle,
        actual=stimulus.cycle(),
      )
    }
    let event = match stimulus.action() {
      Drive(inputs) => {
        for input in inputs {
          simulator.set_input(input.name(), input.value())
        }
        simulator.settle()
        @trace.InputDriven(drive_event_name(inputs))
      }
      RisingEdge(clock) => {
        simulator.rising_edge(clock)
        RisingEdge(clock)
      }
    }
    trace_boundary += 1UL
    recorder.record(
      simulator.cycle().value(),
      trace_boundary,
      event,
      replay_samples(hardware_module, simulator, bundle.taps()),
    )
    reached = stop_reached(bundle.stop(), Some(stimulus.boundary()), simulator)
  }
  let trace = recorder.finish()
  let digest = trace_result_digest(trace)
  {
    trace,
    digest,
    expected_matches: digest == bundle.expected_result(),
    stop_reached: reached,
  }
}

///|
fn replay_trace_domains(
  hardware_module : @ir.Module,
) -> Array[@trace.TraceDomain] raise {
  let domains : Array[@trace.TraceDomain] = []
  for domain in hardware_module.domains() {
    guard hardware_module.node(domain.clock()) is Some(clock) else {
      abort("validated domain clock is missing")
    }
    let name = match clock.kind() {
      Input(name) => name
      _ => abort("validated domain clock is not an input")
    }
    domains.push(@trace.TraceDomain::checked(domain.id().ordinal(), name))
  }
  domains
}

///|
fn replay_trace_digest(bundle : ReplayBundle) -> @trace.TraceDigest raise {
  @trace.TraceDigest::checked(
    bundle.ir_digest().algorithm(),
    bundle.ir_digest().hex(),
  )
}

///|
fn execute_schema2(bundle : ReplayBundle) -> ReplayResult raise {
  let design = @codec.parse(bundle.canonical_ir())
  guard design.top_module() is Some(hardware_module) else {
    raise MissingTopModule
  }
  let simulator = @sim.Simulator::prepare(hardware_module)
  // Reuse the established recorder solely for canonical signal resolution and
  // changed-only calculation. Its temporary legacy cycle/boundary fields are
  // discarded; schema-2 frame time and boundary come only from replay events.
  let recorder = @trace.TraceRecorder::new(bundle.taps())
  let mut trace_boundary = 0UL
  recorder.record(
    simulator.cycle().value(),
    trace_boundary,
    Initial,
    replay_samples(hardware_module, simulator, bundle.taps()),
  )
  let mut reached = stop_reached(bundle.stop(), None, simulator)
  let executed : Array[AtomicReplayEvent] = []
  for event in bundle.events() {
    if reached {
      break
    }
    let drives : Array[@sim.InputDrive] = []
    for input in event.drives() {
      drives.push(@sim.InputDrive::checked(input.name(), input.value()))
    }
    simulator.apply_event(
      @sim.TimestampEvent::checked(
        @sim.SimulationTime::from_uint64(event.time()),
        drives,
        event.domains(),
      ),
    )
    trace_boundary += 1UL
    recorder.record(
      simulator.cycle().value(),
      trace_boundary,
      Settled,
      replay_samples(hardware_module, simulator, bundle.taps()),
    )
    executed.push(event)
    reached = stop_reached(bundle.stop(), Some(event.boundary()), simulator)
  }
  let changed = recorder.finish()
  let frames : Array[@trace.AtomicTraceFrame] = []
  frames.push(
    @trace.AtomicTraceFrame::checked(
      0UL,
      0UL,
      AtomicInitial,
      [],
      [],
      changed.frames()[0].changes(),
    ),
  )
  for index, event in executed {
    let drives : Array[String] = []
    for input in event.drives() {
      drives.push(input.name())
    }
    let domains : Array[Int32] = []
    for domain in event.domains() {
      domains.push(domain.ordinal())
    }
    frames.push(
      @trace.AtomicTraceFrame::checked(
        event.time(),
        event.boundary(),
        AtomicBatch,
        drives,
        domains,
        changed.frames()[index + 1].changes(),
      ),
    )
  }
  let timebase = match bundle.timebase() {
    Some(value) => value
    None => abort("validated schema-2 replay lacks timebase")
  }
  let trace = @trace.Trace::checked_atomic(
    bundle.semantic_version(),
    replay_trace_digest(bundle),
    timebase,
    replay_trace_domains(hardware_module),
    bundle.taps(),
    frames,
  )
  let digest = trace_result_digest(trace)
  {
    trace,
    digest,
    expected_matches: digest == bundle.expected_result(),
    stop_reached: reached,
  }
}

///|
/// Execute either replay generation after re-validating its embedded IR at the
/// execution boundary. Canonical legacy artifacts remain decodable but unsafe
/// hardware cannot reach the simulator.
pub fn execute(bundle : ReplayBundle) -> ReplayResult raise {
  let design = @codec.parse(bundle.canonical_ir())
  @cdc.validate_design(design) catch {
    error => raise ReplayExecutionError::CdcRejected(error)
  }
  match bundle.schema() {
    Legacy1 => execute_schema1(bundle)
    Atomic2 => execute_schema2(bundle)
  }
}
