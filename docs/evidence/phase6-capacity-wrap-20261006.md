# Fetched capacity and origin wrap on 2026-10-06

The `fetched-concurrent-1x1-k1-capacity-origin-wrap` fixture passes pinned
Verilator lint, build, execution and typed audit. All 30 public outputs agree
across 1,371 cycles, or 41,130 observations. Actual and expected TSV are
byte-identical. This is one bounded capacity/origin-wrap replay, not the complete
Phase 6 gate or a formal result.

Implementation checkpoint `87b958372d3a75ec16a9825cae1d6abe91511c4f` uses
Device ABI 1.0, descriptor encoding 0.2, a 1x1/K1 array, ring base 3072,
two ring slots, queue/retirement depth two and 4096 host bytes. The
[workload contract](../PHASE6_DIFFERENTIAL_CAPACITY_WRAP.md) fixes eight
canonical Fence commands with IDs 401 through 408. No production hardware,
ABI, external runner or formal monitor changes are introduced.

## Observed ownership and drainage

The real configuration handshake records origin `0xfffffffe` (4294967294).
Producer and consumer begin at that origin; accepted publications are zero,
two, four and six. The first two refills wait for committed consumer zero
and two, respectively, and an idle host. Descriptor read ACKs do not authorize
slot reuse.

With completion readiness held low, five commands are admitted and the sixth
is fetched but not admitted. At that checkpoint consumer is three, producer
four, queue occupancy two and exactly 192 descriptor reads and matching ACKs
have occurred. The oldest successful completion is `(401,0,0,0)`. The sixth
packet remains in host-owned slot one, bytes 3104 through 3135. All 4096
host bytes match the independent sentinel-and-installed-packet expectation.

Across 32 additional quiet edges, the consumer, producer, queue occupancy,
oldest completion and saved slot bytes remain unchanged before and after each
edge. There are no accepted requests, ACKs or new publications; the host has
no pending response or stalled request. Publication readiness is zero because
the reader holds a backpressured Packet. All five compute counters stay zero.

Releasing completion readiness retires 401 through 406 in order. Only after
consumer and producer reach four, queue occupancy becomes zero and the host
is idle is the final pair installed. Publication six retires 407 and 408.
All eight completions have zero fault, progress and address. Final consumer
and producer are six. Exactly 256 descriptor-byte reads and successful ACKs
use continuous tags zero through 255, with no operand read or write.
Every final host byte matches sentinel 165 plus the last two descriptors.
Reader faults, shared halt, transport fault address and all compute counters
stay zero throughout. Only the startup reset is applied; there is no flush,
host reseeding or recovery reset.

## Validation and retained evidence

The full native slice gate passes 828/828 tests, interface generation,
formatting, strict native checking including warning 73, default CLI smoke
and dependency/source-size boundaries. The focused capacity test passes 1/1
and fixture CLI tests pass 13/13. The first strict check found a deprecated
`ArrayView.to_array` call; its actual failure is retained under
`native-check-failed-deprecated-view`. The corrected code uses `to_owned`.
Determinism, all eleven artifacts, all thirty output ports, origin in the
recorded trace, a changed observation and foreign fixture identity are checked.
All 88 artifacts of eight earlier fixtures remain byte-identical. Their
comparison inventory SHA-256 is
`bbae47c353d51a63ed68fde300f9ad557fa07f536a1808db7fa3af16b75a2d1c`.

The unchanged, network-disabled volume runner uses Verilator 5.050 and locked
`linux/arm64` image
`docker.io/verilator/verilator@sha256:6d8207220a9aa51fa8bed1449641cc5b113ca0ef912aa1a76afccd728a6391c5`.
No tool pins, warning waivers, compiler flags, hardware inputs or bounds change.
The dedicated validation VM keeps its existing 8 GiB RAM and 4 GiB scoped swap.

Original inputs, generated C++ and executable, actual trace, all three published
operation receipts, failed/successful logs and seventeen checkpoint files
(thirteen source/interface/specification files plus four runner/pin files)
are retained at
`/Users/kq/Workspace/lunachip/.phase6-capacity-wrap-evidence-20261006`.
The original run is `/private/tmp/lunachip-capacity-wrap-evidence-20261006.9h0OS2`.
The verified inventory contains 434 files with SHA-256
`2ed411758e0f92f4b007e190e44a94a25b3a745421694e14a93d8d4c7c1db96d`.
Dirty native validation contexts and clean committed tool contexts remain
individually recorded; they are not claimed to share one HEAD. Frozen source
hashes match the committed implementation checkpoint.

| Artifact | SHA-256 |
| --- | --- |
| `bundle/design.lcir` | `cb2c2e85e2897f7de8d1ded1be154bba8fb8bfbd936eff31f5af66649dab6a37` |
| `bundle/stimulus.tsv` | `bc26481f7752a4b775ab11db44300ef0ad88777f7f380a7dd4990aa2f4b9a7ba` |
| `build/actual.tsv` and `bundle/expected.tsv` | `75d8b81d42dd79dbcd9f96042a1ffa3c4c580d67c77dabd1f295abd1bba29e83` |

This slice tests reader origin and producer/consumer wrap, not internal queue
ticket wrap. It adds no invalid publication, arithmetic, Run overlap or reset
recovery claim. Remaining invalid-descriptor coverage, synthesis, full-device
safety/fairness and the fresh unchanged-snapshot Phase 5 aggregate remain
separate gates. Physical RAM, analog CDC, timing, power and silicon remain
unclaimed.
