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
pub fn to_vcd(trace : Trace) -> String {
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
