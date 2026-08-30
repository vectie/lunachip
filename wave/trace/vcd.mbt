///|
fn vcd_identifier(index : Int) -> String {
  "s\{index}"
}

///|
fn vcd_reference(signal : TraceSignal) -> String {
  "lunachip_\{encode_text(signal.path())}__\{encode_text(signal.name())}"
}

///|
fn vcd_bits(value : @wave.LogicValue) -> String {
  let source = value.to_bit_string()
  let builder = StringBuilder(size_hint=source.length())
  for code in source {
    if code == 'X' {
      builder.write_char('x')
    } else {
      builder.write_char(code)
    }
  }
  builder.to_string()
}

///|
fn write_vcd_value(
  builder : StringBuilder,
  identifier : String,
  value : @wave.LogicValue,
) -> Unit {
  let bits = vcd_bits(value)
  if value.width() == 1 {
    builder.write_string("\{bits}\{identifier}\n")
  } else {
    builder.write_string("b\{bits} \{identifier}\n")
  }
}

///|
/// Export a deterministic IEEE-1364-style Value Change Dump.
///
/// The fixed timescale and absence of wall-clock metadata make output
/// byte-stable. VCD timestamp `n` denotes the nth preserved trace boundary;
/// the exact LunaChip cycle, boundary number, and event are retained in the
/// adjacent comment. Unknown bits are emitted as lowercase `x`.
fn to_vcd_schema1(trace : Trace) -> String {
  let builder = StringBuilder()
  builder.write_string("$version LunaChip LunaWave trace schema 1 $end\n")
  builder.write_string("$timescale 1ns $end\n")
  builder.write_string("$scope module lunachip $end\n")
  for index, signal in trace.signals() {
    builder.write_string(
      "$var wire \{signal.width()} \{vcd_identifier(index)} \{vcd_reference(signal)} $end\n",
    )
  }
  builder.write_string("$upscope $end\n$enddefinitions $end\n")
  for frame_index, frame in trace.frames() {
    let (event_tag, event_argument) = event_parts(frame.event())
    builder.write_string("#\{frame_index}\n")
    builder.write_string(
      "$comment cycle=\{frame.cycle()} boundary=\{frame.boundary()} event=\{event_tag} argument=\{event_argument} $end\n",
    )
    for change in frame.changes() {
      write_vcd_value(
        builder,
        vcd_identifier(change.signal_index()),
        change.value(),
      )
    }
  }
  builder.to_string()
}

///|
fn vcd_join_drives(drives : ArrayView[String]) -> String {
  if drives.is_empty() {
    return "-"
  }
  drives.map(encode_text).join(",")
}

///|
fn vcd_join_domains(domains : ArrayView[Int]) -> String {
  if domains.is_empty() {
    return "-"
  }
  domains.map(domain => domain.to_string()).join(",")
}

///|
fn vcd_domain_index(domains : ArrayView[TraceDomain], requested : Int) -> Int {
  for index, domain in domains {
    if domain.id() == requested {
      return index
    }
  }
  abort("validated trace contains an unknown active domain")
}

///|
fn vcd_domain_counts(
  domains : ArrayView[TraceDomain],
  counts : ArrayView[UInt64],
) -> String {
  if domains.is_empty() {
    return "-"
  }
  let entries : Array[String] = []
  for index, domain in domains {
    entries.push("\{domain.id()}:\{counts[index]}")
  }
  entries.join(",")
}

///|
fn to_vcd_schema2(trace : Trace) -> String {
  let builder = StringBuilder()
  let timebase = match trace.timebase() {
    Some(value) => value
    None => abort("validated schema-2 trace lacks timebase")
  }
  builder.write_string("$version LunaChip LunaWave trace schema 2 $end\n")
  // VCD requires a physical-looking timescale token. LunaChip deliberately
  // uses 1ps only as a viewer unit: one VCD unit is exactly one normalized
  // design tick and is not a physical picosecond timing claim.
  builder.write_string("$timescale 1ps $end\n")
  builder.write_string(
    "$comment lunachip_timebase=\{timebase} normalized_ticks_per_source_unit vcd_unit=one_normalized_tick display_timescale=1ps_not_physical $end\n",
  )
  for domain in trace.domains() {
    builder.write_string(
      "$comment domain=\{domain.id()} clock=\{encode_text(domain.clock())} $end\n",
    )
  }
  builder.write_string("$scope module lunachip $end\n")
  for index, signal in trace.signals() {
    builder.write_string(
      "$var wire \{signal.width()} \{vcd_identifier(index)} \{vcd_reference(signal)} $end\n",
    )
  }
  builder.write_string("$upscope $end\n$enddefinitions $end\n")
  let domain_counts : Array[UInt64] = Array::make(trace.domains().length(), 0UL)
  let mut last_time : UInt64? = None
  for frame in trace.atomic_frames() {
    if last_time != Some(frame.time()) {
      builder.write_string("#\{frame.time()}\n")
      last_time = Some(frame.time())
    }
    for domain in frame.active_domains() {
      let index = vcd_domain_index(trace.domains(), domain)
      domain_counts[index] = domain_counts[index] + 1UL
    }
    let (event_tag, event_argument) = atomic_event_parts(frame.event())
    builder.write_string(
      "$comment time=\{frame.time()} boundary=\{frame.boundary()} event=\{event_tag} argument=\{event_argument} drives=\{vcd_join_drives(frame.drives())} domains=\{vcd_join_domains(frame.active_domains())} domain_counts=\{vcd_domain_counts(trace.domains(), domain_counts)} $end\n",
    )
    for change in frame.changes() {
      write_vcd_value(
        builder,
        vcd_identifier(change.signal_index()),
        change.value(),
      )
    }
  }
  builder.to_string()
}

///|
/// Export schema 1 with legacy frame-index timestamps or schema 2 with exact
/// normalized design timestamps. Schema-2 cycle counters are never used as
/// time and are not present in the native representation.
pub fn to_vcd(trace : Trace) -> String {
  match trace.schema() {
    Legacy1 => to_vcd_schema1(trace)
    Atomic2 => to_vcd_schema2(trace)
  }
}
