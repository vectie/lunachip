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

The rejected grep/count checker, synthetic RTLIL fixtures, and gate were
removed. A replacement must first capture actual locked `memory -nomap`
output, then implement a typed graph parser with alias canonicalization, exact
cell and memory bindings, isolated full-graph mutants, and an immutable
incomplete-first receipt. The checker must consume the schema-v2 typed roles;
it must not infer lane correspondence from array order or reintroduce a
presence/count contract. Until that graph checker passes, there is deliberately
no command that can label this matrix as exact topology evidence.

This evidence makes no RAM-inference, timing, placement/routing, metastability,
MTBF, or physical-CDC claim.
