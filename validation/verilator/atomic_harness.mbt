///|
fn atomic_cpp_line(out : StringBuilder, line : String) -> Unit {
  out.write_string(line)
  out.write_char('\n')
}

///|
fn atomic_direction_text(direction : PortDirection) -> String {
  match direction {
    Input => "input"
    Output => "output"
  }
}

///|
fn atomic_cpp_string(text : String) -> String {
  text.replace(old="\\", new="\\\\").replace(old="\"", new="\\\"")
}

///|
/// Emits the phase-neutral schema-v2 manifest used by the locked Phase 3
/// runner. Domain clock names are already canonical emitted port names in the
/// stimulus contract and are copied without name inference or dense remapping.
pub fn atomic_harness_json(
  emitted : @systemverilog.EmittedDesign,
  ports : ReadOnlyArray[HarnessPort],
  stimulus : AtomicStimulus,
  harness_filename : String,
) -> String raise HarnessError {
  validate_atomic_ports(ports, stimulus)
  if !atomic_safe_path(harness_filename) {
    raise InvalidAtomicHarnessFilename(harness_filename)
  }
  guard emitted.modules().get(emitted.manifest().top_module_ordinal())
    is Some(top) else {
    raise MissingEmittedTopModule
  }
  let out = StringBuilder()
  out.write_string("{\n")
  out.write_string(
    "  \"$schema\": \"https://lunachip.dev/schema/verilator-harness-v2.json\",\n",
  )
  out.write_string("  \"schema_version\": \"lunachip.verilator-harness/v2\",\n")
  out.write_string("  \"top_module\": \"\{top.identifier()}\",\n")
  out.write_string("  \"sources\": [")
  for index, source in emitted.modules() {
    if index > 0 {
      out.write_string(", ")
    }
    out.write_string("\"\{source.filename()}\"")
  }
  out.write_string("],\n")
  out.write_string("  \"harness_cpp\": \"\{harness_filename}\",\n")
  out.write_string("  \"stimulus\": \"stimulus.tsv\",\n")
  out.write_string(
    "  \"stimulus_schema\": \"lunachip.verilator-stimulus/v2\",\n",
  )
  out.write_string("  \"result\": \"actual.tsv\",\n")
  out.write_string("  \"domains\": [\n")
  for index, domain in stimulus.domains() {
    let clock = domain.clock_port()
    out.write_string(
      "    { \"id\": \{domain.id()}, \"clock_port\": \"\{clock}\", \"edge\": \"rising\" }",
    )
    out.write_string(
      if index + 1 == stimulus.domains().length() {
        "\n"
      } else {
        ",\n"
      },
    )
  }
  out.write_string("  ],\n  \"ports\": [\n")
  for index, port in ports {
    out.write_string(
      "    { \"name\": \"\{port.emitted_name}\", \"direction\": \"\{atomic_direction_text(port.direction)}\", \"width\": \{port.width}, \"signed\": \{if port.signal_type is SInt(_) { "true" } else { "false" }} }",
    )
    out.write_string(if index + 1 == ports.length() { "\n" } else { ",\n" })
  }
  out.write_string("  ]\n}\n")
  out.to_string()
}

///|
fn atomic_result_header(outputs : ArrayView[HarnessPort]) -> String {
  let out = StringBuilder()
  out.write_string("time\\tboundary")
  for output in outputs {
    out.write_string("\\t\{atomic_cpp_string(output.source_name)}")
  }
  out.write_string("\\n")
  out.to_string()
}

///|
fn append_parse_u64(out : StringBuilder) -> Unit {
  atomic_cpp_line(
    out, "static bool parse_u64(const std::string& text, std::uint64_t& value) {",
  )
  atomic_cpp_line(
    out, "  if (text.empty() || (text.size() > 1 && text[0] == '0')) return false;",
  )
  atomic_cpp_line(out, "  value = 0;")
  atomic_cpp_line(out, "  for (char c : text) {")
  atomic_cpp_line(out, "    if (c < '0' || c > '9') return false;")
  atomic_cpp_line(
    out, "    const auto digit = static_cast<std::uint64_t>(c - '0');",
  )
  atomic_cpp_line(
    out, "    if (value > (std::numeric_limits<std::uint64_t>::max() - digit) / 10U) return false;",
  )
  atomic_cpp_line(out, "    value = value * 10U + digit;")
  atomic_cpp_line(out, "  }")
  atomic_cpp_line(out, "  return true;")
  atomic_cpp_line(out, "}")
}

///|
fn append_bit_parser(out : StringBuilder) -> Unit {
  atomic_cpp_line(
    out, "static bool parse_bit(const std::vector<std::string>& row, std::uint64_t& value) {",
  )
  atomic_cpp_line(
    out, "  if (row.size() != 5 || row[0] != \"DRIVE\" || row[2] != \"1\" || row[4] != \"1\") return false;",
  )
  atomic_cpp_line(out, "  if (row[3] == \"0\") { value = 0; return true; }")
  atomic_cpp_line(out, "  if (row[3] == \"1\") { value = 1; return true; }")
  atomic_cpp_line(out, "  return false;")
  atomic_cpp_line(out, "}")
}

///|
fn append_wide_helpers(out : StringBuilder) -> Unit {
  atomic_cpp_line(
    out, "static bool parse_value(const std::vector<std::string>& row, int width, std::uint64_t& value) {",
  )
  atomic_cpp_line(
    out, "  if (width < 1 || width > 64 || row.size() != 5 || row[0] != \"DRIVE\") return false;",
  )
  atomic_cpp_line(out, "  std::uint64_t parsed_width = 0;")
  atomic_cpp_line(
    out, "  if (!parse_u64(row[2], parsed_width) || parsed_width != static_cast<std::uint64_t>(width)) return false;",
  )
  atomic_cpp_line(
    out, "  if (row[3].size() != static_cast<std::size_t>(width) || row[4].size() != static_cast<std::size_t>(width)) return false;",
  )
  atomic_cpp_line(out, "  value = 0;")
  atomic_cpp_line(out, "  for (int index = 0; index < width; ++index) {")
  atomic_cpp_line(
    out, "    const char bit = row[3][static_cast<std::size_t>(index)];",
  )
  atomic_cpp_line(
    out, "    if ((bit != '0' && bit != '1') || row[4][static_cast<std::size_t>(index)] != '1') return false;",
  )
  atomic_cpp_line(
    out, "    value = (value << 1) | static_cast<std::uint64_t>(bit - '0');",
  )
  atomic_cpp_line(out, "  }")
  atomic_cpp_line(out, "  return true;")
  atomic_cpp_line(out, "}")
  atomic_cpp_line(
    out, "static std::string render_hex(std::uint64_t value, int width) {",
  )
  atomic_cpp_line(
    out, "  value &= width == 64 ? std::numeric_limits<std::uint64_t>::max() : ((std::uint64_t{1} << width) - 1U);",
  )
  atomic_cpp_line(
    out, "  static constexpr char digits[] = \"0123456789abcdef\";",
  )
  atomic_cpp_line(
    out, "  std::string text(static_cast<std::size_t>((width + 3) / 4), '0');",
  )
  atomic_cpp_line(
    out, "  for (std::size_t index = text.size(); index > 0; --index) {",
  )
  atomic_cpp_line(out, "    text[index - 1] = digits[value & 15U];")
  atomic_cpp_line(out, "    value >>= 4;")
  atomic_cpp_line(out, "  }")
  atomic_cpp_line(out, "  return text;")
  atomic_cpp_line(out, "}")
}

///|
/// Emits the schema-v2 C++ bridge shared by all multi-clock differential
/// fixtures. Inputs are strict fully-known binary values and results are
/// canonical hexadecimal values for widths one through 64. The one-bit code
/// path is intentionally frozen so extraction does not change existing bundle
/// bytes.
pub fn atomic_harness_cpp(
  ports : ReadOnlyArray[HarnessPort],
  stimulus : AtomicStimulus,
  result_prefix : String,
  edge_mode : AtomicHarnessEdgeMode,
) -> String raise HarnessError {
  validate_atomic_ports(ports, stimulus)
  validate_atomic_result_prefix(result_prefix)
  let inputs = input_ports(ports)
  let outputs = output_ports(ports)
  let one_bit = inputs.all(port => port.width == 1) &&
    outputs.all(port => port.width == 1)
  let out = StringBuilder()
  atomic_cpp_line(out, "#include \"Vlunachip_model.h\"")
  atomic_cpp_line(out, "#include \"verilated.h\"")
  atomic_cpp_line(out, "#include <cstdint>")
  atomic_cpp_line(out, "#include <fstream>")
  atomic_cpp_line(out, "#include <iostream>")
  atomic_cpp_line(out, "#include <limits>")
  atomic_cpp_line(out, "#include <string>")
  atomic_cpp_line(out, "#include <vector>")
  atomic_cpp_line(out, "using Model = Vlunachip_model;")
  atomic_cpp_line(
    out, "static std::vector<std::string> cells(const std::string& line) {",
  )
  atomic_cpp_line(out, "  std::vector<std::string> result;")
  atomic_cpp_line(out, "  std::size_t begin = 0;")
  atomic_cpp_line(out, "  for (;;) {")
  atomic_cpp_line(out, "    const auto tab = line.find('\\t', begin);")
  atomic_cpp_line(out, "    result.push_back(line.substr(begin, tab - begin));")
  atomic_cpp_line(out, "    if (tab == std::string::npos) break;")
  atomic_cpp_line(out, "    begin = tab + 1;")
  atomic_cpp_line(out, "  }")
  atomic_cpp_line(out, "  return result;")
  atomic_cpp_line(out, "}")
  append_parse_u64(out)
  if one_bit {
    if !inputs.is_empty() {
      append_bit_parser(out)
    }
  } else {
    append_wide_helpers(out)
  }
  atomic_cpp_line(out, "int main(int argc, char** argv) {")
  atomic_cpp_line(out, "  Verilated::commandArgs(argc, argv);")
  atomic_cpp_line(out, "  if (argc != 3) return 64;")
  atomic_cpp_line(out, "  std::ifstream input(argv[1]);")
  atomic_cpp_line(
    out, "  std::ofstream result(argv[2], std::ios::binary | std::ios::trunc);",
  )
  atomic_cpp_line(out, "  if (!input || !result) return 65;")
  atomic_cpp_line(out, "  Model top;")
  for port in ports {
    if port.direction == Input {
      atomic_cpp_line(out, "  top.\{port.emitted_name} = 0;")
    }
  }
  atomic_cpp_line(out, "  top.eval();")
  atomic_cpp_line(out, "  std::string line;")
  atomic_cpp_line(
    out, "  if (!std::getline(input, line) || line != \"LUNACHIP-VERILATOR-STIMULUS\\t2\") return 66;",
  )
  atomic_cpp_line(
    out,
    "  if (!std::getline(input, line) || line != \"TIMEBASE\\t\{stimulus.ticks_per_source_unit()}\") return 66;",
  )
  atomic_cpp_line(
    out,
    "  if (!std::getline(input, line) || line != \"DOMAINS\\t\{stimulus.domains().length()}\") return 66;",
  )
  for domain in stimulus.domains() {
    atomic_cpp_line(
      out,
      "  if (!std::getline(input, line) || line != \"DOMAIN\\t\{domain.id()}\\t\{domain.clock_port()}\\trising\") return 66;",
    )
  }
  atomic_cpp_line(out, "  if (!std::getline(input, line)) return 66;")
  atomic_cpp_line(out, "  auto count_row = cells(line);")
  atomic_cpp_line(out, "  std::uint64_t event_count = 0;")
  atomic_cpp_line(
    out, "  if (count_row.size() != 2 || count_row[0] != \"EVENTS\" || !parse_u64(count_row[1], event_count)) return 66;",
  )
  atomic_cpp_line(
    out, "  for (std::uint64_t ordinal = 0; ordinal < event_count; ++ordinal) {",
  )
  atomic_cpp_line(out, "    if (!std::getline(input, line)) return 66;")
  atomic_cpp_line(out, "    const auto event = cells(line);")
  atomic_cpp_line(
    out, "    std::uint64_t parsed_ordinal = 0, time = 0, boundary = 0, drive_count = 0, domain_count = 0;",
  )
  atomic_cpp_line(
    out, "    if (event.size() != 6 || event[0] != \"EVENT\" || !parse_u64(event[1], parsed_ordinal) || parsed_ordinal != ordinal || !parse_u64(event[2], time) || !parse_u64(event[3], boundary) || !parse_u64(event[4], drive_count) || !parse_u64(event[5], domain_count)) return 66;",
  )
  for port in ports {
    if port.direction == Input && port.signal_type.is_clock() {
      atomic_cpp_line(out, "    top.\{port.emitted_name} = 0;")
    }
  }
  atomic_cpp_line(
    out, "    for (std::uint64_t drive = 0; drive < drive_count; ++drive) {",
  )
  atomic_cpp_line(out, "      if (!std::getline(input, line)) return 66;")
  atomic_cpp_line(out, "      const auto row = cells(line);")
  atomic_cpp_line(out, "      std::uint64_t value = 0;")
  if inputs.is_empty() {
    atomic_cpp_line(out, "      return 67;")
  } else if one_bit {
    atomic_cpp_line(out, "      if (!parse_bit(row, value)) return 67;")
    for index, port in inputs {
      atomic_cpp_line(
        out,
        "      \{if index == 0 { "if" } else { "else if" }} (row[1] == \"\{port.emitted_name}\") top.\{port.emitted_name} = value;",
      )
    }
  } else {
    atomic_cpp_line(
      out, "      if (row.size() != 5 || row[0] != \"DRIVE\") return 67;",
    )
    for index, port in inputs {
      atomic_cpp_line(
        out,
        "      \{if index == 0 { "if" } else { "else if" }} (row[1] == \"\{port.emitted_name}\") { if (!parse_value(row, \{port.width}, value)) return 67; top.\{port.emitted_name} = value; }",
      )
    }
  }
  if !inputs.is_empty() {
    atomic_cpp_line(out, "      else return 67;")
  }
  atomic_cpp_line(out, "    }")
  atomic_cpp_line(out, "    std::vector<std::uint64_t> active;")
  atomic_cpp_line(
    out, "    for (std::uint64_t edge = 0; edge < domain_count; ++edge) {",
  )
  atomic_cpp_line(out, "      if (!std::getline(input, line)) return 66;")
  atomic_cpp_line(out, "      const auto row = cells(line);")
  atomic_cpp_line(out, "      std::uint64_t id = 0;")
  atomic_cpp_line(
    out, "      if (row.size() != 2 || row[0] != \"DOMAIN\" || !parse_u64(row[1], id)) return 66;",
  )
  atomic_cpp_line(out, "      active.push_back(id);")
  atomic_cpp_line(out, "    }")
  atomic_cpp_line(out, "    top.eval();")
  atomic_cpp_line(out, "    for (const auto id : active) {")
  for index, domain in stimulus.domains() {
    atomic_cpp_line(
      out,
      "      \{if index == 0 { "if" } else { "else if" }} (id == \{domain.id()}U) top.\{domain.clock_port()} = 1;",
    )
  }
  atomic_cpp_line(out, "      else return 68;")
  if edge_mode == SequentialEdges {
    atomic_cpp_line(out, "      top.eval();")
  }
  atomic_cpp_line(out, "    }")
  if edge_mode == AtomicEdges {
    atomic_cpp_line(out, "    top.eval();")
  }
  atomic_cpp_line(out, "    result << time << '\\t' << boundary;")
  for output in outputs {
    if one_bit {
      atomic_cpp_line(
        out,
        "    result << '\\t' << (static_cast<std::uint64_t>(top.\{output.emitted_name}) & 1U);",
      )
    } else {
      atomic_cpp_line(
        out,
        "    result << '\\t' << render_hex(static_cast<std::uint64_t>(top.\{output.emitted_name}), \{output.width});",
      )
    }
  }
  atomic_cpp_line(out, "    result << '\\n';")
  atomic_cpp_line(out, "  }")
  atomic_cpp_line(
    out, "  if (!std::getline(input, line) || line != \"END\") return 66;",
  )
  atomic_cpp_line(out, "  if (std::getline(input, line)) return 66;")
  atomic_cpp_line(out, "  top.final();")
  atomic_cpp_line(out, "  return result ? 0 : 74;")
  atomic_cpp_line(out, "}")
  let body = out.to_string()
  let header = result_prefix.replace(old="\n", new="\\n") +
    atomic_result_header(outputs)
  body.replace(
    old="  Model top;\n",
    new="  result << \"\{header}\";\n  Model top;\n",
  )
}
