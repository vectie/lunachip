///|
test "fetched supported source reproduces accepted four checked invariants without changing original twelve" {
  let sequential = fetched_transport_sequential()
  let emitted = @rtl.emit_design(
    @ir.Design::single(
      "FetchedTransportProofView",
      fetched_transport_proof_view(sequential),
    ),
  )
  let original = fetched_transport_proof_source(sequential, emitted)
  let supported = fetched_transport_supported_source(sequential, emitted)
  let support = fetched_transport_supporting_source()
  assert_eq(
    sha256_hex(original),
    "aa105bc8af41f7615bebcaf146aba2843e02c08cd7ad85fe6ec3597afef247a1",
  )
  assert_eq(
    sha256_hex(supported),
    "4b32fb7ef6ffc8689b38b01562c6f5ef59fa5d7f1b148ba9a6676fd9220c4c8b",
  )
  assert_eq(supported.split(support).count(), 2)
  assert_eq(supported.replace(old=support, new=""), original)
  assert_eq(supported.split(": assert (").count(), 17)
  assert_eq(supported.split(": assume (").count(), 2)
  assert_eq(supported.split(": cover (").count(), 2)
  assert_eq(support.split("!lc_seen_edge").count(), 5)
  assert_false(support.contains("lc_reset"))
  assert_false(support.contains("assume"))
  assert_false(support.contains("logic "))
  assert_eq(fetched_transport_proof_assertions().length(), 12)
  // Typed source identity and original state/cut construction are still required.
  assert_eq(sequential.hardware.memories().length(), 0)
  assert_eq(sequential.probe.roots.length(), 26)
  assert_eq(sequential.probe.candidates.length(), 21)
}

///|
test "fetched supported collector preserves accepted Boolean module and prove config" {
  let artifacts = fetched_transport_supported_artifacts()
  assert_eq(artifacts, fetched_transport_supported_artifacts())
  assert_eq(artifacts.map(artifact => artifact.path), [
    "sequential-boolean.sv", "selected.sv", "prove.sby",
  ])
  assert_eq(
    sha256_hex(artifacts[0].content),
    "e2fdbb95e931cf6d86abe63b6a94b2a84037bf4798267bd5f6db5d2e9a60fa64",
  )
  assert_eq(
    sha256_hex(artifacts[1].content),
    "4b32fb7ef6ffc8689b38b01562c6f5ef59fa5d7f1b148ba9a6676fd9220c4c8b",
  )
  assert_eq(
    sha256_hex(artifacts[2].content),
    "dfbb6589baeda8d3cfec87c95e707615a098e89417d25154dc17c92aafe77ba0",
  )
  let legacy = fetched_transport_proof_artifacts()
  assert_eq(legacy.length(), 6)
  assert_eq(legacy[2].content, artifacts[0].content)
  assert_eq(
    sha256_hex(legacy[3].content),
    "aa105bc8af41f7615bebcaf146aba2843e02c08cd7ad85fe6ec3597afef247a1",
  )
  assert_true(
    artifacts[2].content.contains("mode prove\ndepth 20\ntimeout 600\n"),
  )
  assert_true(
    artifacts[2].content.contains(
      "prep -top lc_fetched_transport_bridge -flatten\n",
    ),
  )
  if @env.get_env_var("LUNACHIP_PHASE6_FETCHED_SUPPORTED_INPUTS_PRINT") ==
    Some("1") {
    for artifact in artifacts {
      println(
        "FETCHED-SUPPORTED-ARTIFACT \{artifact.path} sha256 \{sha256_hex(artifact.content)}",
      )
      println(artifact.content)
      println("END-FETCHED-SUPPORTED-ARTIFACT \{artifact.path}")
    }
  }
}
