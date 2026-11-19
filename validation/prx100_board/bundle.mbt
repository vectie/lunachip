///|
fn protocol() -> @verilator.ResultProtocol raise {
  @verilator.ResultProtocol::checked(
    "LUNACHIP-PRX100-RESULT", "1", "prx100-composed-byte-smoke/v0.1",
  )
}

///|
fn ports() -> ReadOnlyArray[@verilator.HarnessPort] raise {
  let result : Array[@verilator.HarnessPort] = []
  for
    (name, signal_type, direction) in [
      ("clock", @wire.clock(), @verilator.PortDirection::Input),
      ("reset", @wire.reset(), Input),
      ("rx_data", @wire.uint(8), Input),
      ("rx_error", @wire.bits(1), Input),
      ("rx_valid", @wire.bits(1), Input),
      ("tx_ready", @wire.bits(1), Input),
      ("tx_data", @wire.uint(8), Output),
      ("tx_valid", @wire.bits(1), Output),
    ] {
    result.push({
      source_name: name,
      emitted_name: name,
      direction,
      width: signal_type.width().bits(),
      signal_type,
    })
  }
  ReadOnlyArray::from_array(result)
}

///|
/// Generate source-bound native expectations for the actual composed core
/// and byte-control shell. Physical UART timing is a separate fixture.
pub fn generate_byte_bundle() -> ReadOnlyArray[@prx100.Artifact] raise {
  let inputs = @prx100.export_byte_test(Smoke)
  let run = bench()
  assert_eq(run.command(0).words[0], 0x50525831U)
  run.workload()
  for _ in 0..<700 {
    run.step()
  }
  assert_eq(run.command(1, arg=256U, data=1U).status, 4)
  for index in 0..<4 {
    for _ in 0..<150 {
      run.step()
    }
    let completion = run.command(5)
    assert_eq(completion.status, 0)
    assert_eq(completion.words[0], (11 + index).reinterpret_as_uint())
    assert_eq(completion.words[1], 0U)
  }
  assert_eq(run.command(2, arg=512U).words[0], 0xffffffc1U)
  assert_eq(run.command(2, arg=4096U).status, 3)
  assert_eq(run.command(8).status, 0)
  assert_eq(run.command(2, arg=256U).words[0], 249U)
  let stimulus = run.stimulus.to_string()
  let expected = run.expected.to_string()
  let identity_text = inputs.map(a => a.path + "\n" + a.content).join("\n")
  let identity = @differential.ResultIdentity::checked(
    @differential.DesignIdentity::checked(
      protocol().semantic_version(),
      @verilator.sha256_hex(identity_text),
    ),
    @verilator.sha256_hex(stimulus),
  )
  let result : Array[@prx100.Artifact] = inputs.iter().to_array()
  let sources = inputs
    .filter(a => a.path.has_suffix(".sv"))
    .map(a => "\"\{a.path}\"")
    .join(",")
  let manifest_ports = ports()
    .map(p => {
      "{\"name\":\"\{p.source_name}\",\"direction\":\"\{if p.is_input() { "input" } else { "output" }}\",\"width\":\{p.width},\"signed\":false}"
    })
    .join(",")
  result.push({
    path: "manifest.json",
    content: "{\"schema_version\":\"lunachip.verilator-harness/v1\",\"top_module\":\"prx100_system\",\"sources\":[\{sources}],\"harness_cpp\":\"harness.cpp\",\"stimulus\":\"stimulus.tsv\",\"result\":\"actual.tsv\",\"clock\":{\"port\":\"clock\",\"edge\":\"rising\"},\"reset\":{\"port\":\"reset\",\"active\":\"high\",\"timing\":\"synchronous\"},\"ports\":[\{manifest_ports}]}\n",
  })
  result.push({
    path: "harness.cpp",
    content: @verilator.harness_cpp(ports(), identity, protocol()),
  })
  result.push({ path: "stimulus.tsv", content: stimulus, })
  result.push({
    path: "expected.tsv",
    content: "\{protocol().magic()}\t1\t\{@verilator.utf8_hex(protocol().semantic_version())}\tsha256\t\{identity.design().design_sha256()}\tsha256\t\{identity.stimulus_sha256()}\n" +
    expected,
  })
  result.push({
    path: "fixture.txt",
    content: "cycles=\{run.cycle - 1}\nprofile=smoke\ninterface=byte-handshake\nexpected_signed_result=-63\n",
  })
  ReadOnlyArray::from_array(result)
}

///|
/// Parse both streams through the existing identity-first comparator.
pub fn audit_byte_replay(
  expected : String,
  actual : String,
  cycles : Int32,
) -> Unit raise {
  let wanted = @verilator.parse_actual_tsv(
    expected,
    ports(),
    cycles,
    protocol(),
  )
  let observed = @verilator.parse_actual_tsv(
    actual,
    ports(),
    cycles,
    protocol(),
  )
  assert_eq(@differential.compare(wanted, observed), Equal)
}
