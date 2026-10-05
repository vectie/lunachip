# Signed 8x8 two-slot independent replay

This slice extends the existing fetched-device replay machinery; it adds no
new runner, oracle or evidence protocol. Its predefined profile is
`fetched-concurrent-8x8-k16-two-slots`: 8x8, reduction capacity 16,
host4096, ring4 and q3. Reference generation is not independent RTL evidence.

## Workload and host ownership

Use distinct deterministic signed INT8 operands, including -128, 127, zero and
-1. Preserve padding in the following disjoint byte layouts:

| Buffer | Base | Shape | Row stride |
|---|---|---|---|
| A0 | 512 | 8x16 bytes | 20 |
| A1 | 768 | 8x16 bytes | 21 |
| B0 | 1280 | 16x8 bytes | 12 |
| B1 | 1536 | 16x8 bytes | 13 |
| C0 | 2048 | 8x8 INT32 | 40 |
| C1 | 2560 | 8x8 INT32 | 44 |
| Descriptor ring | 3072 | 4x32 bytes | 32 |

Drain LoadA0, LoadB0, MatMul into C0 and Fence before publishing LoadA1,
LoadB1, MatMul into C1 and StoreC0. Publish StoreC1 and Fence only after the
pre-edge consumer has released their reused ring slots. Caller IDs 101–110
must retire in order with success and exact progress. C0 persists while the
second compute uses C1; both stores are checked against the independent
row-major oracle and every one of the 4096 host bytes, including padding and
the final host-authored descriptor replacements.

Vary request readiness deterministically and delay responses by one through
five host edges. Hold the oldest LoadA1 completion for 64 edges, require all
its fields to remain immutable, and observe real younger descriptor-or-B1
request and response handshakes. This combined progress predicate does not
prove that both traffic classes individually advance, nor does this fixture
measure Run/capture overlap.

## Validation obligations

The exact expected totals are 320 descriptor reads, 512 operand reads and 128
word writes: 960 transactions and matching acknowledgements, 832 read bytes
and 512 write bytes. Each delay class is exercised 192 times. Both MatMul
records require accepted=active=30, elapsed=31, capture=64 and stall=0; these
are latest-inner-compute counters, not physical throughput measurements.

Run the focused deterministic bundle, exact typed-comparison and deliberate
output-mutation tests first. Preserve every artifact of the three earlier
fixtures byte-for-byte after the private host-policy addition. Export through
the existing native CLI and run strict pinned Verilator lint/build/execute,
then audit all 30 public outputs against the complete reference trace.
Record actual cycle count, identities and retained artifact hashes only after
execution. Larger randomized, fault-owner and formal obligations remain
separate gates; no physical hardware or performance claim follows.
