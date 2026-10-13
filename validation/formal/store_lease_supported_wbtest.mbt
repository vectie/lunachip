///|
test "Store lease support adds one checked paired-state conclusion without changing the failed four-conclusion attempt" {
  let inputs = store_preservation_proof_inputs(
    @flux_tile.queued_concurrent_store_preservation_fixture(),
  )
  let original = store_lease_source(inputs, "lease-update")
  let supported = store_lease_supported_source(inputs)
  let added = store_lease_phase_support()
  assert_eq(
    sha256_hex(original),
    "c98ecb2cceb8b9f88e157043c8cdd31b6bcae9d9fa0b31e4b78d52e5e9fc9489",
  )
  assert_eq(supported.split(added).count(), 2)
  assert_eq(supported.replace(old=added, new=""), original)
  assert_eq(original.split(": assert (").count(), 5)
  assert_eq(supported.split(": assert (").count(), 6)
  assert_eq(supported.split(": assume (").count(), 2)
  assert_eq(supported.split(": cover (").count(), 1)
  assert_eq(added.split("!lc_seen_edge").count(), 2)
  assert_false(added.contains("lc_reset"))
  assert_false(added.contains("assume"))
  assert_false(added.contains("logic "))
  assert_false(added.contains("Leased"))
}

///|
test "Store lease supported collector preserves the locked induction policy and labels the new task" {
  let artifacts = store_lease_supported_artifacts()
  assert_eq(artifacts.map(artifact => artifact.path), [
    "lease-update-supported.sv", "lease-update-supported.sby",
  ])
  assert_eq(artifacts[0].content.split(": assert (").count(), 6)
  assert_true(
    artifacts[1].content.contains(
      "mode prove\ndepth 20\ntimeout 600\nmulticlock on\n",
    ),
  )
  assert_true(artifacts[1].content.contains("smtbmc bitwuzla\n"))
  assert_true(artifacts[1].content.contains("logger -werror .*\n"))
  assert_true(
    artifacts[1].content.contains(
      "write_rtlil /out/lease-update-supported-prepared.rtlil\n",
    ),
  )
  assert_true(
    artifacts[1].content.contains(
      "lease-update-supported.sv /work/lease-update-supported.sv\n",
    ),
  )
  assert_false(artifacts[1].content.contains("chformal"))
  if @env.get_env_var("LUNACHIP_PHASE6_STORE_LEASE_SUPPORTED_INPUTS_PRINT") ==
    Some("1") {
    for artifact in artifacts {
      println(
        "STORE-LEASE-SUPPORTED-ARTIFACT \{artifact.path} sha256 \{sha256_hex(artifact.content)}",
      )
      println(artifact.content)
      println("END-STORE-LEASE-SUPPORTED-ARTIFACT \{artifact.path}")
    }
  }
}
