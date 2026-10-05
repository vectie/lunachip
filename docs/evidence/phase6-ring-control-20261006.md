# Fetched ring-control recovery replay result

Strict pinned lint, build, execution and typed audit all exit zero. All 30 public
outputs agree over 7,107 post-initial-reset cycles: 213,210 exact observations.
This closes the finite [ring-control workload](../PHASE6_DIFFERENTIAL_RING_CONTROL.md),
not the unfinished Phase 6 formal or full-device gate.

## Source and native checkpoint

The completed native gate passes 845/845 tests, warning-strict checking including
warning 73, the bootstrap CLI smoke run and dependency/source-size boundaries.
Targeted fixture 1/1 and CLI 29/29 tests also pass. The gate ran at precommit
`1a218ac1aa8c8537e7982df89c7fe6c54ad83216` with the documented dirty fixture/CLI
sources. Before/after HEAD and status listings match; that does not establish
that formatting never changed file contents. The initial interface-generation
wrapper rejected its legitimate status change, and the first strict check
found a reserved local name and test range-precedence error. Original logs are
retained alongside corrected passing checks; no obligations were weakened.

Implementation and CLI were committed separately as `623827e` and `77db8bb`.
The subsequent native build, exports and all four external-tool/audit jobs use
clean, unchanged `77db8bb9d894f2e10b506242827023dd2c29e86c`. Their before/after
HEAD/status snapshots match. Export additionally checks ten implementation
source digests and unchanged helper/native-exporter bytes. The generated public
API adds only `generate_ring_control_bundle()`; hardware, ABI, descriptor 0.2,
host engine and runners are unchanged. All six new files remain below 500 lines.

All 110 artifacts from ten previous replay bundles remain byte/SHA-identical.
Comparison inventory SHA-256:
`22ea6de8b4c6bb95c9218704a6894f366f24de914451062da20f8e5b436e648c`.
The new eleven-artifact inventory SHA-256 is
`b77924bf57c9f16a7dce477466a453fad4d6f1229f25189ff8a50df1be727de6`.
Reference self-audit alone is not independent RTL evidence.

## Independent compiled RTL agreement

The unchanged runner uses locked Verilator 5.050, Linux ARM64 image
`docker.io/verilator/verilator@sha256:6d8207220a9aa51fa8bed1449641cc5b113ca0ef912aa1a76afccd728a6391c5`,
network disabled and warnings fatal. Lint, build, execute and the existing
`audit-ring-control` comparator each have an actual zero exit and empty stderr.
The independently compiled `actual.tsv` is byte-identical to `expected.tsv`,
including identity and all 7,107 complete rows. Both SHA-256 values are
`eecabd3e3f2a5325fe20c5cd750950bb0a7f720af7f28f64575a7c39673a63b1`.
Design SHA-256:
`8733d9d6791e2049604c065a35d3c62220e4d9d9059af23d12a79a51388c2c46`.
Stimulus SHA-256:
`1a53b64c1bb649c9e10e97f8ba555a5b3e04eb2ed7168a438951d47bc40e7391`.

The seven epochs cover alignment/address-window priority, wide nonwrapping
configuration bounds, a legal no-op publication, backward/over-capacity
publication, invalid publication during actual packet admission, admitted-work
drainage despite reader fault, held completion and reset/fresh recovery. Saved
final descriptor ACK occurs at cycle 5,727; invalid publication at 5,728 advances
consumer 3→4 and active 124→125 while producer stays 6 and transport poison stays
false. The long completion is discovered at 6,119 and held for 32 active edges.

Actual public request/response/completion observations match 11 retirements,
352 descriptor reads, 1,026 operand reads, two word writes and 1,380 matched
request/ACK pairs. Successful writes carry independent oracle results 3,072 and 6.
The reference host validates all 4,096 bytes, saved ACK ownership and quiet-edge
obligations; `workload.audit` remains generated-reference evidence, not a
separate compiled-host memory dump or formal theorem. Independent read-only
reviews checked the source, native contexts, artifacts and PRE handshake counts.

## Retention and claim boundary

The complete original support tree is retained at
`/Users/kq/Workspace/lunachip/.phase6-ring-control-evidence-20261006`, matching
`/private/tmp/lunachip-ring-control-support-20261006.hM0cXG` by recursive byte
comparison. Its 486 inventoried regular files plus `outputs.sha256` include
failed attempts, inputs, compiled outputs and every actual log. Inventory
SHA-256: `6568ba24b1ce394a941606d57b4adf47c0269651ddcd4b79a16c29550163ef94`.

This is finite 1x1/K512 ring-control/recovery agreement. It does not establish
universal publication correctness, internal ticket wrap, fairness, saved packet
identity, engine ownership, leases, full-device/fetched/8x8 formal safety,
synthesis equivalence, physical performance or completion of Phase 6. The
retained queue safety timeout and unexecuted retirement-record formal tasks
remain unchanged unfinished obligations.
