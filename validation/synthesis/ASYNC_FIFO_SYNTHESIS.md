# Asynchronous-FIFO synthesis evidence boundary

This slice is separate from the legacy Phase 4 `SynthesisKind::Fifo` and
`FifoFormalFixture`. It checks the locked Yosys `memory -nomap` RTLIL before
technology mapping. The expected document names the canonical FIFO roles; the
checker reports stable, closed boolean keys for domains/resets, pointer and
Gray state, synchronizer inventory and bypass, flag equations, address slices,
lane writers, destination writers, payload bypass, and extra private state.

The checked-in RTLIL fixture and its one-change mutants validate the native
parser conservatively. They do not establish compatibility with a new Yosys
serialization. Only the pinned gate may establish that compatibility, and it
starts with an `incomplete` receipt, snapshots repository and bundle inputs,
logs every command, hashes inputs/results, and promotes the receipt only after
all three real outputs pass and the snapshots remain unchanged.

This evidence makes no RAM-inference, timing, placement/routing, metastability,
MTBF, or physical-CDC claim.
