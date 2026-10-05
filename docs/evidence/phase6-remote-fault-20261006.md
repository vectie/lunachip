# Fetched remote failure and partial write recovery on 2026-10-06

The `fetched-concurrent-1x2-k2-remote-fault-recovery` fixture passes pinned
Verilator lint, build, execution and typed audit. All 30 public outputs agree
across 2,822 cycles, or 84,660 observations. Actual and expected TSV are
byte-identical. This is a fixed matching remote-failure replay, not the complete
Phase 6 gate or a full-device formal result.

Implementation checkpoint `54774903d6fd8b62f03aba4778aa8fb4419c4b1a` uses
Device ABI 1.0, descriptor encoding 0.2, a 1x2 array, reduction capacity two,
four ring slots, queue/retirement depth three and 4096 host bytes. The
[workload contract](../PHASE6_DIFFERENTIAL_REMOTE_FAULT.md) fixes sixteen
descriptors, two once-only failures and the independent signed matrix oracle.
No production hardware, ABI or external runner changes are introduced.

## Observed remote failures and recovery

The first StoreC0 writes its first four-byte word successfully. Its second
accepted word request has tag 201 and address 1540. The host commits only the
low two bytes before returning the saved matching status 1 response. Completion
fault 9 reports four successful bytes and address 1540; the failing ACK adds no
successful progress. Before retry descriptors overwrite the ring, all 4096
host bytes match the independent checkpoint, including second-word bytes
`[203,255,165,165]`. A full four-byte host write followed by a changed ACK would
not pass that checkpoint.

Retry stores the same C0 generation without reset or recomputation. C0 is
`[-23,-53]`; both stores of the distinct unrelated C1 result `[35,93]` check
each actual accepted word against the independent oracle, preventing a later
overwrite from hiding an incorrect first transfer.

Replacement LoadB0 successfully commits two elements, then the accepted third
read at address 771 and tag 304 receives matching status 1. Its fault 9
completion reports two successful bytes and address 771. The fourth byte is not
requested during this failed reload. The dependent MatMul rejects with fault 4
and StoreC with fault 5, both with zero progress and address. That three-command
group issues 96 descriptor reads, zero operand reads, zero C0 writes and two C1
writes; all five compute counters remain unchanged before and after every edge.
The rejected store destination remains sentinel 165.

Successful reload, recomputation and store create fresh generations and produce
`[-16,33]`. Three actual active edges and two capture edges are observed; final
accepted/active/elapsed/stall/capture counters are `[3,3,4,0,2]`. Final all-byte
checks cover the old C0, distinct C1, recovered C0, padding and final ring slots.
There is only the startup reset: no joint reset, flush or host reinitialization.
Reader fault, shared halt and transport fault address remain zero throughout.

All sixteen completions retire in order. Five safe refills finish with producer
and consumer sixteen. The stream contains 537 continuous-tag request/ACK pairs:
512 descriptor-byte reads, fifteen operand-byte reads and ten result-word writes.
Exactly two ACKs have status 1. Writes request forty bytes, physically affect
thirty-eight and report thirty-six successfully acknowledged bytes. These are
distinct functional measures, not physical throughput.

## Validation and retained evidence

The full native slice gate passes 825/825 tests, interface generation, formatting,
strict native checking including warning 73, default CLI smoke and dependency
and source-size boundaries. The focused remote test passes 1/1 and fixture CLI
tests pass 12/12. The initial CLI run found a stale expected help string;
`cli-tests-failed-help` retains its actual failure. The corrected run also tests
missing and excess arguments for both new commands. Determinism, all artifacts,
complete output ports, a changed observation and foreign fixture identity are
checked. All 77 artifacts of seven earlier fixtures remain byte-identical.

The unchanged, network-disabled volume runner uses Verilator 5.050 and locked
`linux/arm64` image
`docker.io/verilator/verilator@sha256:6d8207220a9aa51fa8bed1449641cc5b113ca0ef912aa1a76afccd728a6391c5`.
The dedicated validation VM retains its existing 8 GiB RAM and 4 GiB scoped guest
swap. No compiler flags, warning waivers, hardware inputs or test bounds change.

Original inputs, generated C++ and executable, actual trace, three published
operation receipts, failed/successful logs and sixteen checkpoint source files
are retained at
`/Users/kq/Workspace/lunachip/.phase6-remote-fault-evidence-20261006`.
The original run is `/private/tmp/lunachip-remote-fault-evidence-20261006.xRVfK2`.
The verified inventory contains 417 files with SHA-256
`3316d6b5d7cd9f19ecec2e7fde138363d9eb7592450206b089e45051a6b59ae8`.
Dirty native validation contexts and clean committed tool contexts remain
individually recorded; they are not claimed to share one HEAD. Frozen source
hashes match the committed implementation checkpoint.

| Artifact | SHA-256 |
| --- | --- |
| `bundle/design.lcir` | `651b0ce19643163e540438e35a06536bd1f1a3aca0474edfdf1ca9d85f1a0835` |
| `bundle/stimulus.tsv` | `23905d2ef625bb35f29231c8f018c27b5d0b84d8601a43d769cf573ba8f5fe50` |
| `build/actual.tsv` and `bundle/expected.tsv` | `3153233e1095df2008b699a9f2f5ada633c8078b6ea458bb6c1abc6343671a09` |

This slice adds no Run-overlap or held-retirement requirement. Arbitrary invalid
descriptors, independent capacity/origin wrap, remaining synthesis coverage,
full-device safety/fairness and the fresh unchanged-snapshot Phase 5 aggregate
remain separate gates. Physical RAM, analog CDC, FPGA timing, power and silicon
remain unclaimed.
