# Direct q3 completion inputs and clean native gate

The three direct-completion fixtures generate, regenerate through the registry,
and export through the existing CLI. The clean native module passes 955/955
tests. This checkpoint records **inputs only**: no completion proof, useful-Store
cover or deadline-negative counterexample has run. Phase 6 remains open.

## Exact source and evidence

Executed source: `c50261ee9633cd1be3b96cae5686d6f4aca5d190`, with unchanged clean
status before and after each clean job. `moon info`, `moon fmt`, strict native
check, the full serial native test run and a fresh CLI build all exit zero.
Working fixture/registry/CLI tests also pass 23/23.

Support: `/private/tmp/lunachip-direct-completion-inputs-20261007.b02aI4`.
Mirror: `.phase6-direct-completion-inputs-evidence-20261007/`. The complete
252-file `outputs.sha256` digest is
`3cac9f39a8892298a2f2499305cc464c9755d93e60b71ff07f297af7e730a2f7`.
Both inventories verify and the two trees compare exactly. The seal includes
failed drafts, repaired checks/tests, compiled script caches, clean command
records, actual exports and independent input qualification.

| Fixture | Exported artifacts | Tasks | Meaning, not observed result |
| --- | ---: | ---: | --- |
| `phase6-flux-tile-direct-q3-eventual-r2-h2-c2-d252` | 13 | 3 | Bounded safety, watched terminal and ordinal ACK covers |
| `phase6-flux-tile-direct-q3-useful-store-r2-h2-c2-d252` | 9 | 1 | Useful Store write/ACK/retirement cover |
| `phase6-flux-tile-direct-q3-negative-deadline1` | 9 | 1 | Selected deadline sensitivity check |

All three preserve ordinary direct 1x1/K2/host1024/q3 IR digest
`35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc`.
Tasks use 640 global steps / 320 DUT rising opportunities and 600-second
timeouts. This horizon contains the complete inclusive 252-edge deadline for
a watch admitted in the first 32 post-reset edges.

## Independent emitted-input review

All 115 observation bindings match actual original-node DUT assignments.
Clock, observer state and properties use the existing rising-PRE convention.
The watch saves the actual public packet and counts ordinal admission and
retirement, including same-edge older ACK. Caller IDs may repeat. ACK wins
at age 252; reaching the search horizon does not disable an outstanding check.

Seven eventual premises constrain one initial joint reset and public producer,
host response and R2/H2/C2 availability. Response availability is an **offer**,
not assumed DUT readiness or acceptance. Request persistence, response
readiness, completion stability, serial ownership, ordinal history and deadline
are six DUT conclusions. Three reachability covers remain.

Useful Store adds only the named public four-packet producer premise. Its cover
requires actual good reads with paired owned ACKs and all four addresses,
original engine accepts/collectors, three prior successful retirements, a real
four-byte Store write at address 128 with mask 15, matching successful host ACK,
and successful ordinal Store retirement. This is not a numerical MatMul proof.

The negative differs from eventual by exactly one checked-deadline expression:
canonical watched LoadA uses one edge instead of 252. Its task selects only the
stable deadline assertion. An actual LoadA admission and next PRE with age one
and no ordinal ACK must still be witnessed and qualified.

## Retained repairs and remaining obligations

Draft type/effect fixes and unsuccessful label-order assertions remain in the
support tree. Canonical formal labels are not insertion order or MoonBit's
default String shortlex ordering; repaired tests check exact membership/count.

The accepted FIFO prefix is a separate supporting theorem. Full packet and
retirement composition, Store preservation, DMA/nested-memory bounds, fetched
transport and scope-specific completion checks remain open. These exports do
not qualify comparison helpers, execute a solver or finish any of those gates.
