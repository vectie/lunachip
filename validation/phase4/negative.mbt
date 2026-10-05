///|
fn negative_design(kind : NegativeFixtureKind) -> @ir.Design raise {
  match kind {
    FaultOutOfBounds => fixture_design(NonPowerOfTwo)
    DynamicRejectCollision =>
      @ir.Design::single("phase4-dynamic-reject", dynamic_reject_module())
  }
}

///|
fn negative_value(
  kind : NegativeFixtureKind,
  cycle : Int,
  name : String,
) -> UInt64 {
  if name == "reset" {
    return if cycle == 0 { 1UL } else { 0UL }
  }
  match kind {
    FaultOutOfBounds =>
      match name {
        "read_address" => if cycle == 0 { 0UL } else { 3UL }
        "read_enable" => if cycle == 0 { 0UL } else { 1UL }
        "write_address0" => 0UL
        "data0" => 0xa5UL
        "write_enable0" => 0UL
        _ => 0UL
      }
    DynamicRejectCollision =>
      match name {
        "address0" | "address1" => 2UL
        "data0" => 0xa5UL
        "data1" => 0x5aUL
        "enable0" | "enable1" => if cycle == 0 { 0UL } else { 1UL }
        _ => 0UL
      }
  }
}

///|
fn negative_stimulus(
  kind : NegativeFixtureKind,
  ports : ReadOnlyArray[@verilator.HarnessPort],
) -> String {
  let inputs = @verilator.input_ports(ports)
  let output = StringBuilder()
  output.write_string(@verilator.tsv_header(inputs))
  for cycle in 0..<=1 {
    output.write_string(cycle.to_string())
    for port in inputs {
      output.write_char('\t')
      output.write_string(
        @verilator.padded_hex(
          negative_value(kind, cycle, port.source_name),
          port.width,
        ),
      )
    }
    output.write_char('\n')
  }
  output.to_string()
}

///|
pub fn generate_negative_bundle(
  kind : NegativeFixtureKind,
) -> NegativeFixtureBundle raise {
  let design = negative_design(kind)
  guard design.top_module() is Some(hardware_module) else {
    raise MissingTopModule
  }
  let emitted = @systemverilog.emit_design(design)
  let ports = @verilator.collect_ports(hardware_module, emitted.manifest())
  let stimulus = negative_stimulus(kind, ports)
  let protocol = result_protocol()
  let design_identity = @differential.DesignIdentity::checked(
    protocol.semantic_version(),
    @verilator.sha256_hex(@ir_codec.serialize(design)),
  )
  let identity = @differential.ResultIdentity::checked(
    design_identity,
    @verilator.sha256_hex(stimulus),
  )
  let json = @verilator.harness_json(emitted, ports)
  let cpp = @verilator.harness_cpp(ports, identity, protocol)
  let artifacts : Array[BundleArtifact] = [
    { path: "design.lcir", content: @ir_codec.serialize(design), },
  ]
  for module_artifact in emitted.modules() {
    artifacts.push({
      path: module_artifact.filename(),
      content: module_artifact.source(),
    })
  }
  artifacts.push({
    path: "names.lcnm",
    content: emitted.manifest().to_canonical_text(),
  })
  artifacts.push({ path: "manifest.json", content: json, })
  artifacts.push({ path: "harness.cpp", content: cpp, })
  artifacts.push({ path: "stimulus.tsv", content: stimulus, })
  artifacts.push({
    path: "expected-failure.txt",
    content: "LUNACHIP-PHASE4-EXPECTED-FAILURE 1\nMARKER " +
    kind.failure_marker() +
    "\n",
  })
  {
    kind,
    artifacts: ReadOnlyArray::from_array(artifacts),
    harness_json: json,
    stimulus_tsv: stimulus,
  }
}
