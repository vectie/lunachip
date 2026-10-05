# Fetched descriptor rejection RTL checkpoint

The fixed descriptor-rejection replay passes strict pinned Verilator lint,
build, execution and typed audit. Its actual RTL observations are byte-identical
to the independent LunaWave reference across 14,464 cycles and all 30 ordinary
public outputs: 433,920 observations. Phase 6 remains in progress.

## Frozen source and retained evidence

All four commands ran against the unchanged, clean implementation commit
`011a0485865571a6237f6b92ed3c82ce9a24cfe4`. Every command's before/after HEAD and
complete Git-status snapshots agree. The earlier
[838-test native checkpoint](phase6-queue-descriptor-native-20261006.md)
documents its distinct precommit source context and old-artifact comparisons.

The complete original support directory is retained, without rewriting earlier
failed native attempts or engine receipts, at
`/Users/kq/Workspace/lunachip/.phase6-descriptor-rejection-evidence-20261006`.
It contains 451 inventoried regular files plus `outputs.sha256`; an independent
review and a recursive byte comparison confirm the retained copy agrees with
`/private/tmp/lunachip-descriptor-rejection-support-20261006.wApINc`.

| Evidence | SHA-256 |
| --- | --- |
| Complete retention inventory | `6748d75a0e1af4befb181b9d9a0843ae3ab9ce1320cc50993ece414876879b66` |
| Canonical design | `196acd54e9ac1546585a808d3ac461858d430f19beb463fd03f586d73a694343` |
| Stimulus | `7a96bab52e258ca9cc9f1edc70510df0f9e2230b57d467b0fcd15259daba06e2` |
| Expected and actual observations | `218f22c9a3ded912992013284ba415d512636877356d1bc2ec3012887ad1e66c` |

The actual child exits in `rtl-lint`, `rtl-build`, `rtl-execute` and `rtl-audit`
are all zero; their stderr files are empty. The typed audit reports
`fixture=fetched-concurrent-2x2-k2-descriptor-rejection cycles=14464 result=equal`.
Both TSV files contain two header lines and 14,464 complete cycle rows. All
eleven exported bundle digests verify.

Receipts bind Verilator 5.050, Linux ARM64, and the locked image
`docker.io/verilator/verilator@sha256:6d8207220a9aa51fa8bed1449641cc5b113ca0ef912aa1a76afccd728a6391c5`.
The existing volume transport and strict warning policy are unchanged. No
replay input, hardware, ABI, runner, waiver or resource limit was changed to
obtain the match.

## Named workload and claim boundary

The [frozen workload](../PHASE6_DIFFERENTIAL_DESCRIPTOR_REJECTION.md) runs 86
ordered descriptors in 31 drained publication groups: 26 successes and 60 faults.
Its reference obligations check reserved locations, opcode aliases, raw-width
dimensions, unused fields, competing fault priority, exact shapes, alignment
and wide preflight bounds. Syntax faults preserve older writer intent;
syntax-valid failed writers prevent stale fallback. Fresh loads, computation,
capture and storage recover without an intervening reset.

The reference host checks 2,752 descriptor reads, seven operand reads, nine word
writes and 2,768 owned ACKs. Per-write arithmetic and saved-ACK checks produce
6, preserve unrelated result 35 and recover result 27; all 4,096 final host bytes
match independent expectations. Seven rejection windows have no data transfer
or compute-counter change. A fault completion remains held for 32 active edges;
nine real scalar Run/capture pairs and eight final quiet edges are recorded.

`workload.audit` remains explicitly generated-reference evidence. Exact replay
agreement now independently validates all its public-boundary observations;
it does not turn each internal reference observation into a formal theorem.
The successful arithmetic is 1x1/K1 on an elaborated 2x2/K2 device. This drained
fixture does not claim new overlap, capacity saturation, internal ticket wrap,
every malformed packet, fairness, full-device safety, synthesis equivalence,
physical performance or completion of the Phase 6 gate.
