# Fetched writer rejection and recovery replay on 2026-10-06

The `fetched-concurrent-1x1-k2-writer-fault-recovery` fixture passes strict
pinned Verilator lint, build, execution and typed audit. All 30 public outputs
agree across 2,887 post-reset cycles: 86,610 observations. Actual and expected
TSV are byte-identical. This is one differential workload, not the complete
Phase 6 gate, a formal proof or physical performance evidence.

The implementation checkpoint is `1926677110ef665c116b6cb7819e6b8d01dcf2cf`.
It uses logical Device ABI 1.0 and descriptor encoding 0.2 with a 1x1 array,
reduction capacity 2, 4096 host bytes, four ring slots and queue/retirement
depth three. [The workload contract](../PHASE6_DIFFERENTIAL_WRITER_FAULT.md)
fixes the descriptors, host timing and required checks.

## Observed behavior

Seventeen commands retire in admission order with IDs 101–117. A malformed
minor-version LoadA receives fault 12 without replacing the earlier valid
writer intent; its dependent MatMul and StoreC still produce 6. A subsequent
syntax-valid stride-zero LoadA receives fault 6. Its dependent MatMul and
StoreC receive faults 4 and 5, respectively, rather than using old physical
operands or results. An unrelated result remains usable and stores 35.
Recovery loads a fresh operand, actually executes and captures, and stores 27.
The final Fence succeeds and producer and consumer both reach 17.

The stream has exactly 552 accepted requests and matching acknowledgements:
544 descriptor-byte reads, five operand-byte reads and three result-word
writes. Totals are 549 read bytes and 12 written bytes. Five ring refills use
observed consumer credit. The rejected group's oldest completion remains
valid with every payload field unchanged for 32 edges. That group performs
128 descriptor reads, zero operand reads, zero C0 writes and one unrelated
C1 write. All five compute counters remain unchanged during the rejection
group; recovery adds one actual active edge and one capture edge.

The independent matrix oracle gives 6, 35 and 27. LunaWave's final host memory
matches all 4096 expected bytes, including ring replacements and untouched
sentinels. Independent RTL receives the frozen host inputs; exact agreement
on all public requests, responses, completions and counters validates the
recorded replay without adapting its inputs to RTL outputs.

## Validation and retention

The complete native slice gate passes 819/819 tests, interface generation,
formatting, strict native checking including warning 73, default CLI smoke,
and dependency/source-size checks. All ten fixture CLI tests pass. Public
tests check artifact determinism, complete output coverage, audit counts,
foreign identity rejection and deliberate observation mutation.
All eleven artifacts of each of the five earlier replay bundles remain
byte-identical: 55 exact filename/byte/SHA-256 comparisons.

The first external comparison helper stopped after a successful writer-bundle
export because it assumed lexical filename order, while MoonBit string
comparison sorts length-first. The original helper and export logs are
preserved. A separate resume helper checks the exact filename set, reuses the
original bundle unchanged and exports only the five older baselines. This was
a helper failure, not an RTL counterexample or a product-code change.

The unchanged network-disabled volume runner uses Verilator 5.050 and the
locked `linux/arm64` image
`docker.io/verilator/verilator@sha256:6d8207220a9aa51fa8bed1449641cc5b113ca0ef912aa1a76afccd728a6391c5`.
No VM, lock, bounds, warning policy or runner changes were made.
Actual inputs, compiled RTL work, trace, three published operation receipts,
command logs and ten checkpoint source files are retained outside Git at
`/Users/kq/Workspace/lunachip/.phase6-writer-fault-evidence-20261006`.
The original run is `/private/tmp/lunachip-writer-fault-20261006.A662eT`.
The verified aggregate inventory contains 348 files and has SHA-256
`ef9f8df44505700205eb1d2ddcad776f76f768b1c261088e3921be0e7e66fd08`.
Dirty pre-commit validation contexts and clean implementation-commit tool
contexts are retained individually; they are not claimed to share a HEAD.
Frozen implementation bytes match the committed checkpoint.

| Artifact | SHA-256 |
| --- | --- |
| `bundle/design.lcir` | `7d4ca530ab35e4fb735d3425d16d89b89b1f207bf8acf706d8529d07674361c6` |
| `bundle/stimulus.tsv` | `4b227e85d2ec5cf92b80416c29418631d0b5a78fdd00d28083cbf21ee7b9430d` |
| `build/actual.tsv` and `bundle/expected.tsv` | `c72dbb46954cb283d0fa18055b8fafb8d53d05d7b7b4820e3c02c44fcaae213a` |

Remaining loader/storer protocol-fault owners, partial remote failures,
capacity/origin wrap, arbitrary invalid descriptors, complete synthesis
coverage and full-device safety/fairness properties remain separate gates.
The incomplete Phase 5 FIFO and unchanged-snapshot aggregate receipts also
remain required. No FPGA, physical RAM, timing, area, power or silicon claim
follows from this replay.
