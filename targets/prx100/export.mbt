///|
fn digest(text : String) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode(text)))
}

///|
fn mapped(
  emitted : @systemverilog.EmittedDesign,
  name : String,
  kind : @systemverilog.SymbolKind,
) -> String raise BoardError {
  for item in emitted.manifest().mappings() {
    if item.kind() == kind && item.source_name() == name {
      return item.identifier()
    }
  }
  raise MissingMapping(name)
}

///|
fn sv_range(width : Int32) -> String {
  if width == 1 {
    ""
  } else {
    "[\{width - 1}:0] "
  }
}

///|
// Vivado requires an explicit input net kind with `default_nettype none`.
// Keep this target normalization outside the portable emitter and canonical IR.
fn explicit_input_nets(source : String) -> String {
  source
  .split("\n")
  .map(line => {
    if line.has_prefix("  input logic ") {
      "  input wire logic " + line[14:].to_owned()
    } else {
      line.to_owned()
    }
  })
  .to_array()
  .join("\n")
}

///|
fn system_wrapper(
  hardware : @ir.Module,
  shell_hw : @ir.Module,
  emitted_core : @systemverilog.EmittedDesign,
  emitted_shell : @systemverilog.EmittedDesign,
  raw_bytes : Bool,
) -> String raise {
  let out = StringBuilder()
  out.write_string("module prx100_system(input wire clock, input wire reset,\n")
  out.write_string(
    if raw_bytes {
      "  input wire rx_valid, input wire [7:0] rx_data, input wire rx_error, input wire tx_ready,\n  output wire tx_valid, output wire [7:0] tx_data);\n"
    } else {
      "  input wire uart_rx, output wire uart_tx);\n"
    },
  )
  out.write_string("  wire core_reset;\n")
  for node in hardware.nodes() {
    if node.kind() is Input(name) && name != "clock" && name != "reset" {
      out.write_string(
        "  wire \{sv_range(node.signal_type().width().bits())}d_\{name};\n",
      )
    }
  }
  for port in hardware.outputs() {
    out.write_string(
      "  wire \{sv_range(port.signal_type().width().bits())}d_\{port.name()};\n",
    )
  }
  let core_connections : Array[String] = []
  for node in hardware.nodes() {
    if node.kind() is Input(name) {
      let net = match name {
        "clock" => "clock"
        "reset" => "core_reset"
        _ => "d_" + name
      }
      core_connections.push(
        "    .\{mapped(emitted_core, name, InputPort)}(\{net})",
      )
    }
  }
  for port in hardware.outputs() {
    core_connections.push(
      "    .\{mapped(emitted_core, port.name(), OutputPort)}(d_\{port.name()})",
    )
  }
  out.write_string(
    "  \{emitted_core.modules()[0].identifier()} core_i(\n\{core_connections.join(",\n")}\n  );\n",
  )
  let shell_connections : Array[String] = []
  for node in shell_hw.nodes() {
    if node.kind() is Input(name) {
      let net = if name.has_prefix("c_") {
        "d_" + name[2:].to_owned()
      } else {
        name
      }
      shell_connections.push(
        "    .\{mapped(emitted_shell, name, InputPort)}(\{net})",
      )
    }
  }
  for port in shell_hw.outputs() {
    let name = port.name()
    let net = if name == "core_reset" ||
      name == "uart_tx" ||
      name == "tx_valid" ||
      name == "tx_data" {
      name
    } else {
      "d_" + name
    }
    shell_connections.push(
      "    .\{mapped(emitted_shell, name, OutputPort)}(\{net})",
    )
  }
  out.write_string(
    "  \{emitted_shell.modules()[0].identifier()} shell_i(\n\{shell_connections.join(",\n")}\n  );\nendmodule\n",
  )
  out.to_string()
}

///|
fn physical_wrapper() -> String {
  let source =
    #|// Target boundary only: startup primitive and reset conditioner.
    #|module prx100_top(input wire clk50, input wire reset_n,
    #|  input wire uart_rx, output wire uart_tx);
    #|  wire eos;
    #|  STARTUPE2 startup_i(.EOS(eos), .CFGCLK(), .CFGMCLK(), .PREQ(),
    #|    .CLK(1'b0), .GSR(1'b0), .GTS(1'b0), .KEYCLEARB(1'b1), .PACK(1'b0),
    #|    .USRCCLKO(1'b0), .USRCCLKTS(1'b1), .USRDONEO(1'b1), .USRDONETS(1'b1));
    #|  (* ASYNC_REG = "TRUE" *) reg [1:0] reset_pipe = 2'b11;
    #|  wire reset_async = !reset_n || !eos;
    #|  always @(posedge clk50 or posedge reset_async)
    #|    if (reset_async) reset_pipe <= 2'b11;
    #|    else reset_pipe <= {reset_pipe[0], 1'b0};
    #|  prx100_system system_i(.clock(clk50), .reset(reset_pipe[1]),
    #|    .uart_rx(uart_rx), .uart_tx(uart_tx));
    #|endmodule
    #|
  source
}

///|
fn constraints() -> String {
  let source =
    #|set_property PACKAGE_PIN D18 [get_ports clk50]
    #|set_property PACKAGE_PIN M4 [get_ports reset_n]
    #|set_property PACKAGE_PIN L17 [get_ports uart_rx]
    #|set_property PACKAGE_PIN L18 [get_ports uart_tx]
    #|set_property IOSTANDARD LVCMOS33 [get_ports {clk50 reset_n uart_rx uart_tx}]
    #|create_clock -name clk50 -period 20.000 [get_ports clk50]
    #|set_input_delay -clock clk50 0.000 [get_ports uart_rx]
    #|set_output_delay -clock clk50 0.000 [get_ports uart_tx]
    #|set_false_path -from [get_ports reset_n]
    #|
  source
}

///|
/// Deterministic input bundle. Actual tool execution is a separate operation.
pub fn export_bundle(profile : Profile) -> ReadOnlyArray[Artifact] raise {
  export_inputs(profile, false)
}

///|
/// Digital byte-handshake integration bundle, never a board build input.
pub fn export_byte_test(profile : Profile) -> ReadOnlyArray[Artifact] raise {
  export_inputs(profile, true)
}

///|
fn export_inputs(
  profile : Profile,
  raw_bytes : Bool,
) -> ReadOnlyArray[Artifact] raise {
  let hardware = core(profile)
  let shell_hw = if raw_bytes { byte_shell(profile) } else { shell(profile) }
  let core_design = @ir.Design::single(
    "phase6-fetched-concurrent-\{profile.rows()}x\{profile.rows()}-k\{profile.reduction()}-two-slots",
    hardware,
  )
  let shell_design = @ir.Design::single("prx100-shell", shell_hw)
  let emitted_core = @systemverilog.emit_design(core_design)
  let emitted_shell = @systemverilog.emit_design(shell_design)
  let artifacts : Array[Artifact] = [
    {
      path: "capabilities.json",
      content: @capabilities.Capabilities::new(
        rows=profile.rows(),
        columns=profile.rows(),
        max_reduction=profile.reduction(),
        host_bytes=4096UL,
        ring_depth=4,
        queue_depth=3,
      ).manifest(),
    },
    { path: "core.lcir", content: @codec.serialize(core_design), },
    { path: "shell.lcir", content: @codec.serialize(shell_design), },
    {
      path: "core.names",
      content: emitted_core.manifest().to_canonical_text(),
    },
    {
      path: "shell.names",
      content: emitted_shell.manifest().to_canonical_text(),
    },
    {
      path: "prx100_system.sv",
      content: system_wrapper(
        hardware, shell_hw, emitted_core, emitted_shell, raw_bytes,
      ),
    },
  ]
  let source_files : Array[String] = []
  for
    (module_hw, emitted) in [
      (hardware, emitted_core),
      (shell_hw, emitted_shell),
    ] {
    let source = emitted.modules()[0]
    artifacts.push({
      path: source.filename(),
      content: explicit_input_nets(native_equality(source.source(), module_hw)),
    })
    source_files.push(source.filename())
  }
  source_files.push("prx100_system.sv")
  artifacts.push({
    path: "target.json",
    content: "{\"schema\":\"lunachip.prx100-target/v1\",\"physical\":\{!raw_bytes},\"part\":\"xc7a100tfgg676-2\",\"rows\":\{profile.rows()},\"columns\":\{profile.rows()},\"max_reduction\":\{profile.reduction()},\"host_bytes\":4096,\"ring_depth\":4,\"queue_depth\":3,\"clock_hz\":50000000,\"uart_divisor\":434,\"transport\":\"0.1\",\"device_abi\":\"1.0\",\"descriptor_encoding\":\"0.2\",\"rtl_normalization\":\"explicit-input-wire-native-equality-v2\",\"fpga_demonstrated\":false}\n",
  })
  let sources = source_files
    .map(path => {
      "{\"path\":\"\{path}\",\"sha256\":\"\{digest(artifacts[artifacts.search_by(a => a.path == path).unwrap()].content)}\"}"
    })
    .join(",")
  artifacts.push({
    path: "job.json",
    content: "{\"schema_version\":\"lunachip.yosys-job/v1\",\"top_module\":\"prx100_system\",\"sources\":[\{sources}],\"formal_tasks\":[]}\n",
  })
  if !raw_bytes {
    artifacts.push({ path: "prx100_top.sv", content: physical_wrapper(), })
    artifacts.push({ path: "prx100.xdc", content: constraints(), })
    artifacts.push({
      path: "build.tcl",
      content: build_tcl(source_files, shell_hw),
    })
  }
  let inventory = artifacts
    .map(a => "\{digest(a.content)}  \{a.path}\n")
    .join("")
  artifacts.push({ path: "SHA256SUMS", content: inventory, })
  ReadOnlyArray::from_array(artifacts)
}
