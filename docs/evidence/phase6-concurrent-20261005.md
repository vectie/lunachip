# Fetched device concurrency replay on 2026-10-05

The named `fetched-concurrent-1x1-k512-overlap` fixture passed strict pinned
Verilator lint, build, execute and typed audit. All 30 public outputs agree
across 9,041 post-reset cycles: 271,230 output observations. Actual and expected
TSV are also byte-identical. This validates the recorded engine overlap, not
the complete Phase 6 gate or physical performance.

Source snapshot: `b86ee217eb2baf80e6471e5f05c0415023aa2882`.
Profile: `flux-tile-0/fetched-concurrent`, logical Device ABI 1.0,
descriptor encoding 0.2. Configuration: 1x1 array, reduction capacity 512,
4096 host bytes, four ring slots and queue/retirement depth three.

## Measured workload

The real byte-memory host fetched ten descriptors and retired ten ordered
successes. It first produced C0=6, then loaded the other operand slots and
published MatMul, StoreC0, LoadA0 and Fence together. Three commands share
caller ID 77; retirement is checked by ordinal, not by an ID lookup.

During edges where the new MatMul active counter advanced, the host accepted
95 descriptor reads, 31 operand reads and one StoreC0 write. The store ACK
occurred at cycle 6,089, before the MatMul terminal became visible at cycle
6,470. The oldest completion was held unchanged for 64 edges while the loader
accepted 13 operand reads. The fixture does not claim capture overlap, Fence
before that completion ACK, or engine reuse while the oldest record is held.

The host accepted 1,860 transactions, reading 1,858 bytes and writing eight.
The independent signed matrix oracle produced C1=81,664; all 4096 host bytes,
including padding and final descriptor-slot contents, match the expected
memory. Producer and consumer both finish at ten. The latest MatMul counters
are accepted=active=512, elapsed=513, capture=1 and stall=0. These are functional
simulation counts, not a throughput, frequency or latency benchmark.

## Tools and retained artifacts

The existing isolated, network-disabled OCI runner used Verilator 5.050 on
`linux/arm64`, with locked image
`docker.io/verilator/verilator@sha256:6d8207220a9aa51fa8bed1449641cc5b113ca0ef912aa1a76afccd728a6391c5`.
No runner flags, tool locks or VM configuration changed.

The eleven generated artifacts, actual TSV and three existing runner receipts
are retained outside Git at
`/Users/kq/Workspace/lunachip/.phase6-concurrent-evidence-20261005`.
The original compiled run remains at
`/private/tmp/lunachip-phase6-concurrent-20261005.5AKgq2`.

| Artifact | SHA-256 |
|---|---|
| `bundle/design.lcir` | `4b10085bf8190905952a181df5a6080791f2116af78c6fff76e0b0a183930a5d` |
| `bundle/stimulus.tsv` | `f93acd47930435cdf1357eb7371821757290fe0d66486989284291363bd2074b` |
| `actual.tsv` and `bundle/expected.tsv` | `3b1aaf20f6e9808855cffe196be401fd7b8b61029059b8642f395b8c39c5fa46` |
| `verilator-lint-receipt.txt` | `43c38942f8a046316f8da52fe43f8da0b5fb7b938361a03a01c097ac02574706` |
| `verilator-build-receipt.txt` | `b1d76148053c1e89fcbb185be4a51fc290e44cec611ea363721534994628f970` |
| `verilator-execute-receipt.txt` | `30e6f7a1b1fe50dc4b0948621c860391277027ba8a76cecce529719417fe5676` |

## Regression checks and limits

All eight targeted fixture/CLI tests passed. Repeated concurrent generation
compares every artifact byte and the complete expected TSV. Typed comparison
rejects a real output mutation and a result carrying another fixture identity.
All eleven original K2 fixture artifacts remain byte-identical to the retained
first replay after the private host/trace refactoring. The only added public
entry point is the predefined concurrent generator; host and trace helpers
remain private. Existing export/audit reports are unchanged; help lists the
two new commands.

The complete native slice gate passed interface generation, formatting,
warning-strict native check with warning 73 enabled, all 738 tests, CLI smoke
and dependency/source-size boundaries. Fault/reset, randomized legal matrices
and latency, capacity/wrap, independent synthesis and named formal tasks remain
required. This result is not an aggregate evidence protocol, a synthesis
equivalence claim, or a physical accelerator claim.
