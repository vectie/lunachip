///|
pub struct Artifact {
  path : String
  content : String
}

///|
priv struct Step {
  label : String
  reset : String
  enable : UInt64
  data : UInt64
  edge : Bool
  diagnostic : Bool
}

///|
fn step(
  label : String,
  reset : String,
  enable : UInt64,
  data : UInt64,
  edge : Bool,
  diagnostic~ : Bool = false,
) -> Step {
  { label, reset, enable, data, edge, diagnostic, }
}

///|
fn steps() -> Array[Step] {
  [
    step("binary_assert_between_edges", "assert", 0UL, 255UL, false),
    step("binary_release_holds", "release", 1UL, 90UL, false),
    step("enabled_edge_load", "release", 1UL, 90UL, true),
    step("disabled_edge_holds", "release", 0UL, 255UL, true),
    step("binary_assert_enabled_between_edges", "assert", 1UL, 0UL, false),
    step("binary_assert_dominates_enabled_edge", "assert", 1UL, 255UL, true),
    step("reload_for_x_hold", "release", 1UL, 90UL, true),
    step("x_between_edges_disabled", "x", 0UL, 195UL, false),
    step("x_clock_disabled", "x", 0UL, 195UL, true),
    step("x_to_known_assert", "assert", 0UL, 0UL, false),
    step("assert_to_x_disabled", "x", 0UL, 255UL, false),
    step("recover_from_x", "assert", 0UL, 0UL, false),
    step("reload_for_z_hold", "release", 1UL, 90UL, true),
    step("z_between_edges_disabled", "z", 0UL, 195UL, false),
    step("z_clock_disabled", "z", 0UL, 195UL, true),
    step("z_to_known_assert", "assert", 0UL, 0UL, false),
    step("assert_to_z_disabled", "z", 0UL, 255UL, false),
    step("recover_from_z", "assert", 0UL, 0UL, false),
    step("reload_for_x_edge", "release", 1UL, 90UL, true),
    step("x_clock_enabled", "x", 1UL, 195UL, true),
    step("held_x_clock_new_enabled_data", "x", 1UL, 240UL, true),
    step("recover_after_x_edge", "assert", 1UL, 0UL, false),
    step("reload_for_z_edge", "release", 1UL, 90UL, true),
    step("z_clock_enabled", "z", 1UL, 195UL, true),
    step("held_z_clock_new_enabled_data", "z", 1UL, 15UL, true),
    step("recover_after_z_edge", "assert", 1UL, 0UL, false),
    step("seed_x_diagnostic", "release", 1UL, 90UL, true),
    step(
      "xfail_x_between_edges_enabled",
      "x",
      1UL,
      195UL,
      false,
      diagnostic=true,
    ),
    step("recover_x_diagnostic", "assert", 1UL, 0UL, false),
    step("seed_z_diagnostic", "release", 1UL, 90UL, true),
    step(
      "xfail_z_between_edges_enabled",
      "z",
      1UL,
      195UL,
      false,
      diagnostic=true,
    ),
    step("final_binary_recovery", "assert", 0UL, 0UL, false),
  ]
}

///|
fn fixture() -> @ir.Module raise {
  let clock = @ir.NodeId::new(0)
  let high = @ir.NodeId::new(1)
  let low = @ir.NodeId::new(2)
  let enable = @ir.NodeId::new(3)
  let data = @ir.NodeId::new(4)
  let state_high = @ir.NodeId::new(5)
  let state_low = @ir.NodeId::new(6)
  let domain = @ir.ClockDomain::rising(clock)
  let u8 = @ir.SignalType::UInt(@ir.Width::new(8))
  @ir.Module::checked_with_metadata(
    "AsyncResetFourState",
    [domain],
    [
      @ir.Node::new(clock, Clock, Input("clock")),
      @ir.Node::new(high, Reset, Input("reset_high")),
      @ir.Node::new(low, Reset, Input("reset_low")),
      @ir.Node::new(enable, Bits(@ir.Width::new(1)), Input("enable")),
      @ir.Node::new(data, u8, Input("data")),
      @ir.Node::new(
        state_high,
        u8,
        Register(
          @ir.RegisterSpec::new(
            domain,
            data,
            reset=@ir.ResetSpec::explicit(high, 165UL, Asynchronous, ActiveHigh),
            enable~,
          ),
        ),
      ),
      @ir.Node::new(
        state_low,
        u8,
        Register(
          @ir.RegisterSpec::new(
            domain,
            data,
            reset=@ir.ResetSpec::explicit(low, 60UL, Asynchronous, ActiveLow),
            enable~,
          ),
        ),
      ),
    ],
    [],
    [
      @ir.OutputPort::new("state_high", u8, state_high),
      @ir.OutputPort::new("state_low", u8, state_low),
    ],
    @ir.ModuleMetadata::checked_complete(
      [],
      [],
      [
        @ir.InputTimingBinding::new(high, Asynchronous),
        @ir.InputTimingBinding::new(low, Asynchronous),
        @ir.InputTimingBinding::new(enable, SampledIn(domain.id())),
        @ir.InputTimingBinding::new(data, SampledIn(domain.id())),
      ],
      [
        @ir.OutputTimingBinding::checked("state_high", ProducedIn(domain.id())),
        @ir.OutputTimingBinding::checked("state_low", ProducedIn(domain.id())),
      ],
      [],
    ),
  )
}

///|
fn known(width : Int32, value : UInt64) -> @wave.LogicValue raise {
  @wave.LogicValue::from_uint64(width~, value~)
}

///|
fn reset_value(reset : String, high : Bool) -> @wave.LogicValue raise {
  match reset {
    "assert" => known(1, if high { 1UL } else { 0UL })
    "release" => known(1, if high { 0UL } else { 1UL })
    "x" | "z" => @wave.LogicValue::unknown(width=1)
    _ => fail("invalid fixture reset")
  }
}

///|
fn reset_literal(reset : String, high : Bool) -> String {
  match reset {
    "assert" => if high { "1'b1" } else { "1'b0" }
    "release" => if high { "1'b0" } else { "1'b1" }
    _ => "1'b" + reset
  }
}

///|
fn identifier(
  emitted : @systemverilog.EmittedDesign,
  kind : @systemverilog.SymbolKind,
  name : String,
) -> String raise {
  for mapping in emitted.manifest().mappings() {
    if mapping.kind() == kind && mapping.source_name() == name {
      return mapping.identifier()
    }
  }
  fail("missing emitted identifier " + name)
}

///|
fn baseline(source : String) -> String raise {
  let output = StringBuilder()
  let mut removed = 0
  let mut alternatives = 0
  for line in source.split("\n") {
    let text = line.to_owned()
    if text.has_prefix("    if (") && text.contains(" <= ") {
      removed += 1
    } else if text.has_prefix("    else ") {
      alternatives += 1
      output.write_string("    " + text[9:].to_owned() + "\n")
    } else {
      output.write_string(text + "\n")
    }
  }
  guard removed == 2 && alternatives == 2 else {
    fail("baseline reconstruction requires exactly two async reset branches")
  }
  output.to_string().trim_end().to_owned() + "\n"
}

///|
pub fn bundle() -> Array[Artifact] raise {
  let hardware = fixture()
  let design = @ir.Design::single("reset_four_state", hardware)
  let emitted = @systemverilog.emit_design(design)
  let simulator = @sim.Simulator::prepare(hardware)
  let header = "event\tlabel\treset\tenable\tdata\tedge\tscope\tstate_high\tstate_low\n"
  let wave = StringBuilder()
  let vendor = StringBuilder()
  wave.write_string(header)
  vendor.write_string(header)
  let bench = StringBuilder()
  bench.write_string("`timescale 1ns/1ps\nmodule reset4state_tb;\n")
  bench.write_string(
    "  reg clock=0, reset_high=0, reset_low=1, enable=0;\n  reg [7:0] data=0;\n  wire [7:0] state_high, state_low;\n  integer trace, receipt;\n",
  )
  bench.write_string("  " + emitted.modules()[0].identifier() + " dut(\n")
  let ports = [
    "clock", "reset_high", "reset_low", "enable", "data", "state_high", "state_low",
  ]
  for index, port in ports {
    let kind = if index < 5 {
      @systemverilog.SymbolKind::InputPort
    } else {
      OutputPort
    }
    let ending = if index < 6 { ",\n" } else { "\n  );\n" }
    bench.write_string(
      "    ." + identifier(emitted, kind, port) + "(" + port + ")" + ending,
    )
  }
  bench.write_string(
    "  initial begin\n    trace=$fopen(\"actual.tsv\",\"w\");\n    if (!trace) $fatal(1,\"trace unavailable\");\n    $fdisplay(trace,\"" +
    header.trim_end().to_owned() +
    "\");\n",
  )
  let domain = @ir.ClockDomain::rising(@ir.NodeId::new(0)).id()
  for index, item in steps() {
    let drives = [
      @sim.InputDrive::checked("reset_high", reset_value(item.reset, true)),
      @sim.InputDrive::checked("reset_low", reset_value(item.reset, false)),
      @sim.InputDrive::checked("enable", known(1, item.enable)),
      @sim.InputDrive::checked("data", known(8, item.data)),
    ]
    simulator.apply_event(
      @sim.TimestampEvent::checked(
        @sim.SimulationTime::from_uint64((index + 1).to_uint64()),
        drives,
        if item.edge {
          [domain]
        } else {
          []
        },
      ),
    )
    let wave_high = simulator.output("state_high").to_bit_string()
    let wave_low = simulator.output("state_low").to_bit_string()
    let high = if item.diagnostic {
      @wave.LogicValue::unknown(width=1)
      .mux(known(8, 165UL), known(8, item.data))
      .to_bit_string()
    } else {
      wave_high
    }
    let low = if item.diagnostic {
      @wave.LogicValue::unknown(width=1)
      .mux(known(8, 60UL), known(8, item.data))
      .to_bit_string()
    } else {
      wave_low
    }
    if item.diagnostic {
      assert_true(high != wave_high && low != wave_low)
    }
    let scope = if item.diagnostic {
      "expected-divergence"
    } else {
      "acceptance"
    }
    let prefix = index.to_string() +
      "\t" +
      item.label +
      "\t" +
      item.reset +
      "\t" +
      item.enable.to_string() +
      "\t" +
      item.data.to_string() +
      "\t" +
      item.edge.to_string() +
      "\t" +
      scope
    wave.write_string(prefix + "\t" + wave_high + "\t" + wave_low + "\n")
    vendor.write_string(prefix + "\t" + high + "\t" + low + "\n")
    let edge_drive = if item.edge { "clock=1;\n" } else { "// no clock edge\n" }
    bench.write_string(
      "    #8; reset_high=" +
      reset_literal(item.reset, true) +
      "; reset_low=" +
      reset_literal(item.reset, false) +
      "; enable=1'd" +
      item.enable.to_string() +
      "; data=8'd" +
      item.data.to_string() +
      ";\n    #1; " +
      edge_drive,
    )
    bench.write_string(
      "    #1; $fdisplay(trace,\"" +
      prefix +
      "\t%b\t%b\",state_high,state_low);\n",
    )
    bench.write_string(
      "    if (state_high !== 8'b" +
      high +
      " || state_low !== 8'b" +
      low +
      ") $fatal(1,\"unexpected result at " +
      item.label +
      " high=%b low=%b\",state_high,state_low);\n",
    )
    if item.diagnostic {
      bench.write_string(
        "    if (state_high === 8'b" +
        wave_high +
        " || state_low === 8'b" +
        wave_low +
        ") $fatal(1,\"expected baseline divergence disappeared\");\n",
      )
      bench.write_string(
        "    $display(\"EXPECTED_DIVERGENCE " +
        item.label +
        " LunaWave=" +
        wave_high +
        "/" +
        wave_low +
        " XSim=%b/%b\",state_high,state_low);\n",
      )
    }
    bench.write_string("    clock=0;\n")
  }
  bench.write_string(
    "    $fclose(trace); receipt=$fopen(\"PASS\",\"w\"); $fdisplay(receipt,\"PASS 30 acceptance events, 2 expected divergence events; both polarities\"); $fclose(receipt);\n    $display(\"RESET4STATE_PASS\"); $finish;\n  end\n  initial begin #1000; $fatal(1,\"watchdog\"); end\nendmodule\n",
  )
  [
    { path: "dut.sv", content: emitted.source(), },
    { path: "baseline-dut.sv", content: baseline(emitted.source()), },
    { path: "canonical.ir", content: @codec.serialize(design), },
    { path: "names.txt", content: emitted.manifest().to_canonical_text(), },
    { path: "expected-lunawave.tsv", content: wave.to_string(), },
    { path: "expected-xsim.tsv", content: vendor.to_string(), },
    { path: "testbench.sv", content: bench.to_string(), },
  ]
}
