# Seeded signed 8x8 replay

The fixed fixture `fetched-concurrent-8x8-k16-seed-5eedc0de20261005` adds
randomized matrices, request backpressure and host response delays to the
existing independent-replay path. It reuses the [8x8 two-slot layout and
command sequence](PHASE6_DIFFERENTIAL_ARRAY8.md), checked capabilities,
host transaction engine, scalar INT8 oracle, trace format and pinned runner.
There is no second host or evidence protocol.

All 14 targeted replay/exporter tests pass, including repeated generation of
all eleven artifacts, deliberate public-output mutation and wrong-fixture
identity rejection. This validates reference generation and audit handling;
all eleven artifacts of each of the four earlier replay fixtures remain
byte-identical after the host-policy addition. Strict pinned RTL lint/build/
execute and typed audit now agree across 7,488 cycles and all 30 outputs; the
[retained result](evidence/phase6-seeded-20261005.md) records exact scope and
artifact hashes.

## Reproducible independent streams

Use the existing fixed SplitMix64 implementation with master seed
`5eedc0de20261005`. Three instances derive their seeds by XOR with separate
labels, so matrix draws do not change transport schedules:

| Stream | XOR label | Derived seed | Draws |
|---|---|---|---|
| Matrices | `4d4154524958` | `5eed8d9f7474595d` | 516 |
| Request readiness | `5245414459` | `5eedc08c6567545c` | 32769 |
| Response delay | `4c4154454e4359` | `5ea1818a6568535c` | 960 |

Draw 512 signed INT8 values for A0, B0, A1 and B1 from the low byte minus
128. Four further draws select one offset per matrix. Replace five distinct
positions `(offset + 23*i) % 128` with `-128, 127, 0, -1, 1`: 492 random
samples remain and 20 explicit edge values are injected. Both 64-word signed
INT32 results must differ and match the independent row-major oracle. Check
all 4096 host bytes, including padding, unchanged operands and final
host-authored descriptor replacements.

Precompute one request-readiness bit per cycle through the fixed 32768-cycle
budget: ready is zero when the sampled value modulo four is zero. Check actual
zero/one driven-cycle counts and require genuine valid-request stalls. For
each of the 960 accepted requests, sample a delay counter from one through
seven. Check the installed counter against the saved accepted request, not
an offered but unaccepted request. Every class must occur; its fixed histogram
is `133, 133, 149, 150, 140, 121, 134`.

These are programmed response-delay counters, not measured request-to-ACK
latencies. The shared host decrements the counter after an edge and presents
response valid on the following edge once zero. Response acceptance remains
an actual handshake. Neither the schedule nor its histogram is a formal
fairness assumption or statistical-coverage claim.

## Required measured checks

Retire ten successful commands with IDs 101–110 and exact progress. Preserve
both persistent result slots and perform two ring refills using pre-edge
consumer credit. Require final producer and consumer counts of ten. Hold
LoadA1's oldest completion valid with every payload field unchanged for 64
edges, and require actual younger descriptor-or-B1 request and response
handshakes during that hold. This combined predicate does not measure
Run/capture overlap or prove both traffic classes separately.

Require 320 descriptor reads, 512 operand reads and 128 full-word writes:
960 requests and matching acknowledgements, 832 read bytes and 512 write
bytes. Both MatMul completions must report accepted=active=30, elapsed=31,
capture=64 and stall=0. These counters describe inner computation, not
physical throughput. Missing progress, a stream-budget overrun or any
unexpected reader/transport fault fails generation; do not weaken checks to
fit the seed.

## Independent execution

Export only to a new directory, then use the existing pinned lint/build/execute
flow and audit all 30 public outputs:

~~~sh
moon run --target native --release cmd/phase6-fixtures -- export-seeded /absolute/new-bundle
scripts/phase3-verilator-run.sh oci lint /absolute/new-bundle /absolute/empty-lint-output
scripts/phase3-verilator-run.sh oci build /absolute/new-bundle /absolute/empty-build-output
scripts/phase3-verilator-run.sh oci execute /absolute/new-bundle /absolute/compiled-build-output
moon run --target native --release cmd/phase6-fixtures -- audit-seeded /absolute/actual.tsv
~~~

Retain the actual cycle count, readiness/stall counts, hold-progress counts,
all result rows, source/RTL/stimulus identities, operation receipts and logs.
Compare all eleven artifacts of each of the four earlier replay fixtures
byte-for-byte. One successful fixed seed is a reproducible randomized case,
not exhaustive matrices or transport coverage. Remaining capacity/wrap,
fault-owner, synthesis and formal obligations are separate gates. No physical
RAM, frequency, area, power or silicon claim follows from this replay.
