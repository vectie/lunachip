# LunaChip implementation status

This ledger records what current repository evidence proves. It is deliberately
stricter than a feature checklist: a phase remains in progress until every gate
in `PLAN.md` has direct evidence.

## Phase ledger

| Phase | Status | Current evidence | Remaining gate |
|---|---|---|---|
| 0 — Repository and semantic skeleton | passed locally | versioned canonical codec; byte-stable round trips; fixed construction-order digest; stable diagnostics and source metadata; pinned CI definition and external-tool manifest schema; full native gate | remote CI execution begins when a remote is configured, but is not substituted for the completed local gate |
| 1 — Combinational LunaWire and LunaWave | in-progress | exact typed builders and IR nodes; shortest stable cycle paths; shared known-mask semantics; exhaustive small-width and seeded end-to-end simulator tests | record prepared steady-state allocation profile and make any required schedule changes |
| 2 — Sequential semantics, trace, and replay | in-progress | uninitialized/initialized registers, feedback-safe next-state construction, deterministic rising-edge API, simultaneous commit tests | explicit domain/reset/enable semantics, properties, native traces, VCD, snapshots, replay |
| 3–10 | not-started | research and gates documented | all deliverables and evidence in `PLAN.md` |

## Phase 0 evidence

The repository phase gate runs:

```sh
moon info
moon fmt
moon check --target native --deny-warn --warn-list +73
moon test --target native --deny-warn
moon run --target native cmd/lunachip
scripts/check-boundaries.sh
```

Canonical codec tests prove:

- schema version rejection and strict canonical parsing;
- parse/serialize/parse byte stability;
- deterministic module and output ordering;
- a reviewed fixed digest fixture;
- UTF-8 names and every current canonical node operation;
- malformed, noncanonical, truncated, and IR-invalid input rejection.

Diagnostic tests prove stable-code uniqueness, checked source coordinates,
immutable semantic paths, related spans, corrections, and adapters for IR and
LunaWire failures.

## Phase 1 evidence and restraint

The implemented combinational surface is subtraction, low/full multiply,
equality, ordered comparison, logical and arithmetic shifts, inclusive slice,
MSB-first concatenation, zero/sign extension, truncation, reinterpretation,
bitwise logic, add, and mux. Width and signedness changes are explicit.

LunaWave delegates those operations to the shared `semantics` package rather
than retaining a second implementation. Tests exhaustively cover small known
values, exercise signed behavior and overshifts, cover representative unknown
propagation, and run a deterministic seeded oracle stream.

Phase 1 is not marked passed because the prepared steady-state allocation gate
still needs measured evidence. That work must profile a representative prepared
design and either prove the loop allocation-free or record and schedule each
remaining allocation source.

## Claim boundary

Current evidence supports “canonical LunaChip IR skeleton” and “the named
combinational subset runs in the LunaWave reference interpreter.” It does not
support claims of SystemVerilog compatibility, differential validation,
synthesis, FPGA execution, GDS, fabrication, or silicon performance.
