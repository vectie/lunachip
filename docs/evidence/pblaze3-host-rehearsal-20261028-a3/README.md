PBlaze3 corrected-history host/campaign rehearsal, 2026-10-28

All 29 host and 14 campaign cases passed against the corrected append-history scripts. No physical device was accessed. Source and reused native executable identities were checked before and after the run.

The retained driver is the unchanged test script with exactly its two initial native build calls omitted. The transformation is checked as reversible; all scenarios and assertions are identical. This refresh reused the active native CLI/mock binaries without compiling in the shared module native cache. Standalone Wasm caches remain outside this archive.

The scenarios cover verified NaN poison before START, correct stale DDR followed by missing/partial STORE rejection, dropped poison rejected before START, input/output overlap and bounds, exact CPU comparisons, delayed completion, torn snapshots, fault/health/reset/count rejection and portable dispatch configuration. The separate five-case history archive proves multiple command records and stdout/stderr survive successes followed by timeout/nonzero; this refresh reruns the full existing host/campaign suite after that fix.

Fresh command histories, per-case logs, inputs, result traces, receipts and mock state are retained. Regenerable executable symlinks are omitted, with exact identities and original targets recorded. Earlier archives and run directories remain untouched. Full-layer preflight evidence is referenced from the prior archive rather than copied or rerun.

These are software orchestration checks. Physical DDR geometry, PCIe/JTAG and accelerator execution still require the board.
