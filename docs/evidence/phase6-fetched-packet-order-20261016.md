# Fetched packet to head ordering

All 119 assertions pass unbounded binary k-induction for the original fetched
1x1, K2, host1024, ring4, queue2 design under its five public peer premises.
This extends the accepted 104-property dependency conjunction with ordering
from reader packet acceptance through the four synchronous FIFO lanes into
the captured head, reservation and dispatch. Physical SRAM generation/value
provenance and the remaining Phase 6 gates are separate.

## Implementation sequence

1. Bind actual FIFO port addresses, enables, data and cell identifiers through
   the canonical graph and emitted name manifest. Add nonfeeding observers only;
   preserve the production graph and all original memory equations.
2. Track the oldest accepted packet with an independent two-entry ghost queue.
   Check live cell correspondence, synchronous ReadOld response correspondence,
   and captured head correspondence through reservation and dispatch. Reset
   discards ghost validity, not memory contents. Compare all 256 packet bits.
3. Retain all 104 accepted conclusions and the original five assumptions. Run
   targeted native regressions, then one pinned unbounded formal attempt in a
   confirmed non-overlapping validation VM window. Retain actual failures too.
4. Review the prepared model for the original ten unknown arrays, 640 unknown
   initialization bits, unchanged address widths and complete qualified Boolean
   helpers. Seal the exact submitted inputs, results and source identities.

## Packet history model

The observer uses two uninitialized 256-bit registers, a one-bit read pointer,
a one-bit write pointer and a two-bit occupancy. These match the original FIFO
address types exactly. Only control resets. An accepted reader packet fills the
next free ghost slot; a pop saves the previous oldest word before any same-edge
push updates that slot. Live original cells must equal the corresponding ghost
words. No unwritten cell or invalid read result is constrained.

An independent four-phase history follows pop, response capture, reservation
and dispatch. It checks the original synchronous read result during the response
phase and all four captured head lanes during both unreserved and reserved
phases. Constant cell references are formal observation taps inside the emitted
DUT; they do not add canonical memory ports, alter existing synchronous ports or
feed the production logic. Removing the observer restores the original binary
helper-qualified DUT text byte for byte.

The native 20-command regression additionally checks live FIFO cells, pointers,
occupancy, responses and captured heads after every edge across two reset
epochs, including malformed packets, failed generations and recovery.

## Reset at the response phase

The first 119-property candidate on clean `e4be3b2` passes basecase 0–19 but
fails induction on `lc_fp_capture_event`. Its observer incorrectly equates
capture with the response phase even when reset is asserted. Production
`queued_concurrent_dispatch` explicitly gates every dispatch state with reset
inactive. This is an incorrect observer conclusion, not a demonstrated
production ordering defect. The failed attempt is retained separately.

Its actual final status is `TIMEOUT 8 108`, child8, at the unchanged 600-second
deadline (601 wall seconds). The induction trace export is incomplete; it is
not a validated reachable counterexample. The sealed 28MiB archive
`artifacts/phase6-fetched-packet-order-20261016-r1` has inventory SHA256
`08ba7b8bdcdd3fe94731e1b99245fe7efa44510dfdf9aa0b279102367453c5f1`,
verified before and after relocation. Its prepared model matches all 119 labels,
five public assumptions, zero covers, ten unknown arrays with 640 storage bits,
unknown read INIT and twenty complete qualified helper pairs. No proof credit
is taken from this conjunction. A prelaunch invocation missing Docker context
was rejected before a solver ran and is recorded separately from the actual job.

The corrected equation is `capture == (!reset && response_phase)`; it checks
reset suppression rather than bypassing the assertion or constraining reset.
A targeted native regression interrupts a genuinely fetched response before
capture, observes capture become false, and verifies all 18 storage words and
all ten registered read outputs are unchanged across the reset edge, including
their unknown masks. The corrected targeted set passes four tests, including
the original 20-command trajectory and the byte-identical dependency baseline.

## Complete conjunction pass

On clean `6e1efb64278460fc37d0ca19c895f4e3201fb3f5`, actual pinned SBY returns
`PASS 0 162`, child0, in 95 wall seconds. Induction succeeds at 51 engine
seconds; basecase 0–19 passes at 65 seconds. The log records successful
k-induction and no traces. This is an unbounded theorem, not a 20-step BMC pass.

All 104 earlier conclusions remain checked jointly with the 15 new conclusions:
capacity, pointer correspondence, head phase, two live cell relations, ReadOld
response equality, captured packet equality, capture/pop events, reservation and
dispatch ordering, and four complete lane control/address correspondences.
Each packet comparison covers all 256 bits; duplicate caller IDs do not replace
the FIFO sequence. Full simultaneous pop/refill samples the old packet before
the replacement is written. Unknown unwritten cells and invalid read results
remain unconstrained.

The corrected SV differs from the failed candidate by exactly the capture/reset
assertion line. The SBY configuration, canonical observation IR and emitted name
manifest are identical. No premise, input, initialization or deadline changes.
Production nodes, domains, memory ports/policies and metadata remain unchanged,
as do all five earlier dependency artifacts. No public API or device ABI changes.

Prepared-model review matches every one of the 119 labels, exactly five original
public assumptions, zero covers, all ten arrays retaining 640 unknown initial
storage bits and unknown read INIT, and twenty complete qualified binary helper
pairs. Submitted source/config copies and full clean before/after Git identity
match. The original UInt13 fields/cursors, UInt64 address calculations, UInt32
request encoding, UInt34 end-exclusive aperture checks and modular UInt32
tickets are unchanged. FIFO addresses are their actual UInt1 type, not a
truncated larger address. This adds no four-state-equivalence claim.

Nineteen frozen focused native tests pass, including the per-edge 20-command
history and response-phase reset regression. Targeted native checking,
interfaces, formatting and the runner test pass. Collector/reviewer unit tests
also passed during implementation. No full Phase 6 matrix pass is claimed.

The sealed 27MiB accepted archive
`artifacts/phase6-fetched-packet-order-20261016-r2` has inventory SHA256
`63c34f872228c9b477d820c973e1e182ead59ae9cd3b42a9ba87e248675c4319`,
verified before and after relocation. Both attempts retain exact inputs,
prepared models, actual logs, results and source copies, without build caches
or copied regression archives.

| Retained input | SHA256 |
|---|---|
| `fetched-packet-order-full.sv` | `e368221a8a9f9b611907afff849a7cf5e20e8ee4d6222e795f9571e9122916dc` |
| `fetched-packet-order-full.sby` | `31ad891bbab0560db30582b9d293a7e3fdf9f5548154f8bd0ef99fa56510eead` |
| `proof-view.lcir` | `3bbf46f47312c8c6e9be390a4684df22db5db78d88ee2a659fcb35fed8f6e229` |
| `proof-view.names` | `54104b0f41568399f219b46b86d8eb79e83dec53eb38860acfc6bc436b3af5ae` |

Each job used a separately confirmed non-overlapping window, released after
owned cleanup and before host review/archival. Docker ps -a was empty after
each job, exactly eight protected PRX100 recovery volumes remain, and the VM
configuration is unchanged: AMD64 QEMU only.

## Remaining gates

Packet-to-head ordering now composes with intended-generation/dependency
control for this exact fetched profile. Physical captured SRAM generation/value
composition, explicit-fairness 8x8 completion, typed safety receipt integration
and the final same-snapshot matrix/aggregate remain open. Older direct-q3 and
8x8 scopes are not promoted; the directed useful Store cover receipt is unchanged.
Phase 6 remains incomplete.
