///|
fn store_guided_admit(
  scenario : StoreCorrespondenceScenario,
  trace : StoreGuidedTrace,
  packet : Array[UInt64],
) -> Unit raise {
  let before = scenario.admissions
  records_present(scenario.source, Some(packet))
  while scenario.admissions == before {
    store_guided_tick(scenario, trace)
  }
  assert_eq(scenario.admissions, before + 1)
  records_present(scenario.source, None)
}

///|
fn store_guided_command(
  scenario : StoreCorrespondenceScenario,
  trace : StoreGuidedTrace,
  packet : Array[UInt64],
  progress : UInt64,
) -> Unit raise {
  let before = scenario.completions.length()
  store_guided_admit(scenario, trace, packet)
  while scenario.completions.length() == before {
    store_guided_tick(scenario, trace)
  }
  assert_eq(scenario.completions.length(), before + 1)
  assert_eq(scenario.completions[before], [73UL, 0UL, progress, 0UL])
}

///|
test "native guided Store original overlap witness records input-only PRE masks below 128 edges" {
  let (scenario, trace) = store_guided_prepare()
  let source = scenario.source
  let observer = scenario.observer
  // K1 is legal within the unchanged K2-capacity ordinary 2x2 device. Reuse
  // the SAME A0/B0 in both computes: C selection, not operand identity,
  // distinguishes the opposite generation required by the original monitor.
  scenario.memory[32] = 2UL
  scenario.memory[35] = 3UL
  scenario.memory[64] = 5UL
  scenario.memory[65] = 7UL
  scenario.memory[256] = 42UL
  let words = @flux_tile.matmul_int8_oracle(
    [2, 3],
    [5, 7],
    rows=2,
    columns=2,
    reduction=1,
  )
  assert_eq(words, [10, 14, 15, 21])
  let expected = scenario.memory.copy()
  store_scenario_expected_words(expected, 512, 16, words)
  store_guided_command(
    scenario,
    trace,
    store_scenario_packet(0UL, rows=2, columns=1, base=32, stride=3),
    2UL,
  )
  store_guided_command(
    scenario,
    trace,
    store_scenario_packet(1UL, rows=1, columns=2, base=64, stride=5),
    2UL,
  )
  store_guided_command(
    scenario,
    trace,
    store_scenario_packet(2UL, rows=2, columns=2, reduction=1),
    0UL,
  )
  store_correspondence_c_words(observer, source, 0, words)
  assert_eq(observer.captures, [4, 0])
  assert_eq(scenario.read_acks, 4)
  assert_eq(scenario.pending, None)
  // This real Loader writes A1, NOT the reused A0. Its input-only fixed delay
  // leaves enough time for the Store read, C1 legal accept and four captures.
  scenario.latency = 40
  store_guided_admit(
    scenario,
    trace,
    store_scenario_packet(0UL, rows=1, columns=1, base=256, stride=1, a=1),
  )
  while scenario.pending is None {
    store_guided_tick(scenario, trace)
  }
  assert_eq(scenario.pending_request, Some([0UL, 256UL, 1UL, 1UL, 0UL, 4UL]))
  assert_eq(store_correspondence_arbiter(observer, source, "state"), 2UL)
  assert_eq(store_correspondence_arbiter(observer, source, "owner"), 0UL)
  store_guided_admit(
    scenario,
    trace,
    store_scenario_packet(3UL, rows=2, columns=2, base=512, stride=16),
  )
  while store_guided_role(scenario, SlottedRegister(Pending)) == 0UL {
    assert_true(scenario.pending is Some(response) && response.delay > 0)
    store_guided_tick(scenario, trace)
  }
  assert_eq(store_guided_role(scenario, StoreRegister(State)), 2UL)
  assert_eq(store_guided_role(scenario, Event(ResponseData)), 10UL)
  assert_eq(store_guided_role(scenario, SlottedRegister(ResponseSlot)), 0UL)
  store_guided_admit(
    scenario,
    trace,
    store_scenario_packet(2UL, rows=2, columns=2, reduction=1, c=1),
  )
  while observer.captures[1] < 4 {
    assert_true(scenario.pending is Some(response) && response.delay > 0)
    assert_eq(store_correspondence_arbiter(observer, source, "state"), 2UL)
    assert_eq(store_correspondence_arbiter(observer, source, "owner"), 0UL)
    assert_eq(store_guided_role(scenario, StoreRegister(State)), 2UL)
    assert_eq(store_guided_role(scenario, SlottedRegister(Pending)), 1UL)
    assert_eq(store_guided_role(scenario, Event(ResponseData)), 10UL)
    store_guided_tick(scenario, trace)
  }
  assert_eq(observer.captures, [4, 4])
  assert_eq(observer.final_captures, [1, 1])
  assert_eq(trace.opposite_accepts, 1)
  assert_eq(trace.intermediate_captures, 3)
  assert_eq(trace.final_captures, 1)
  // Original final-history flag was committed on the preceding edge. Sample
  // one MORE genuine held PRE before allowing the Loader's matching response.
  assert_true(scenario.pending is Some(response) && response.delay > 0)
  store_guided_tick(scenario, trace)
  assert_true(trace.genuine_hits > 0)
  store_correspondence_c_words(observer, source, 0, words)
  store_correspondence_c_words(observer, source, 1, words)
  scenario.request_ready = 0UL
  while scenario.pending is Some(_) {
    assert_eq(records_output(source, "memory_request_valid"), 0UL)
    store_guided_tick(scenario, trace)
  }
  assert_eq(scenario.read_acks, 5)
  while records_output(source, "memory_request_valid") == 0UL {
    store_guided_tick(scenario, trace)
  }
  let held = [1UL, 512UL, 4UL, 15UL, 10UL, 5UL]
  let mut held_offers = 0
  for _ in 0..<3 {
    assert_eq(store_correspondence_arbiter(observer, source, "state"), 1UL)
    assert_eq(store_correspondence_arbiter(observer, source, "owner"), 1UL)
    assert_eq(store_scenario_request(source), held)
    assert_eq(scenario.pending, None)
    store_guided_tick(scenario, trace)
    held_offers += 1
  }
  assert_eq(held_offers, 3)
  scenario.latency = 0
  scenario.request_ready = 1UL
  while trace.coherent_hits == 0 {
    store_guided_tick(scenario, trace)
  }
  // The original cover is Store Done after a COMPLETE rectangle, not merely
  // a granted write or arbitrary completion. No second Store/new reset is
  // needed to witness this predicate; the earlier broader regression stays.
  assert_eq(scenario.admissions, 6)
  assert_eq(observer.store_accepts, 1)
  assert_eq(observer.compute_accepts, 2)
  assert_eq(trace.read_accepts, 4)
  assert_eq(trace.qualified_grants, 1)
  assert_eq(trace.qualified_writes, 1)
  assert_eq(trace.qualified_acks, 1)
  assert_eq(scenario.read_acks, 5)
  assert_eq(scenario.write_acks, 4)
  assert_eq(scenario.requests.length(), 9)
  for index in 0..<4 {
    assert_eq(scenario.requests[5 + index], [
      1UL,
      (512 + index / 2 * 16 + index % 2 * 4).to_uint64(),
      4UL,
      15UL,
      words[index].to_uint64(),
      (5 + index).to_uint64(),
    ])
  }
  assert_eq(scenario.memory, expected)
  assert_eq(observer.pre_samples, trace.steps)
  assert_eq(observer.post_samples, trace.steps)
  assert_eq(observer.reset_edges, 1)
  assert_true(
    observer.unknown_registers > 0 &&
    observer.unknown_arithmetic > 0 &&
    observer.unknown_reads > 0 &&
    observer.unknown_cells > 0,
  )
  assert_true(trace.steps < 128)
  let input_count = observer.slice.hardware
    .nodes()
    .filter(node => node.kind() is Input(name) && name != "clock")
    .length()
  assert_eq(trace.producers.length(), 4)
  assert_eq(trace.inputs.length(), trace.steps * input_count)
  let inputs = store_preservation_proof_inputs(observer.fixture)
  assert_eq(inputs.projection.hardware, observer.slice.hardware)
  assert_eq(inputs.emitted, trace.emitted)
  let summary = "NATIVE-GUIDED-STORE ONLY-not-SMTC-or-engine-evidence steps=\{trace.steps} read-accepts=\{trace.read_accepts} pregrant-edges=\{trace.pregrant_edges} opposite-accepts=\{trace.opposite_accepts} intermediate=\{trace.intermediate_captures} final=\{trace.final_captures} genuine-held=\{trace.genuine_hits} qualified-grants=\{trace.qualified_grants} qualified-writes=\{trace.qualified_writes} qualified-ACKs=\{trace.qualified_acks} native-coherent-ghost-hits=\{trace.coherent_hits} read-ACKs=\{scenario.read_acks} write-ACKs=\{scenario.write_acks} held-public-offers=\{held_offers}"
  println(summary)
  if @env.get_env_var("LUNACHIP_PHASE6_STORE_GUIDANCE_PRINT") == Some("1") {
    let header = "NATIVE-PRE-ROSTER ONLY-not-SMTC-not-global-phase-qualified-not-universal-safety\nInput-only known-bit scenario guidance; unknown bits remain free.\nOriginal-source \{observer.slice.plan.probe.source_digest}\nProjection-report \{sha256_hex(store_storage_projection_report(observer.slice))}\nPositive-source \{sha256_hex(inputs.positive)}\nNegative-source \{sha256_hex(inputs.negative)}\n\{summary}\n"
    for
      (path, content) in [
        ("pre-inputs.txt", header + trace.inputs.join("\n") + "\n"),
        ("native-causal-trace.txt", header + trace.causal.join("\n") + "\n"),
      ] {
      println("STORE-GUIDANCE-ARTIFACT \{path} sha256 \{sha256_hex(content)}")
      println(content)
      println("END-STORE-GUIDANCE-ARTIFACT \{path}")
    }
  }
}
