///|
/// One canonical external clock-domain mapping. IDs preserve the IR's sparse
/// clock-node ordinals and are strictly ordered in an AtomicStimulus so a
/// manifest, stimulus, simulator, and RTL harness share one stable identity
/// without inferring domains from clock names.
pub struct StimulusDomain {
  id : Int
  clock_port : String
} derive(Debug, Eq)

///|
pub fn StimulusDomain::checked(
  id : Int,
  clock_port : String,
) -> StimulusDomain raise StimulusContractError {
  if id < 0 {
    raise InvalidStimulusDomainId(id)
  }
  require_stimulus_identifier("clock port", clock_port)
  { id, clock_port }
}

///|
pub fn StimulusDomain::id(self : StimulusDomain) -> Int {
  self.id
}

///|
pub fn StimulusDomain::clock_port(self : StimulusDomain) -> String {
  self.clock_port
}

///|
/// A fully-known named input assignment. Verilator is the two-state oracle;
/// accepting an unknown bit here would silently change LunaWave semantics.
pub struct AtomicStimulusDrive {
  name : String
  value : @differential.NormalizedValue
} derive(Debug, Eq)

///|
pub fn AtomicStimulusDrive::checked(
  name : String,
  value : @differential.NormalizedValue,
) -> AtomicStimulusDrive raise StimulusContractError {
  require_stimulus_identifier("drive", name)
  if value.known_mask().contains("0") {
    raise UnknownVerilatorStimulusValue(name~)
  }
  { name, value }
}

///|
pub fn AtomicStimulusDrive::name(self : AtomicStimulusDrive) -> String {
  self.name
}

///|
pub fn AtomicStimulusDrive::value(
  self : AtomicStimulusDrive,
) -> @differential.NormalizedValue {
  self.value
}

///|
/// One atomic boundary. Every drive is applied first, all listed rising edges
/// then fire together, and the model settles once before observations. A
/// single event may contain multiple domains at one exact normalized time.
pub struct AtomicStimulusEvent {
  time : UInt64
  boundary : UInt64
  drives : ReadOnlyArray[AtomicStimulusDrive]
  domains : ReadOnlyArray[Int]
} derive(Debug, Eq)

///|
pub fn AtomicStimulusEvent::checked(
  time : UInt64,
  boundary : UInt64,
  declared_drives : ArrayView[AtomicStimulusDrive],
  declared_domains : ArrayView[Int],
) -> AtomicStimulusEvent raise StimulusContractError {
  if declared_drives.is_empty() && declared_domains.is_empty() {
    raise EmptyAtomicStimulusEvent
  }
  let drives = declared_drives.to_owned()
  drives.sort_by((left, right) => {
    stimulus_text_compare(left.name(), right.name())
  })
  for index, drive in drives {
    if index > 0 && drives[index - 1].name() == drive.name() {
      raise DuplicateAtomicStimulusDrive(drive.name())
    }
  }
  let domains = declared_domains.to_owned()
  domains.sort()
  for index, domain in domains {
    if domain < 0 {
      raise InvalidStimulusDomainId(domain)
    }
    if index > 0 && domains[index - 1] == domain {
      raise DuplicateAtomicStimulusDomain(domain)
    }
  }
  {
    time,
    boundary,
    drives: ReadOnlyArray::from_array(drives),
    domains: ReadOnlyArray::from_array(domains),
  }
}

///|
pub fn AtomicStimulusEvent::time(self : AtomicStimulusEvent) -> UInt64 {
  self.time
}

///|
pub fn AtomicStimulusEvent::boundary(self : AtomicStimulusEvent) -> UInt64 {
  self.boundary
}

///|
pub fn AtomicStimulusEvent::drives(
  self : AtomicStimulusEvent,
) -> ReadOnlyArray[AtomicStimulusDrive] {
  self.drives
}

///|
pub fn AtomicStimulusEvent::domains(
  self : AtomicStimulusEvent,
) -> ReadOnlyArray[Int] {
  self.domains
}

///|
/// Canonical schema-v2 stimulus. `ticks_per_source_unit` is the exact integer
/// lattice denominator used to normalize rational source-clock schedules.
pub struct AtomicStimulus {
  ticks_per_source_unit : UInt64
  domains : ReadOnlyArray[StimulusDomain]
  events : ReadOnlyArray[AtomicStimulusEvent]
} derive(Debug, Eq)

///|
pub fn AtomicStimulus::checked(
  ticks_per_source_unit : UInt64,
  declared_domains : ArrayView[StimulusDomain],
  events : ArrayView[AtomicStimulusEvent],
) -> AtomicStimulus raise StimulusContractError {
  if ticks_per_source_unit == 0UL {
    raise InvalidStimulusTimebase(ticks_per_source_unit)
  }
  if declared_domains.is_empty() {
    raise EmptyStimulusDomains
  }
  let domains = declared_domains.to_owned()
  domains.sort_by((left, right) => left.id() - right.id())
  for index, domain in domains {
    if index > 0 && domains[index - 1].id() == domain.id() {
      raise DuplicateStimulusDomainId(domain.id())
    }
    for previous in 0..<index {
      if domains[previous].clock_port() == domain.clock_port() {
        raise DuplicateStimulusClockPort(domain.clock_port())
      }
    }
  }
  let mut previous_time : UInt64? = None
  let mut previous_boundary : UInt64? = None
  for event in events {
    match previous_time {
      Some(previous) if event.time() <= previous =>
        raise NonMonotonicAtomicStimulusTime(previous~, actual=event.time())
      _ => ()
    }
    match previous_boundary {
      Some(previous) if event.boundary() <= previous =>
        raise NonMonotonicAtomicStimulusBoundary(
          previous~,
          actual=event.boundary(),
        )
      _ => ()
    }
    for domain in event.domains() {
      let mut found = false
      for declared in domains {
        if declared.id() == domain {
          found = true
          break
        }
      }
      if !found {
        raise UnknownAtomicStimulusDomain(domain)
      }
    }
    previous_time = Some(event.time())
    previous_boundary = Some(event.boundary())
  }
  {
    ticks_per_source_unit,
    domains: ReadOnlyArray::from_array(domains),
    events: ReadOnlyArray::from_array(events),
  }
}

///|
pub fn AtomicStimulus::ticks_per_source_unit(self : AtomicStimulus) -> UInt64 {
  self.ticks_per_source_unit
}

///|
pub fn AtomicStimulus::domains(
  self : AtomicStimulus,
) -> ReadOnlyArray[StimulusDomain] {
  self.domains
}

///|
pub fn AtomicStimulus::events(
  self : AtomicStimulus,
) -> ReadOnlyArray[AtomicStimulusEvent] {
  self.events
}

///|
fn stimulus_text_compare(left : String, right : String) -> Int {
  let left_bytes = @utf8.encode(left)
  let right_bytes = @utf8.encode(right)
  let common = left_bytes.length().min(right_bytes.length())
  for index in 0..<common {
    let difference = left_bytes[index].to_int() - right_bytes[index].to_int()
    if difference != 0 {
      return difference
    }
  }
  left_bytes.length() - right_bytes.length()
}

///|
fn require_stimulus_identifier(
  kind : String,
  name : String,
) -> Unit raise StimulusContractError {
  if name.is_empty() {
    raise InvalidStimulusIdentifier(kind~, name~)
  }
  for index, symbol in name {
    let code = symbol.to_int()
    let letter = (code >= 65 && code <= 90) || (code >= 97 && code <= 122)
    let digit = code >= 48 && code <= 57
    if !(letter || symbol == '_' || (index > 0 && (digit || symbol == '$'))) {
      raise InvalidStimulusIdentifier(kind~, name~)
    }
  }
}

///|
fn stimulus_tokens(line : String) -> Array[String] {
  line.split("\t").map(part => part.to_owned()).to_array()
}

///|
fn stimulus_parse_int(
  line : Int,
  field : String,
  text : String,
) -> Int raise StimulusContractError {
  @strconv.from_str(text) catch {
    _ => raise InvalidStimulusInteger(line~, field~, value=text)
  }
}

///|
fn stimulus_parse_uint64(
  line : Int,
  field : String,
  text : String,
) -> UInt64 raise StimulusContractError {
  @strconv.from_str(text) catch {
    _ => raise InvalidStimulusInteger(line~, field~, value=text)
  }
}

///|
priv struct StimulusReader {
  lines : Array[String]
  mut cursor : Int
}

///|
fn StimulusReader::next(
  self : StimulusReader,
  expected : String,
) -> (Int, Array[String]) raise StimulusContractError {
  if self.cursor >= self.lines.length() - 1 {
    raise InvalidStimulusLine(
      line=self.cursor + 1,
      expected~,
      actual="end of input",
    )
  }
  let line = self.cursor + 1
  let actual = self.lines[self.cursor]
  self.cursor += 1
  (line, stimulus_tokens(actual))
}

///|
fn stimulus_require(
  line : Int,
  tokens : ArrayView[String],
  keyword : String,
  count : Int,
  expected : String,
) -> Unit raise StimulusContractError {
  if tokens.length() != count || tokens[0] != keyword {
    raise InvalidStimulusLine(line~, expected~, actual=tokens.join("\t"))
  }
}

///|
/// Canonical tab-separated encoding consumed by a future multi-clock C++
/// harness. Existing cycle TSV is deliberately not routed through this API.
pub fn AtomicStimulus::to_tsv(self : AtomicStimulus) -> String {
  let output = StringBuilder()
  output.write_string("LUNACHIP-VERILATOR-STIMULUS\t2\n")
  output.write_string("TIMEBASE\t\{self.ticks_per_source_unit()}\n")
  output.write_string("DOMAINS\t\{self.domains().length()}\n")
  for domain in self.domains() {
    output.write_string(
      "DOMAIN\t\{domain.id()}\t\{domain.clock_port()}\trising\n",
    )
  }
  output.write_string("EVENTS\t\{self.events().length()}\n")
  for ordinal, event in self.events() {
    output.write_string(
      "EVENT\t\{ordinal}\t\{event.time()}\t\{event.boundary()}\t\{event.drives().length()}\t\{event.domains().length()}\n",
    )
    for drive in event.drives() {
      let value = drive.value()
      output.write_string(
        "DRIVE\t\{drive.name()}\t\{value.width()}\t\{value.value_bits()}\t\{value.known_mask()}\n",
      )
    }
    for domain in event.domains() {
      output.write_string("DOMAIN\t\{domain}\n")
    }
  }
  output.write_string("END\n")
  output.to_string()
}

///|
/// Strictly parse schema v2 and require exact reserialization, rejecting
/// reordered records and all alternative spellings of canonical integers.
pub fn parse_atomic_stimulus(
  source : String,
) -> AtomicStimulus raise StimulusContractError {
  if !source.has_suffix("\n") {
    raise NonCanonicalStimulus
  }
  let reader : StimulusReader = {
    lines: source.split("\n").map(part => part.to_owned()).to_array(),
    cursor: 0,
  }
  let (header_line, header) = reader.next("stimulus header")
  stimulus_require(
    header_line, header, "LUNACHIP-VERILATOR-STIMULUS", 2, "LUNACHIP-VERILATOR-STIMULUS tab version",
  )
  if header[1] != "2" {
    raise UnsupportedStimulusVersion(header[1])
  }
  let (timebase_line, timebase_tokens) = reader.next("TIMEBASE tab ticks")
  stimulus_require(
    timebase_line, timebase_tokens, "TIMEBASE", 2, "TIMEBASE tab ticks",
  )
  let timebase = stimulus_parse_uint64(
    timebase_line,
    "timebase",
    timebase_tokens[1],
  )
  let (domain_count_line, domain_count_tokens) = reader.next(
    "DOMAINS tab count",
  )
  stimulus_require(
    domain_count_line, domain_count_tokens, "DOMAINS", 2, "DOMAINS tab count",
  )
  let domain_count = stimulus_parse_int(
    domain_count_line,
    "domain count",
    domain_count_tokens[1],
  )
  if domain_count < 0 {
    raise InvalidStimulusInteger(
      line=domain_count_line,
      field="domain count",
      value=domain_count_tokens[1],
    )
  }
  let domains : Array[StimulusDomain] = []
  let mut previous_domain_id : Int? = None
  for _ in 0..<domain_count {
    let (line, tokens) = reader.next("DOMAIN tab id tab clock tab rising")
    stimulus_require(
      line, tokens, "DOMAIN", 4, "DOMAIN tab id tab clock tab rising",
    )
    if tokens[3] != "rising" {
      raise InvalidStimulusLine(
        line~,
        expected="rising clock edge",
        actual=tokens[3],
      )
    }
    let id = stimulus_parse_int(line, "domain id", tokens[1])
    match previous_domain_id {
      Some(previous) if id <= previous =>
        raise NonCanonicalStimulusDomainOrder(previous~, actual=id)
      _ => ()
    }
    domains.push(StimulusDomain::checked(id, tokens[2]))
    previous_domain_id = Some(id)
  }
  let (event_count_line, event_count_tokens) = reader.next("EVENTS tab count")
  stimulus_require(
    event_count_line, event_count_tokens, "EVENTS", 2, "EVENTS tab count",
  )
  let event_count = stimulus_parse_int(
    event_count_line,
    "event count",
    event_count_tokens[1],
  )
  if event_count < 0 {
    raise InvalidStimulusInteger(
      line=event_count_line,
      field="event count",
      value=event_count_tokens[1],
    )
  }
  let events : Array[AtomicStimulusEvent] = []
  for ordinal in 0..<event_count {
    let (line, tokens) = reader.next(
      "EVENT tab ordinal tab time tab boundary tab drives tab domains",
    )
    stimulus_require(
      line, tokens, "EVENT", 6, "EVENT tab ordinal tab time tab boundary tab drives tab domains",
    )
    let parsed_ordinal = stimulus_parse_int(line, "event ordinal", tokens[1])
    if parsed_ordinal != ordinal {
      raise InvalidStimulusLine(
        line~,
        expected="event ordinal {ordinal}",
        actual=tokens[1],
      )
    }
    let drive_count = stimulus_parse_int(line, "drive count", tokens[4])
    let edge_count = stimulus_parse_int(line, "domain edge count", tokens[5])
    if drive_count < 0 || edge_count < 0 {
      raise InvalidStimulusInteger(
        line~,
        field="event member count",
        value="{tokens[4]} {tokens[5]}",
      )
    }
    let drives : Array[AtomicStimulusDrive] = []
    for _ in 0..<drive_count {
      let (drive_line, drive_tokens) = reader.next(
        "DRIVE tab name tab width tab value tab known",
      )
      stimulus_require(
        drive_line, drive_tokens, "DRIVE", 5, "DRIVE tab name tab width tab value tab known",
      )
      let width = stimulus_parse_int(drive_line, "drive width", drive_tokens[2])
      let value = @differential.NormalizedValue::from_planes(
        drive_tokens[3],
        drive_tokens[4],
      ) catch {
        error =>
          raise InvalidStimulusLine(
            line=drive_line,
            expected="normalized drive value",
            actual="\{Repr(error)}",
          )
      }
      if value.width() != width {
        raise InvalidStimulusLine(
          line=drive_line,
          expected="width-matched normalized drive value",
          actual=drive_tokens.join("\t"),
        )
      }
      drives.push(AtomicStimulusDrive::checked(drive_tokens[1], value))
    }
    let event_domains : Array[Int] = []
    for _ in 0..<edge_count {
      let (domain_line, domain_tokens) = reader.next("DOMAIN tab id")
      stimulus_require(domain_line, domain_tokens, "DOMAIN", 2, "DOMAIN tab id")
      event_domains.push(
        stimulus_parse_int(domain_line, "event domain id", domain_tokens[1]),
      )
    }
    events.push(
      AtomicStimulusEvent::checked(
        stimulus_parse_uint64(line, "event time", tokens[2]),
        stimulus_parse_uint64(line, "event boundary", tokens[3]),
        drives,
        event_domains,
      ),
    )
  }
  let (end_line, end_tokens) = reader.next("END")
  stimulus_require(end_line, end_tokens, "END", 1, "END")
  let stimulus = AtomicStimulus::checked(timebase, domains, events)
  if reader.cursor != reader.lines.length() - 1 || stimulus.to_tsv() != source {
    raise NonCanonicalStimulus
  }
  stimulus
}
