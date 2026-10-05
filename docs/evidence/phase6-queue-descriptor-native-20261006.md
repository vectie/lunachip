# Queue task and descriptor replay native checkpoint

The queue-conservation exporter and fetched descriptor-rejection replay pass
the full native gate: 838/838 tests, strict checking including warning 73,
public interface generation, formatting, CLI smoke and dependency/source-size
boundaries. The implementations are committed separately as `8ca341c` and
`011a0485865571a6237f6b92ed3c82ce9a24cfe4` and integrated into the main repository.
Phase 6 remains in progress; this checkpoint establishes native generation
and replay behavior, not device formal safety or independent RTL agreement.

## Native validation and source context

The gate ran against the pending implementation at HEAD
`e8d9fff2e39d994a4e14a665d42728a0715043f3`, before the two implementation
commits. Its original before/after HEAD and complete Git-status snapshots match.
The successful native build and subsequent artifact comparisons use clean
commit `011a048`. No precommit run is relabeled as a clean-source result.

Original logs are under
`/private/tmp/lunachip-descriptor-rejection-support-20261006.wApINc`.
They retain the initial mixed-error compile failure, both output-order test
failures, corrected targeted passes and the full gate. Canonical IR sorts
outputs; corrected identity tests compare complete canonical bytes and emit
RTL from the independently constructed module's original output order.

## Queue exporter and exact adapter check

The unchanged direct 1x1/K2/host1024/q3 DUT supplies all 115 exact typed
observations. The positive bundle contains three structural assertions and a
full/refill capture cover; the negative changes only the selected population
comparison after genuine admission and reservation. It adds no ordinary IR
node, register, memory or ABI port.

The existing pinned SAT helper check passes all 19 emitted comparison helpers
for defined binary inputs. The negated miter fails its selected proof with
actual exit one, confirming sensitivity. This is pointwise Boolean equivalence,
not four-state or sequential device equivalence.

| Adapter input | SHA-256 |
| --- | --- |
| Ordinary production RTL | `977623cc1a7c835ca6da9287c4625ab9f36cf172d30158ae728fc461b630d44f` |
| Exact queue formal adapter | `b81ca96190670c59fa630b13430180c48f227cf8a4931256b8d356eb5d1cfef5` |

Queue inputs, helper results and old formal comparisons are under
`/private/tmp/lunachip-phase6-formal-compat-20261006.ISG3ZQ`.
The actual queue safety, cover and selected counterexample remain separate
task results; helper equivalence cannot stand in for them.

## Descriptor rejection replay

The ordinary fetched 2x2/K2 device executes 86 descriptors in 31 drained
publication groups over 14,464 post-reset cycles. Its independent oracle checks
26 successful and 60 fault completions, 2,768 request/ACK pairs, nine accepted
word writes and all 4,096 host bytes. Seven rejection windows have no data DMA
or compute-counter changes. Successful arithmetic is specifically 1x1/K1,
with results 6, an unrelated retained result 35 and fresh recovery result 27.

The bundle contains 11 deterministic artifacts and 30 defined output taps,
for 433,920 expected observations. Its identity-bound reference self-audit is
Equal; it is not an independently executed RTL audit. The workload contract is
[the descriptor rejection specification](../PHASE6_DIFFERENTIAL_DESCRIPTOR_REJECTION.md).

| Replay input | SHA-256 |
| --- | --- |
| Canonical design | `196acd54e9ac1546585a808d3ac461858d430f19beb463fd03f586d73a694343` |
| Expected observations | `218f22c9a3ded912992013284ba415d512636877356d1bc2ec3012887ad1e66c` |

## Compatibility results

All 93 artifacts from nine older formal bundles and all 99 artifacts from
nine older replay bundles match their retained baseline filenames, bytes and
SHA-256 digests exactly. Local generation inputs are not substituted for
the old full-DUT formal bundles.

| Comparison inventory | SHA-256 |
| --- | --- |
| 93 old formal artifacts | `ddda42d48dca193873f141bc4a35d86e68dd5fb225c9aadfd25a3c5d98e6c171` |
| 99 old replay artifacts | `0913c11ccc7279c5924c838bd005fa5b3186403020ce340a600cb04ae44a359a` |

These results do not complete saved-packet identity, engine ownership, immutable
retirement, leases, fairness, fetched/8x8 formal coverage or the Phase 6 gate.
Physical RAM, timing, power, FPGA and silicon claims remain excluded.
