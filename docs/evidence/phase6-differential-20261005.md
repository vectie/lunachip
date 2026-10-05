# First fetched concurrent RTL replay — 2026-10-05

Source snapshot: `23c582c7ac9b41e08fedd39130aa4c70c3da8833`.
Profile: `flux-tile-0/fetched-concurrent`, logical Device ABI 1.0,
descriptor encoding 0.2. Fixture: `fetched-concurrent-1x1-k2`.

The pinned Verilator 5.050 runner passed strict lint, build and execute on
`linux/arm64`, using image
`docker.io/verilator/verilator@sha256:6d8207220a9aa51fa8bed1449641cc5b113ca0ef912aa1a76afccd728a6391c5`.
Execution used the existing isolated, network-disabled OCI runner and volume
transport. No VM configuration or tool lock was changed.

The typed audit returned `result=equal` for 1,114 post-reset cycles and all
30 public outputs: 33,420 output observations. Actual and expected TSV are also
byte-identical. The real host workload fetched five descriptors, retired five
ordered successes, reused a consumed ring slot, held completion for nine
cycles, and checked all 1024 host bytes against the independent matrix oracle.
The signed result is -637. It accepted 165 transactions, reading 164 bytes and
writing four bytes. These are functional simulation counts, not performance.

## Retained local artifacts

The generated bundle, actual TSV and three existing runner receipts are kept
outside Git at
`/Users/kq/Workspace/lunachip/.phase6-differential-evidence-20261005`.
The copied actual TSV independently passes the same typed audit. The original
run, including the failed first lint diagnostics and compiled model, remains
at `/private/tmp/lunachip-phase6-20261005.mcblUu`.

| Artifact | SHA-256 |
|---|---|
| `bundle/design.lcir` | `d47c7cccaa7dc7d8021b0fabc6a4eb7d4977bb53c1c5fa06416bbbb5e531cf79` |
| `bundle/stimulus.tsv` | `1ac51fcafebca36566a086de1488211c56de6d91b193cf6fc39ba155d2d187e0` |
| `actual.tsv` and `bundle/expected.tsv` | `2de70068d839449b0f5cb6f6e2b33b3490623089aeea1e967c8127a7dce7c1b2` |
| `verilator-lint-receipt.txt` | `43c38942f8a046316f8da52fe43f8da0b5fb7b938361a03a01c097ac02574706` |
| `verilator-build-receipt.txt` | `b1d76148053c1e89fcbb185be4a51fc290e44cec611ea363721534994628f970` |
| `verilator-execute-receipt.txt` | `30e6f7a1b1fe50dc4b0948621c860391277027ba8a76cecce529719417fe5676` |

## Required emitter fix and regression checks

The initial lint run failed on eleven intentionally unconsumed upper-bit
ranges. The backend now emits source-local `UNUSEDSIGNAL` annotations only
around declarations whose direct Slice/Truncate consumers establish a proper
nonempty interval hull. Full consumers, outputs, memory/FIFO dependencies,
implicit state holds and dead-node rejection remain conservative. Public ports
and runner flags are unchanged; no dummy logic was added.

All 31 backend tests, including nine focused scope tests, pass. Instrumented
coverage of the new private helper reports 69/69. The six fixture/CLI tests
pass, including real value mismatch, malformed TSV and overwrite refusal.
Canonical fetched IR and the expected trace are byte-identical before/after
the fix. All nine complete Phase 4 synthesis bundles are also byte-identical.

The completed native slice gate passed public interface generation, formatting,
warning-strict native check with warning 73 enabled, all 736 tests, CLI smoke
and dependency/source-size boundaries. A preliminary native run was stopped
after external lint revealed the needed fix; it is not counted as a gate pass.

## Claim boundary

This establishes recorded cycle agreement for this named small successful pipeline and its
fixed stalls, not the complete Phase 6 gate. It does not yet independently
exercise sustained engine overlap, both slots, randomized legal matrices,
fault owners, capacity/wrap or reset/flush. Synthesis and named formal tasks
remain separate unfinished gates. This record is a scoped result, not a new
aggregate evidence protocol or a claim of source/proof artifact closure.
