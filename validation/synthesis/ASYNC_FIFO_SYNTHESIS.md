# Asynchronous-FIFO synthesis evidence boundary

This slice is separate from the legacy Phase 4 `SynthesisKind::Fifo` and
`FifoFormalFixture`. Its schema-v2 artifact is an
`async-fifo-pre-map-expected-contract`: it names the canonical FIFO roles that
a future checker must bind to an independently parsed Yosys graph. It is an
expected contract, not an observed pre-map result.

The expected contract records:

- exact depth, address width, pointer width, and synchronizer-stage count;
- source and destination domain objects with positive edges and nested
  synchronous, active-high, zero-valued reset objects;
- source valid/ready and destination ready/valid roles;
- binary and Gray current/next pointers, full/nonempty current/next flags,
  addresses, transfers, and both Gray synchronizer pipelines;
- one typed lane object per payload leaf, binding its index, private memory,
  width, source payload, raw read, and visible payload.

The `expected_contract.kind` token is
`canonical-ir-role-inventory-only`. Its pre-map typed-graph, RAM-mapping,
timing, physical-CDC, metastability, and four-state-equivalence fields remain
false. Only a later evidence artifact produced by the pinned checker may state
which of those independent observations passed.

The rejected grep/count checker and synthetic RTLIL fixtures remain removed.
Their replacement strictly parses actual locked `memory -nomap` JSON into a
typed graph, canonicalizes bit aliases, binds every role by identity, checks
owned state and equations, proves the crossing cutsets and payload barriers,
and validates the complete lane-local `$mem_v2` topology. Isolated mutants
exercise graph closure, lane swaps, second writers, guarded write arms, masks,
continuations, reset values, collision behavior, and initialization.

`AsyncFifoPreMapReport` remains an intentionally non-gating diagnostic. Its
artifact identity is `lunachip.async-fifo-pre-map-audit/v1`; even a clean run
says `incomplete`, sets `evidence_ready` false, and keeps every claim false.
This prevents unit tests or callers of the lower-level audit from accidentally
promoting an evidence claim.

The separate typed `AsyncFifoSynthesisEvidenceReport` is the only final-report
facade. It consumes the inventory JSON, pre-map JSON, pre-map RTLIL, and Yosys
lock text. Each input is bound by SHA-256 and its UTF-8 byte length. The report
also records the Yosys creator, fixed-order check statuses, canonically sorted
issues, and exact check/state/memory counts. It says `pass` only when the
complete graph-and-memory audit has no issues and all four bound sources are
nonempty. Only that pass promotes `pre_map_typed_graph`,
`two_state_role_equivalence`, `owned_state_exact`, and `memory_topology`.
The `audit.*` statuses are deliberately aggregate and atomic: every audit
status is `pass` only for an issue-free complete audit, and one audit issue
marks every `audit.*` status `fail`. Individual diagnostics remain available
through the sorted issue records; no partial audit status is an evidence claim.

The lock's schema, pinned digests, and execution validity are established by
the locked gate and its validator. This report content-binds the exact lock
text it was given; it does not independently reinterpret or weaken that lock.
Its strict schema is
`toolchain/yosys/async-fifo-synthesis-evidence.schema.json`.

The native command writes into a newly created directory and refuses any
existing output, so a previous receipt cannot be overwritten:

```sh
moon run --target native cmd/phase5-async-fifo-synthesis-check -- check \
  async-fifo-role-inventory.json pre-map.json pre-map.rtlil \
  toolchain/yosys/lock.json evidence-out
```

The resulting file is
`evidence-out/async-fifo-synthesis-evidence.json`. A failed receipt is still
written for diagnosis and the command exits non-pass.

This evidence makes no RAM-inference, timing, placement/routing, metastability,
MTBF, or physical-CDC claim.
