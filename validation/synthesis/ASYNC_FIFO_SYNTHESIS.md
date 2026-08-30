# Asynchronous-FIFO synthesis evidence boundary

This slice is separate from the legacy Phase 4 `SynthesisKind::Fifo` and
`FifoFormalFixture`. The generated document names the canonical FIFO roles
needed by a future checker. It is not a pre-map RTLIL topology result.

The rejected grep/count checker, synthetic RTLIL fixtures, and gate were
removed. A replacement must first capture actual locked `memory -nomap`
output, then implement a typed graph parser with alias canonicalization, exact
cell and memory bindings, isolated full-graph mutants, and an immutable
incomplete-first receipt. Until then, there is deliberately no command that
can label this matrix as exact topology evidence.

This evidence makes no RAM-inference, timing, placement/routing, metastability,
MTBF, or physical-CDC claim.
