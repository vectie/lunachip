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
pub fn execute(bundle : ReplayBundle) -> ReplayResult raise {
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
