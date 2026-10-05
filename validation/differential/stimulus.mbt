///|
/// Simulator-neutral differential stimulus actions.
pub(all) enum StimulusAction {
  Drive(tap~ : String, value~ : NormalizedValue)
  RisingEdge(domain~ : String)
  Sample(tap~ : String)
} derive(Debug, Eq)

///|
/// One action at an explicit event and cycle coordinate.
pub struct Stimulus {
  event : UInt64
  cycle : UInt64
  action : StimulusAction
} derive(Debug, Eq)

///|
pub fn Stimulus::drive(
  event : UInt64,
  cycle : UInt64,
  tap : String,
  value : NormalizedValue,
) -> Stimulus raise DifferentialError {
  if tap.length() == 0 {
    raise EmptyTap
  }
  { event, cycle, action: Drive(tap~, value~), }
}

///|
pub fn Stimulus::rising_edge(
  event : UInt64,
  cycle : UInt64,
  domain : String,
) -> Stimulus raise DifferentialError {
  if domain.length() == 0 {
    raise EmptyDomain
  }
  { event, cycle, action: RisingEdge(domain~), }
}

///|
pub fn Stimulus::sample(
  event : UInt64,
  cycle : UInt64,
  tap : String,
) -> Stimulus raise DifferentialError {
  if tap.length() == 0 {
    raise EmptyTap
  }
  { event, cycle, action: Sample(tap~), }
}

///|
pub fn Stimulus::event(self : Stimulus) -> UInt64 {
  self.event
}

///|
pub fn Stimulus::cycle(self : Stimulus) -> UInt64 {
  self.cycle
}

///|
pub fn Stimulus::action(self : Stimulus) -> StimulusAction {
  self.action
}

///|
fn stimulus_coordinate_compare(left : Stimulus, right : Stimulus) -> Int {
  let event_order = left.event.compare(right.event)
  if event_order != 0 {
    return event_order
  }
  left.cycle.compare(right.cycle)
}

///|
/// Ordered stimulus with an explicit provenance seed. The package never uses
/// ambient randomness; generators must record the seed supplied by the caller.
///
/// Drives at one `(event, cycle)` coordinate form one simultaneous group and
/// must appear first, uniquely named and in canonical UTF-8 byte order. Edge
/// and sample order after that group is semantic and retained exactly.
pub struct StimulusSequence {
  identity : DesignIdentity
  seed : UInt64
  stimuli : ReadOnlyArray[Stimulus]
} derive(Debug, Eq)

///|
pub fn StimulusSequence::checked(
  identity : DesignIdentity,
  seed : UInt64,
  stimuli : Array[Stimulus],
) -> StimulusSequence raise DifferentialError {
  let mut boundary_seen = false
  let mut previous_drive : String? = None
  let seen_edges : Array[String] = []
  let seen_samples : Array[String] = []
  for index, stimulus in stimuli {
    if index > 0 {
      let previous = stimuli[index - 1]
      if stimulus.event < previous.event || stimulus.cycle < previous.cycle {
        raise NonMonotonicStimulus(index~)
      }
      if stimulus_coordinate_compare(previous, stimulus) != 0 {
        boundary_seen = false
        previous_drive = None
        seen_edges.clear()
        seen_samples.clear()
      }
    }
    match stimulus.action {
      Drive(tap~, ..) => {
        if boundary_seen {
          raise DriveAfterBoundary(index~)
        }
        match previous_drive {
          Some(previous_tap) => {
            let order = compare_utf8(
              @utf8.encode(previous_tap),
              @utf8.encode(tap),
            )
            if order == 0 {
              raise DuplicateDrive(
                event=stimulus.event,
                cycle=stimulus.cycle,
                tap~,
              )
            }
            if order > 0 {
              raise NonCanonicalDriveOrder(index~)
            }
          }
          None => ()
        }
        previous_drive = Some(tap)
      }
      RisingEdge(domain~) => {
        if seen_edges.contains(domain) {
          raise DuplicateEdge(
            event=stimulus.event,
            cycle=stimulus.cycle,
            domain~,
          )
        }
        seen_edges.push(domain)
        boundary_seen = true
      }
      Sample(tap~) => {
        if seen_samples.contains(tap) {
          raise DuplicateSample(
            event=stimulus.event,
            cycle=stimulus.cycle,
            tap~,
          )
        }
        seen_samples.push(tap)
        boundary_seen = true
      }
    }
    if index > 0 &&
      stimulus_coordinate_compare(stimuli[index - 1], stimulus) < 0 &&
      stimulus.event == stimuli[index - 1].event {
      raise InconsistentEventCycle(index~)
    }
  }
  { identity, seed, stimuli: ReadOnlyArray::from_array(stimuli.copy()), }
}

///|
pub fn StimulusSequence::identity(self : StimulusSequence) -> DesignIdentity {
  self.identity
}

///|
pub fn StimulusSequence::seed(self : StimulusSequence) -> UInt64 {
  self.seed
}

///|
pub fn StimulusSequence::stimuli(
  self : StimulusSequence,
) -> ReadOnlyArray[Stimulus] {
  self.stimuli
}

///|
pub extend StimulusAction with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend StimulusAction with Eq::{not_equal, equal}

///|
pub extend Stimulus with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Stimulus with Eq::{not_equal, equal}

///|
pub extend StimulusSequence with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend StimulusSequence with Eq::{not_equal, equal}
