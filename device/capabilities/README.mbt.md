# FluxTile capabilities

This pure publisher describes the `flux-tile-0/fetched-concurrent` logical
device profile. Device ABI **1.0** and descriptor encoding **0.2** are distinct.
It imports no hardware or simulation code and makes no evidence/performance
claim. Configuration is immutable and constructible only through checked
`Capabilities::new`; its six fields are publicly readable.

```mbt check
///|
test {
  let config = @capabilities.Capabilities::new(
    rows=2,
    columns=3,
    max_reduction=5,
    host_bytes=4096UL,
    ring_depth=4,
    queue_depth=3,
  )
  assert_eq(config.rows, 2)
  assert_eq(config.columns, 3)
  assert_eq(config.max_reduction, 5)
  assert_eq(config.host_bytes, 4096UL)
  assert_eq(config.ring_depth, 4)
  assert_eq(config.queue_depth, 3)
  assert_true(config.manifest().has_suffix("\n"))
  assert_eq(config.manifest(), config.manifest())
}
```

`manifest()` emits a fixed-order newline-terminated JSON object. Consumers own
parsing and must select supported schema, profile, Device ABI and descriptor
versions explicitly. Counter values concern the latest inner-issued MatMul,
not workload totals or the retiring command. Descriptor-slot reuse does not
authorize operand/output-buffer reuse; the host owns aliasing and coherency.
Joint reset requires flushing actual host transactions before release.
