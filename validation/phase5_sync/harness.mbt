///|
fn cpp_line(out : StringBuilder, line : String) -> Unit {
  out.write_string(line)
  out.write_char('\n')
}

///|
fn emitted_clock_port(
  ports : ReadOnlyArray[@verilator.HarnessPort],
  source_name : String,
) -> String raise SyncFixtureError {
  for port in ports {
    if port.is_input() &&
      port.signal_type().is_clock() &&
      port.source_name() == source_name {
      return port.emitted_name()
    }
  }
  raise MissingDomainClock(-1)
}

///|
fn harness_manifest_json(
  emitted : @systemverilog.EmittedDesign,
  ports : ReadOnlyArray[@verilator.HarnessPort],
  stimulus : @verilator.AtomicStimulus,
  harness_filename : String,
) -> String raise {
  guard emitted.modules().get(emitted.manifest().top_module_ordinal())
    is Some(top) else {
    raise MissingTopModule
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
      "    { \"name\": \"\{port.emitted_name()}\", \"direction\": \"\{if port.is_input() { "input" } else { "output" }}\", \"width\": \{port.width()}, \"signed\": \{if port.signal_type() is SInt(_) { "true" } else { "false" }} }",
    )
    out.write_string(if index + 1 == ports.length() { "\n" } else { ",\n" })
  }
  out.write_string("  ]\n}\n")
  out.to_string()
}

///|
fn cpp_result_header(outputs : ArrayView[@verilator.HarnessPort]) -> String {
  let out = StringBuilder()
  out.write_string("time\\tboundary")
  for output in outputs {
    out.write_string("\\t\{output.source_name()}")
  }
  out.write_string("\\n")
  out.to_string()
}

///|
fn atomic_harness_cpp(
  kind : SyncFixtureKind,
  design : @ir.Design,
  ports : ReadOnlyArray[@verilator.HarnessPort],
  stimulus : @verilator.AtomicStimulus,
  sequential_edges : Bool,
) -> String raise {
  let inputs = @verilator.input_ports(ports)
  let outputs = @verilator.output_ports(ports)
  let out = StringBuilder()
  cpp_line(out, "#include \"Vlunachip_model.h\"")
  cpp_line(out, "#include \"verilated.h\"")
  cpp_line(out, "#include <cstdint>")
  cpp_line(out, "#include <fstream>")
  cpp_line(out, "#include <iostream>")
  cpp_line(out, "#include <limits>")
  cpp_line(out, "#include <string>")
  cpp_line(out, "#include <vector>")
  cpp_line(out, "using Model = Vlunachip_model;")
  cpp_line(
    out, "static std::vector<std::string> cells(const std::string& line) {",
  )
  cpp_line(out, "  std::vector<std::string> result;")
  cpp_line(out, "  std::size_t begin = 0;")
  cpp_line(out, "  for (;;) {")
  cpp_line(out, "    const auto tab = line.find('\\t', begin);")
  cpp_line(out, "    result.push_back(line.substr(begin, tab - begin));")
  cpp_line(out, "    if (tab == std::string::npos) break;")
  cpp_line(out, "    begin = tab + 1;")
  cpp_line(out, "  }")
  cpp_line(out, "  return result;")
  cpp_line(out, "}")
  cpp_line(
    out, "static bool parse_u64(const std::string& text, std::uint64_t& value) {",
  )
  cpp_line(
    out, "  if (text.empty() || (text.size() > 1 && text[0] == '0')) return false;",
  )
  cpp_line(out, "  value = 0;")
  cpp_line(out, "  for (char c : text) {")
  cpp_line(out, "    if (c < '0' || c > '9') return false;")
  cpp_line(out, "    const auto digit = static_cast<std::uint64_t>(c - '0');")
  cpp_line(
    out, "    if (value > (std::numeric_limits<std::uint64_t>::max() - digit) / 10U) return false;",
  )
  cpp_line(out, "    value = value * 10U + digit;")
  cpp_line(out, "  }")
  cpp_line(out, "  return true;")
  cpp_line(out, "}")
  cpp_line(
    out, "static bool parse_bit(const std::vector<std::string>& row, std::uint64_t& value) {",
  )
  cpp_line(
    out, "  if (row.size() != 5 || row[0] != \"DRIVE\" || row[2] != \"1\" || row[4] != \"1\") return false;",
  )
  cpp_line(out, "  if (row[3] == \"0\") { value = 0; return true; }")
  cpp_line(out, "  if (row[3] == \"1\") { value = 1; return true; }")
  cpp_line(out, "  return false;")
  cpp_line(out, "}")
  cpp_line(out, "int main(int argc, char** argv) {")
  cpp_line(out, "  Verilated::commandArgs(argc, argv);")
  cpp_line(out, "  if (argc != 3) return 64;")
  cpp_line(out, "  std::ifstream input(argv[1]);")
  cpp_line(
    out, "  std::ofstream result(argv[2], std::ios::binary | std::ios::trunc);",
  )
  cpp_line(out, "  if (!input || !result) return 65;")
  cpp_line(out, "  Model top;")
  for port in ports {
    if port.is_input() {
      cpp_line(out, "  top.\{port.emitted_name()} = 0;")
    }
  }
  cpp_line(out, "  top.eval();")
  cpp_line(out, "  std::string line;")
  cpp_line(
    out, "  if (!std::getline(input, line) || line != \"LUNACHIP-VERILATOR-STIMULUS\\t2\") return 66;",
  )
  cpp_line(
    out,
    "  if (!std::getline(input, line) || line != \"TIMEBASE\\t\{stimulus.ticks_per_source_unit()}\") return 66;",
  )
  cpp_line(
    out,
    "  if (!std::getline(input, line) || line != \"DOMAINS\\t\{stimulus.domains().length()}\") return 66;",
  )
  for domain in stimulus.domains() {
    let clock = domain.clock_port()
    cpp_line(
      out,
      "  if (!std::getline(input, line) || line != \"DOMAIN\\t\{domain.id()}\\t\{clock}\\trising\") return 66;",
    )
  }
  cpp_line(out, "  if (!std::getline(input, line)) return 66;")
  cpp_line(out, "  auto count_row = cells(line);")
  cpp_line(out, "  std::uint64_t event_count = 0;")
  cpp_line(
    out, "  if (count_row.size() != 2 || count_row[0] != \"EVENTS\" || !parse_u64(count_row[1], event_count)) return 66;",
  )
  cpp_line(
    out, "  for (std::uint64_t ordinal = 0; ordinal < event_count; ++ordinal) {",
  )
  cpp_line(out, "    if (!std::getline(input, line)) return 66;")
  cpp_line(out, "    const auto event = cells(line);")
  cpp_line(
    out, "    std::uint64_t parsed_ordinal = 0, time = 0, boundary = 0, drive_count = 0, domain_count = 0;",
  )
  cpp_line(
    out, "    if (event.size() != 6 || event[0] != \"EVENT\" || !parse_u64(event[1], parsed_ordinal) || parsed_ordinal != ordinal || !parse_u64(event[2], time) || !parse_u64(event[3], boundary) || !parse_u64(event[4], drive_count) || !parse_u64(event[5], domain_count)) return 66;",
  )
  for port in ports {
    if port.is_input() && port.signal_type().is_clock() {
      cpp_line(out, "    top.\{port.emitted_name()} = 0;")
    }
  }
  cpp_line(
    out, "    for (std::uint64_t drive = 0; drive < drive_count; ++drive) {",
  )
  cpp_line(out, "      if (!std::getline(input, line)) return 66;")
  cpp_line(out, "      const auto row = cells(line);")
  cpp_line(out, "      std::uint64_t value = 0;")
  cpp_line(out, "      if (!parse_bit(row, value)) return 67;")
  for index, port in inputs {
    cpp_line(
      out,
      "      \{if index == 0 { "if" } else { "else if" }} (row[1] == \"\{port.emitted_name()}\") top.\{port.emitted_name()} = value;",
    )
  }
  cpp_line(out, "      else return 67;")
  cpp_line(out, "    }")
  cpp_line(out, "    std::vector<std::uint64_t> active;")
  cpp_line(
    out, "    for (std::uint64_t edge = 0; edge < domain_count; ++edge) {",
  )
  cpp_line(out, "      if (!std::getline(input, line)) return 66;")
  cpp_line(out, "      const auto row = cells(line);")
  cpp_line(out, "      std::uint64_t id = 0;")
  cpp_line(
    out, "      if (row.size() != 2 || row[0] != \"DOMAIN\" || !parse_u64(row[1], id)) return 66;",
  )
  cpp_line(out, "      active.push_back(id);")
  cpp_line(out, "    }")
  cpp_line(out, "    top.eval();")
  cpp_line(out, "    for (const auto id : active) {")
  for index, domain in stimulus.domains() {
    let clock = emitted_clock_port(ports, domain_clock_name(kind, domain.id()))
    cpp_line(
      out,
      "      \{if index == 0 { "if" } else { "else if" }} (id == \{domain.id()}U) top.\{clock} = 1;",
    )
  }
  cpp_line(out, "      else return 68;")
  if sequential_edges {
    cpp_line(out, "      top.eval();")
  }
  cpp_line(out, "    }")
  if !sequential_edges {
    cpp_line(out, "    top.eval();")
  }
  cpp_line(out, "    result << time << '\\t' << boundary;")
  for output in outputs {
    cpp_line(
      out,
      "    result << '\\t' << (static_cast<std::uint64_t>(top.\{output.emitted_name()}) & 1U);",
    )
  }
  cpp_line(out, "    result << '\\n';")
  cpp_line(out, "  }")
  cpp_line(
    out, "  if (!std::getline(input, line) || line != \"END\") return 66;",
  )
  cpp_line(out, "  if (std::getline(input, line)) return 66;")
  cpp_line(out, "  top.final();")
  cpp_line(out, "  return result ? 0 : 74;")
  cpp_line(out, "}")
  let body = out.to_string()
  let header = result_identity_prefix(
      design,
      stimulus.to_tsv(),
      stimulus.ticks_per_source_unit(),
    ).replace(old="\n", new="\\n") +
    cpp_result_header(outputs)
  body.replace(
    old="  Model top;\n",
    new="  result << \"\{header}\";\n  Model top;\n",
  )
}
