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

## First conjunction and missing ownership history

The first candidate keeps all 119 accepted conclusions and adds 38 assertions
for capture, publication, generation tickets, Store leases, readback and DMA
origin. On clean `6fc5b0c29e7c40222d864e9b990fb7b65f2101e1`, pinned SBY
returns `TIMEOUT 8 179`, child8, after 601 wall seconds. Basecase 0–19 passes
at 105 engine seconds; induction fails at 470 seconds and identifies
`lc_full_dut.lc_fs_latest_generation_1` at 541 seconds. It produces no trace.
This is not a validated reachable counterexample or an unbounded safety pass.

Prepared-model review matches all 157 labels, the original five assumptions,
zero covers, ten arrays retaining 640 unknown initial storage bits and unknown
read INIT, and twenty complete qualified binary helper pairs. Source/config
copies and full clean before/after Git identity match. All 22 focused frozen
native tests pass. Two fixture/docstring tests and collector/reviewer unit
tests also pass during implementation. The production graph is unchanged.

The sealed archive `artifacts/phase6-fetched-sram-20261016-r1` has inventory
SHA256 `01ef778e8ecc83d79304667cdec4b8dde398e55a1553f683418a29e6f2e17bff`.
Its VM window is released after owned cleanup, before host review/archival;
the protected PRX100 volumes and QEMU configuration are unchanged.

Inspection of the collection equations motivates two additional checked
Pending-generation ownership relations: each C ticket must belong either to
the reserved MatMul head for that C slot or to the actual current Compute.
Collection compares full tickets; ownership is therefore needed to rule out
unreachable induction states that give both C banks the same live ticket. This
is a proof-closure hypothesis, not a claim that such a state is reachable.
A third checked relation carries the physical generation basis of a successful
reserved Store head through its wait before outer acceptance. The original
157 conclusions remain selected; no ownership relation is assumed.
