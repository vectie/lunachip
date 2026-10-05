# Reader poison and pending response reset replay on 2026-10-05

The named `fetched-concurrent-1x1-k64-reader-poison-reset` fixture passed strict
pinned Verilator lint, build, execute and typed audit. All 30 public outputs
agree across 1,261 post-reset cycles: 37,830 observations, including both joint
reset edges. Actual and expected TSV are byte-identical. This covers the
recorded reader-owned fault and reset sequence, not all fault owners or Phase 6.

Source snapshot: `2a8441aa9cdea89052c401d9c43909e9258b2b97`.
Profile: `flux-tile-0/fetched-concurrent`, logical Device ABI 1.0,
descriptor encoding 0.2. Configuration: 1x1 array, reduction capacity 64,
4096 host bytes, four ring slots and q2 retirement.

## Owned fault and compute drainage

After two successful K16 operand loads, the host publishes LoadA0 K64, MatMul
A1/B1 into C1 K16 and Fence. The first Fence byte at address 3072 is an actual
accepted request with saved global tag 192; consumer is four while producer
is five. The host holds that response for two edges, then returns the saved
byte with tag 193 and fault zero. At the real response handshake on cycle 808,
the new MatMul active counter advances from one to two.

The reader reports protocol fault 5 at address 3072 and transport halts with
that same address. The loader's 32 committed bytes are retained in its ordered
cancellation completion, fault 15. The admitted MatMul drains to success with
accepted=active=16, elapsed=17, capture=1 and stall=0. The oldest cancellation
record remains valid and unchanged for 32 edges, covering twelve compute
advances and one capture edge. An eight-edge quiet window sees no new DMA
admission, consumer advancement or fabricated Fence completion.

Those counters and the success record establish compute/capture drainage,
not arithmetic oracle agreement: poison prevents storing C1, and reset
invalidates it. The fixture makes no claim about that unobserved result.

## Joint reset and recovery

The first joint reset clears poisoned ownership. A new LoadA0 ID 91 then
accepts its first operand request at address 2048 on cycle 991, epoch tag 32
after 32 descriptor reads. Its saved response remains pending across the
second reset assertion and edge; the host presents its actual saved tag/data
valid, then flushes the obligation before reset release. Native assertions
check immediate pre-edge suppression; independent replay compares the recorded
post-edge public outputs. No interrupted ID 91 completion is manufactured.

After reconfiguration the first global tag is zero again. MatMul ID 92 rejects
the invalidated old slots with fault 4, and Fence ID 93 succeeds. Their 64
descriptor reads are the complete recovery epoch. Host bytes and lifetime
counts survive transport reset: 290 transactions/read bytes, no writes.
Every one of the 4096 host bytes matches the expected memory, including padding
and host-authored descriptor replacements.

## Retained artifacts and regression checks

The existing isolated network-disabled runner used Verilator 5.050 on
`linux/arm64`, image
`docker.io/verilator/verilator@sha256:6d8207220a9aa51fa8bed1449641cc5b113ca0ef912aa1a76afccd728a6391c5`.
Runner flags, locks, VM configuration and production hardware graph are unchanged.

The eleven generated artifacts, actual TSV and three runner receipts are kept
outside Git at
`/Users/kq/Workspace/lunachip/.phase6-fault-reset-evidence-20261005`.
The compiled run remains at
`/private/tmp/lunachip-phase6-fault-reset-20261005.eR6eIF`.

| Artifact | SHA-256 |
|---|---|
| `bundle/design.lcir` | `77aac2fc7d215ec361a290178a57d5d998d85b60cebf0f24ba9cff7026ad7892` |
| `bundle/stimulus.tsv` | `ffc5fad8572b54cc61917ab1df2501a41fc446b6953bc43fe3e5689f1257cada` |
| `actual.tsv` and `bundle/expected.tsv` | `116a6cab1717e6ee888ac01bc125c9410c102b44ff8416fef2bc098f367b13c7` |
| `verilator-lint-receipt.txt` | `43c38942f8a046316f8da52fe43f8da0b5fb7b938361a03a01c097ac02574706` |
| `verilator-build-receipt.txt` | `b1d76148053c1e89fcbb185be4a51fc290e44cec611ea363721534994628f970` |
| `verilator-execute-receipt.txt` | `30e6f7a1b1fe50dc4b0948621c860391277027ba8a76cecce529719417fe5676` |

All ten targeted fixture/CLI tests pass, including repeated complete bundle
bytes, a real output mutation and wrong-fixture identity rejection. All eleven
artifacts of each earlier fixture remain byte-identical after separating the
private tag epoch from lifetime counts. The complete native slice gate passed
743/743 tests, interface generation, formatting, warning-strict native check
with warning 73, default CLI smoke and dependency/source-size boundaries.
Loader/storer-owned poison, remote failures, randomized workloads/latency,
capacity/wrap, larger 8x8 replay, the complete synthesis matrix and named formal
tasks remain required; no physical accelerator or performance claim follows.
