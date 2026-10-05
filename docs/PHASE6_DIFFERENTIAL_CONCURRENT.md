# Next fetched-device replay: measured engine overlap

This is the next implementation slice, not completed evidence. It follows the
[first successful pinned replay](evidence/phase6-differential-20261005.md).
Keep the existing pipeline generator and every original artifact byte unchanged.

Add `generate_concurrent_bundle()` for a predefined checked configuration:
1x1 array, reduction capacity 512, host aperture 4096, ring depth four and
queue/retirement depth three. Reuse the same ResultProtocol, public-port
collection, C++ harness, TSV parser and typed comparison. Only private host
configuration and trace/edge helpers are factored where the second fixture
requires reuse; do not add another runner, general scenario framework or public
unchecked plan. Each bundle owns its fixture identity.

## Workload and host ownership

Use ring bytes 3072..3199, scalar A0=2 at 32 and B0=3 at 64, signed K512 A1
bytes 512..1023 and B1 bytes 1280..1791, reload A0 bytes 2048..2559, and separate
four-byte result destinations 2800 and 2816. These regions do not alias.

Drain three scalar setup commands to produce C0=6, then two long loads to
initialize A1/B1. Publish four descriptors together at positions 5..8: MatMul
A1/B1 into C1, StoreC0, LoadA0 of 512 bytes, then Fence. The first three use
duplicate caller ID 77 and must retire by ordinal with progress 0,4,512; Fence
uses ID 78. Hold the oldest MatMul completion while the loader continues making
real bus progress. After that group drains, publish StoreC1 at position 9 with
ID 79 into the consumed slot. Producer and consumer must both finish at ten.

Before recording the fixture, require actual descriptor-read, operand-read and
store-write acceptance on edges where the new MatMul's active counter advances.
Classify response acknowledgements from the saved accepted request, not live
request outputs. Require StoreC0's successful ACK before the MatMul terminal
record appears, immutable held oldest completion with real loader handshakes,
and independent signed oracle agreement for both outputs and all 4096 host
bytes including padding. Expected arithmetic totals are 1860 transactions,
1858 read bytes and eight write bytes; they become measured facts only after
the reference workload passes.

K512 and a short fixed response delay provide a bounded initial timing choice.
Measure the overlap predicates before pinning. If latency tuning is needed,
change only the named fixture's host policy, retain deterministic backpressure
and regenerate its trace; never weaken the required predicates to obtain a pass.

## Scope and gate

The q3 retirement table fills with the three engines, so do not claim Fence
passes before the oldest external ACK, engine reuse under held retirement,
capture overlap, or all twelve overlap classes. Poison and reset are separate
later fixtures. Preserve the default export/audit commands; add explicit
concurrent export/audit commands using the same equality and failure paths.

After targeted native tests and original-artifact byte comparisons pass, run
strict pinned Verilator lint/build/execute/audit, then the completed native
slice gate. Commit the factoring, workload/tests, CLI and evidence separately.
This fixture still does not replace the full Phase 6 synthesis/formal gate.
