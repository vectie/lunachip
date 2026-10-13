///|
test "fresh fetched transport report pins actual original state and deterministic closure" {
  let probe = fetched_transport_probe()
  assert_eq(
    probe.production_digest,
    "d47c7cccaa7dc7d8021b0fabc6a4eb7d4977bb53c1c5fa06416bbbb5e531cf79",
  )
  assert_eq(
    probe.source,
    @flux_tile.ring_concurrent_tile(
      rows=1,
      columns=1,
      max_reduction=2,
      host_bytes=1024UL,
      ring_depth=4,
      queue_depth=2,
    ),
  )
  assert_eq(probe.roots.length(), 26)
  assert_eq(
    probe.roots.fold(init=0, (bits, root) => {
      bits + root.signal_type.width().bits()
    }),
    666,
  )
  for root in probe.roots {
    assert_eq(probe.roots.filter(other => other.node == root.node).length(), 1)
    assert_eq(
      dependency_generation_node(probe.source, root.node).kind(),
      Register(root.spec),
    )
    assert_eq(root.spec.initial(), None)
    assert_eq(root.spec.domain(), @ir.ClockDomain::rising(probe.clock))
    assert_eq(root.spec.reset(), Some(@ir.ResetSpec::new(probe.reset, 0UL)))
  }
  assert_eq(
    fetched_transport_probe_report(probe),
    fetched_transport_probe_report(fetched_transport_probe()),
  )
  assert_eq(
    fetched_transport_closure(
      probe.source,
      probe.roots,
      probe.candidates,
      probe.events,
    ),
    probe.cone.iter().to_array(),
  )
  // Whole report is inspection output; no inferred count is an accepted cut pin.
  println(fetched_transport_probe_report(probe))
}

///|
test "fresh fetched materialization copies all original specs and only explicit raw boundaries" {
  let slice = fetched_transport_sequential()
  let copy = slice.hardware
  assert_eq(copy.memories().length(), 0)
  // Current IR has no instance node; the canonical design is one flat module.
  assert_eq(@ir.Design::single("FetchedTransportSequential", copy).modules(), [
    copy,
  ])
  for root in slice.probe.roots {
    let node = dependency_generation_node(
      copy,
      dependency_generation_mapped(slice.original_to_local, root.node),
    )
    guard node.kind() is Register(spec) else {
      fail("missing original register")
    }
    assert_eq(node.signal_type(), root.signal_type)
    assert_eq(
      spec.next(),
      dependency_generation_mapped(slice.original_to_local, root.spec.next()),
    )
    assert_eq(spec.initial(), root.spec.initial())
    assert_eq(spec.enable(), None)
    assert_eq(
      spec.reset(),
      Some(
        @ir.ResetSpec::new(
          dependency_generation_mapped(
            slice.original_to_local,
            slice.probe.reset,
          ),
          0UL,
        ),
      ),
    )
  }
  for cut in slice.probe.candidates {
    let node = dependency_generation_node(
      copy,
      dependency_generation_mapped(slice.original_to_local, cut.original.id()),
    )
    assert_eq(node.kind(), Input("cut_n\{cut.original.id().ordinal()}"))
    assert_eq(node.signal_type(), cut.original.signal_type())
  }
  for node in slice.probe.cone {
    let actual = dependency_generation_node(
      copy,
      dependency_generation_mapped(slice.original_to_local, node.id()),
    )
    assert_eq(
      actual.kind(),
      dependency_generation_remap(node.kind(), slice.original_to_local),
    )
    assert_eq(actual.signal_type(), node.signal_type())
  }
  assert_eq(
    @ir_codec.serialize(@ir.Design::single("FetchedTransportSequential", copy)),
    @ir_codec.serialize(
      @ir.Design::single(
        "FetchedTransportSequential",
        fetched_transport_sequential().hardware,
      ),
    ),
  )
  // Exact interface aliases also keep every reviewed raw cut reachable.
  ignore(
    @rtl.emit_design(@ir.Design::single("FetchedTransportSequential", copy)),
  )
  // Opt-in source collector only. Keep the original probe report separately
  // for its complete-report pin; the extended report records every local map.
  if @env.get_env_var("LUNACHIP_PHASE6_FETCHED_CORE_PRINT") == Some("1") {
    let canonical = @ir_codec.serialize(
      @ir.Design::single("FetchedTransportSequential", copy),
    )
    let report = fetched_transport_probe_report(slice.probe)
    let mapped_report = StringBuilder()
    mapped_report.write_string(report)
    mapped_report.write_string("CORE-IR sha256 \{sha256_hex(canonical)}\n")
    for original in slice.probe.source.nodes() {
      if slice.original_to_local[original.id().ordinal()] is Some(mapped) {
        let actual = dependency_generation_node(copy, mapped)
        mapped_report.write_string(
          "MAPPED original \{original.id().ordinal()} local \{mapped.ordinal()} type \{Repr(actual.signal_type())} kind \{Repr(actual.kind())}\n",
        )
      }
    }
    for output in copy.outputs() {
      mapped_report.write_string(
        "MAPPED-OUTPUT \{output.name()} local \{output.driver().ordinal()} type \{Repr(output.signal_type())}\n",
      )
    }
    let artifacts : Array[FormalBundleArtifact] = [
      { path: "probe-report.txt", content: report, },
      { path: "sequential.lcir", content: canonical, },
      { path: "sequential-report.txt", content: mapped_report.to_string(), },
    ]
    for artifact in artifacts {
      println(
        "FETCHED-CORE-ARTIFACT \{artifact.path} sha256 \{sha256_hex(artifact.content)}",
      )
      println(artifact.content)
      println("END-FETCHED-CORE-ARTIFACT \{artifact.path}")
    }
  }
}

///|
test "fresh fetched closure rejects omitted source interface" {
  let probe = fetched_transport_probe()
  for missing in 0..<probe.candidates.length() {
    let candidates : Array[TwoClientArbiterCandidate] = []
    for index, candidate in probe.candidates {
      if index != missing {
        candidates.push(candidate)
      }
    }
    try
      fetched_transport_closure(
        probe.source,
        probe.roots,
        candidates,
        probe.events,
      )
    catch {
      _ => ()
    } noraise {
      _ => fail("omitted actual source boundary must not become a hidden cut")
    }
  }
}
