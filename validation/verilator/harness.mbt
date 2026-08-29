///|
fn direction_text(direction : PortDirection) -> String {
  match direction {
    Input => "input"
    Output => "output"
  }
}

///|
pub fn harness_json(
  emitted : @systemverilog.EmittedDesign,
  ports : ReadOnlyArray[HarnessPort],
) -> String raise HarnessError {
  guard emitted.modules().get(emitted.manifest().top_module_ordinal())
    is Some(top) else {
    raise MissingEmittedTopModule
  }
  let clock = clock_port(ports)
  let reset = reset_port(ports)
  let output = StringBuilder()
  output.write_string("{\n")
  output.write_string(
    "  \"$schema\": \"https://lunachip.dev/schema/verilator-harness-v1.json\",\n",
  )
  output.write_string(
    "  \"schema_version\": \"lunachip.verilator-harness/v1\",\n",
  )
  output.write_string("  \"top_module\": \"")
  output.write_string(top.identifier())
  output.write_string("\",\n  \"sources\": [")
  for index, source in emitted.modules() {
    if index > 0 {
      output.write_string(", ")
    }
    output.write_string("\"")
    output.write_string(source.filename())
    output.write_string("\"")
  }
  output.write_string("],\n")
  output.write_string("  \"harness_cpp\": \"harness.cpp\",\n")
  output.write_string("  \"stimulus\": \"stimulus.tsv\",\n")
  output.write_string("  \"result\": \"actual.tsv\",\n")
  output.write_string("  \"clock\": { \"port\": \"")
  output.write_string(clock.emitted_name)
  output.write_string("\", \"edge\": \"rising\" },\n")
  output.write_string("  \"reset\": { \"port\": \"")
  output.write_string(reset.emitted_name)
  output.write_string(
    "\", \"active\": \"high\", \"timing\": \"synchronous\" },\n",
  )
  output.write_string("  \"ports\": [\n")
  for index, port in ports {
    output.write_string("    { \"name\": \"")
    output.write_string(port.emitted_name)
    output.write_string("\", \"direction\": \"")
    output.write_string(direction_text(port.direction))
    output.write_string("\", \"width\": ")
    output.write_string(port.width.to_string())
    output.write_string(", \"signed\": ")
    output.write_string(
      if port.signal_type is SInt(_) {
        "true"
      } else {
        "false"
      },
    )
    output.write_string(
      if index + 1 == ports.length() {
        " }\n"
      } else {
        " },\n"
      },
    )
  }
  output.write_string("  ]\n}\n")
  output.to_string()
}

///|
fn cpp_line(output : StringBuilder, line : String) -> Unit {
  output.write_string(line)
  output.write_char('\n')
}

///|
fn cpp_header(ports : ArrayView[HarnessPort]) -> String {
  let output = StringBuilder()
  output.write_string("cycle")
  for port in ports {
    output.write_char('\t')
    output.write_string(port.emitted_name)
  }
  output.to_string()
}

///|
pub fn harness_cpp(
  ports : ReadOnlyArray[HarnessPort],
  identity : @differential.ResultIdentity,
  protocol : ResultProtocol,
) -> String raise HarnessError {
  let clock = clock_port(ports)
  let inputs = input_ports(ports)
  let outputs = output_ports(ports)
  let output = StringBuilder()
  cpp_line(output, "#include \"Vlunachip_model.h\"")
  cpp_line(output, "#include \"verilated.h\"")
  cpp_line(output, "#include <cstdint>")
  cpp_line(output, "#include <fstream>")
  cpp_line(output, "#include <iostream>")
  cpp_line(output, "#include <string>")
  cpp_line(output, "#include <vector>")
  cpp_line(output, "")
  cpp_line(output, "using Model = Vlunachip_model;")
  cpp_line(output, "")
  cpp_line(
    output, "static std::vector<std::string> split_tsv(const std::string& line) {",
  )
  cpp_line(output, "  std::vector<std::string> cells;")
  cpp_line(output, "  std::size_t begin = 0;")
  cpp_line(output, "  for (;;) {")
  cpp_line(output, "    const std::size_t tab = line.find('\\t', begin);")
  cpp_line(output, "    cells.push_back(line.substr(begin, tab - begin));")
  cpp_line(output, "    if (tab == std::string::npos) break;")
  cpp_line(output, "    begin = tab + 1;")
  cpp_line(output, "  }")
  cpp_line(output, "  return cells;")
  cpp_line(output, "}")
  cpp_line(output, "")
  cpp_line(
    output, "static bool parse_cycle(const std::string& text, std::uint64_t& value) {",
  )
  cpp_line(
    output, "  if (text.empty() || (text.size() > 1 && text[0] == '0')) return false;",
  )
  cpp_line(output, "  value = 0;")
  cpp_line(output, "  for (char symbol : text) {")
  cpp_line(output, "    if (symbol < '0' || symbol > '9') return false;")
  cpp_line(
    output, "    const std::uint64_t digit = static_cast<std::uint64_t>(symbol - '0');",
  )
  cpp_line(output, "    if (value > (UINT64_MAX - digit) / 10U) return false;")
  cpp_line(output, "    value = value * 10U + digit;")
  cpp_line(output, "  }")
  cpp_line(output, "  return true;")
  cpp_line(output, "}")
  cpp_line(output, "")
  cpp_line(
    output, "static bool parse_hex(const std::string& text, int width, std::uint64_t& value) {",
  )
  cpp_line(
    output, "  if (text.size() != static_cast<std::size_t>((width + 3) / 4)) return false;",
  )
  cpp_line(output, "  value = 0;")
  cpp_line(output, "  for (char symbol : text) {")
  cpp_line(output, "    std::uint64_t nibble = 0;")
  cpp_line(output, "    if (symbol >= '0' && symbol <= '9') {")
  cpp_line(output, "      nibble = static_cast<std::uint64_t>(symbol - '0');")
  cpp_line(output, "    } else if (symbol >= 'a' && symbol <= 'f') {")
  cpp_line(
    output, "      nibble = static_cast<std::uint64_t>(symbol - 'a' + 10);",
  )
  cpp_line(output, "    } else {")
  cpp_line(output, "      return false;")
  cpp_line(output, "    }")
  cpp_line(output, "    value = (value << 4) | nibble;")
  cpp_line(output, "  }")
  cpp_line(output, "  return width == 64 || (value >> width) == 0;")
  cpp_line(output, "}")
  cpp_line(output, "")
  cpp_line(
    output, "static std::string render_hex(std::uint64_t value, int width) {",
  )
  cpp_line(output, "  static constexpr char digits[] = \"0123456789abcdef\";")
  cpp_line(
    output, "  std::string text(static_cast<std::size_t>((width + 3) / 4), '0');",
  )
  cpp_line(
    output, "  for (std::size_t index = text.size(); index > 0; --index) {",
  )
  cpp_line(output, "    text[index - 1] = digits[value & 15U];")
  cpp_line(output, "    value >>= 4;")
  cpp_line(output, "  }")
  cpp_line(output, "  return text;")
  cpp_line(output, "}")
  cpp_line(output, "")
  cpp_line(output, "int main(int argc, char** argv) {")
  cpp_line(output, "  Verilated::commandArgs(argc, argv);")
  cpp_line(output, "  if (argc != 3) {")
  cpp_line(output, "    std::cerr << \"usage: harness STIMULUS RESULT\\n\";")
  cpp_line(output, "    return 64;")
  cpp_line(output, "  }")
  cpp_line(output, "  std::ifstream stimulus(argv[1]);")
  cpp_line(
    output, "  std::ofstream result(argv[2], std::ios::binary | std::ios::trunc);",
  )
  cpp_line(output, "  if (!stimulus || !result) return 65;")
  cpp_line(output, "  std::string line;")
  output.write_string("  if (!std::getline(stimulus, line) || line != \"")
  output.write_string(cpp_header(inputs))
  cpp_line(output, "\") return 66;")
  output.write_string("  result << \"")
  output.write_string(protocol.magic)
  output.write_string("\\t")
  output.write_string(protocol.version)
  output.write_string("\\t")
  output.write_string(utf8_hex(identity.design().semantic_version()))
  output.write_string("\\tsha256\\t")
  output.write_string(identity.design().design_sha256())
  output.write_string("\\tsha256\\t")
  output.write_string(identity.stimulus_sha256())
  cpp_line(output, "\\n\";")
  output.write_string("  result << \"")
  output.write_string(cpp_header(outputs))
  cpp_line(output, "\\n\";")
  cpp_line(output, "  Model top;")
  cpp_line(output, "  top." + clock.emitted_name + " = 0;")
  cpp_line(output, "  top.eval();")
  cpp_line(output, "  std::uint64_t expected_cycle = 0;")
  cpp_line(output, "  while (std::getline(stimulus, line)) {")
  cpp_line(output, "    const auto cells = split_tsv(line);")
  output.write_string("    if (cells.size() != ")
  output.write_string((inputs.length() + 1).to_string())
  cpp_line(output, ") return 66;")
  cpp_line(output, "    std::uint64_t cycle = 0;")
  cpp_line(
    output, "    if (!parse_cycle(cells[0], cycle) || cycle != expected_cycle) return 66;",
  )
  output.write_string("    std::vector<std::uint64_t> values(")
  output.write_string(inputs.length().to_string())
  cpp_line(output, ");")
  for index, port in inputs {
    cpp_line(
      output,
      "    if (!parse_hex(cells[" +
      (index + 1).to_string() +
      "], " +
      port.width.to_string() +
      ", values[" +
      index.to_string() +
      "])) return 67;",
    )
    cpp_line(
      output,
      "    top." + port.emitted_name + " = values[" + index.to_string() + "];",
    )
  }
  cpp_line(output, "    top." + clock.emitted_name + " = 0;")
  cpp_line(output, "    top.eval();")
  cpp_line(output, "    top." + clock.emitted_name + " = 1;")
  cpp_line(output, "    top.eval();")
  cpp_line(output, "    if (cycle > 0) {")
  cpp_line(output, "      result << cycle;")
  for port in outputs {
    cpp_line(
      output,
      "      result << '\\t' << render_hex(static_cast<std::uint64_t>(top." +
      port.emitted_name +
      "), " +
      port.width.to_string() +
      ");",
    )
  }
  cpp_line(output, "      result << '\\n';")
  cpp_line(output, "    }")
  cpp_line(output, "    expected_cycle += 1;")
  cpp_line(output, "  }")
  cpp_line(output, "  if (expected_cycle == 0) return 66;")
  cpp_line(output, "  top.final();")
  cpp_line(output, "  return result ? 0 : 74;")
  cpp_line(output, "}")
  output.to_string()
}
