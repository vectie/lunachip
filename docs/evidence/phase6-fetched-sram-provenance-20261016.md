# Fetched SRAM capture generation and value provenance

Extend the accepted 119-property fetched packet/dependency conjunction with
provenance for the actual C SRAM cells, publication and Store readback. The
scope remains fetched 1x1/K2/host1024/ring4/queue2, not general 8x8 arithmetic
correctness or fabricated SRAM measurements.

## Implementation and acceptance sequence

1. Reuse the existing Store/capture observation seam for the exact fetched
   graph. Keep all production nodes, ports, memory policies and metadata equal.
2. Bind the raw accumulator producer independently of the memory write mux.
   Track per-generation capture validity, full producer tickets and values.
   Prove that successful publication has a complete captured basis, and that
   Store reads and public DMA writes preserve that basis without stale fallback.
3. Preserve unknown initial cells/read states and reset invalidation without
   memory erasure. Preserve full cursor/address equations; add no internal
   premises, initialized RAM or successful-response assumptions.
4. Exercise both slots, failed generations, recovery and reset in targeted
   native tests. Run a pinned unbounded conjunction on a clean frozen snapshot
   in a confirmed non-overlapping VM window. Review and seal actual outcomes,
   including unsuccessful attempts, before updating the acceptance ledger.

The starting accepted archive is
`artifacts/phase6-fetched-packet-order-20261016-r2`, inventory SHA256
`63c34f872228c9b477d820c973e1e182ead59ae9cd3b42a9ba87e248675c4319`.
No SRAM provenance proof result is claimed at this planning checkpoint.
