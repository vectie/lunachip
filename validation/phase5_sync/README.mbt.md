# Phase 5 synchronizer differential evidence

This package compares LunaWave with the existing digest-pinned Phase 3
Verilator runner through the schema-v2 atomic multi-clock contract. It owns
three public-LunaWire fixtures: a resettable asynchronous-input two-stage
synchronizer, a three-stage timed crossing with coprime normalized periods and
a nonzero-phase coincidence, and a four-stage timed crossing with non-coprime
periods and repeated phase-zero coincidences.

Normalized schedules are projected directly into stimulus events. Their exact
times, boundaries, simultaneous domain sets, and sparse domain IDs are retained
without reconstructing clocks in the harness. At each event, the production
harness lowers clocks, applies every drive, evaluates once, raises every active
clock before another evaluation, evaluates once, and samples once.

The sequential-edge bridge is generated only in the negative bundle. It
intentionally evaluates after each active clock and must first disagree at
normalized time 93, boundary 18, output `synchronized`. Production bundles do
not contain this bridge.

This is register-transfer differential evidence. It does not establish
physical placement, metastability behavior, MTBF, or timing closure.
