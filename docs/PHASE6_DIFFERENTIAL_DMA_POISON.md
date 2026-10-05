# Fetched loader and storer protocol fault replay

This fixture completes independent replay coverage of the two remaining shared
transport protocol-fault owners. The reader-owner fixture already exists.
It reuses the fetched concurrent device, host-byte environment, deterministic
eleven-artifact exporter, 30-output comparison and pinned Verilator runner.
No hardware controller, formal monitor, tool policy or new scenario framework
is added. This fixture does not complete Phase 6.

## Fixed workload

Use logical Device ABI 1.0, descriptor encoding 0.2, an 8x8 array, reduction
capacity 64, 16384 host bytes, ring depth 16 and queue/retirement depth 16.
Ring base is 8192 and origin is zero. Reproduce the existing public-port native
fault workload: first load A0/B0 with K5 and compute C0; then load signed A1/B1
with K64. Setup IDs are 10 through 14. Drain each setup batch before changing
host bytes. These operations establish physical storage through actual DMA
and computation, not software state injection.

The fault batch contains Fence200, LoadA0/201, StoreC0/202, MatMul1/203,
StoreC1/204 and Fence205. LoadA0 replaces the old A0 while StoreC0 uses the
already computed C0; MatMul uses the unrelated loaded A1/B1 and targets C1.
The replacement A0 bytes are -7. StoreC0 uses base4096/stride40; StoreC1 uses
base5120/stride40. Leave destination padding and untouched bytes at sentinel165.
Signed setup data, layouts and oracle values follow the existing
`ring_concurrent_fault_test.mbt` workload exactly.

Run two fixed fault epochs in one trace: loader ownership, then storer
ownership, separated by joint reset. Corrupt only the saved response for an
actually accepted transaction of the selected class. Preserve its global tag
and data, and drive response fault2. Arm only after both data DMA classes have
nonzero successful ACK-backed progress, consumer count is at least9, and
compute active cycles are strictly between0 and78 with capture still zero.
If those predicates cannot be met, generation fails rather than weakening the
scenario. Any response delay used to reach that window is recorded and bounded.

Hold Fence200 while discovery and compute drainage occur. The hold continues
until the accepted compute reaches all78 active edges and64 capture edges;
its valid bit and all completion payload fields must remain identical before
and after every held edge. Then drain exactly the admitted prefix captured at
discovery, never the published count. In particular, an incomplete or held
unadmitted reader packet gains no completion obligation.

## Required observable checks

The malformed response must actually handshake while the compute counter
advances on that same edge. Require shared halt and the owned accepted request
address, with no fabricated reader fault. The owner completes fault10 and the
actual address; its unfinished data sibling completes fault15/address0.
Both report only prior successful ACK-backed progress. Fence200 remains a
successful terminal, accepted MatMul203 drains successfully, and remaining
admitted but unissued commands cancel with15 and zero progress/address.

After discovery, no further memory request, publication or packet admission
may be accepted. Record a finite quiet window after exact ordered retirement.
Observe request/response ownership and stalled payloads through the existing
host checks. Derive partial result writes from accepted requests and compare
every committed byte against the independent old-C0 matrix oracle; untouched
words/padding must remain sentinel165. The malformed store request has the
existing full four-byte accepted-write side effect, but must not count as
successfully acknowledged completion progress. This replay does not model
a partial remote write.

After each fault epoch, jointly reset the device and flush old host transport
obligations before deassertion. Require cleared poison, configuration,
publication/consumer counts, queue/retirement and compute counters, and the
first new request tag0. Fetch a stale-slot MatMul followed by Fence: MatMul
must reject invalidated operand metadata with fault4 and no DMA/compute,
while Fence succeeds. Reset again before the next complete setup epoch.

Record each owner's accepted transaction, ACK-backed loader/storer progress,
fault address, discovery active count/advance, held edges/compute drainage,
admitted prefix and exact ordered completions, quiet interval and resets.
Check all16384 final host bytes against deterministic host refills and oracle
write effects. Keep actual observations separate from programmed delays.

## Integration and validation

Extend the private host drive with the actual two-bit response fault input;
old fixtures keep zero and their eleven-artifact bundles must remain exactly
byte-identical. Reuse the existing private fault context with explicit ring
base and finite budget instead of creating another replay engine. Add only
`generate_dma_poison_bundle`, `export-dma-poison` and `audit-dma-poison`.
The public API needs checked documentation, black-box determinism/complete
ports/audit tests and an observation mutation control. The CLI also checks
foreign trace identity.

Validate source in an isolated checkout while the existing Phase 5 gate's
checkout remains frozen. Run compiler/test and external engines serially;
do not merge into its live snapshot. At slice completion run the native gate,
compare all66 earlier fixture artifacts, commit implementation, then run
unchanged pinned RTL lint/build/execute and typed audit in a fresh directory.
Retain original receipts and inputs without adapting them to independent
outputs, and record the result in a separate commit.

A pass covers these two fixed malformed-response owners and recorded timing.
Matching remote faults/partial writes, arbitrary packet and capacity/origin
wrap cases, complete synthesis and full-device safety/fairness gates remain
separate requirements. No metastability, timing or physical-chip claim follows.
