# PRX100 matrix clock experiment

The fresh baseline matrix profile spends 3,932,160 of 5,055,195 cycles issuing
ordered FP32 operations. The selected sixteen-lane interleaved core already
accepts one product per lane per edge. This experiment raises its target clock
from 33 1/3 MHz to 40 MHz, preserving all MoonBit hardware, canonical IR,
first-party emitted RTL, arithmetic order, memory layout and integer inputs.
Vendor clock IP and supplemental target timing constraints are the intentional
physical changes.

The new clock is an explicit build option. Qualification requires fresh routed
setup, hold, pulse-width, CDC bus-skew and debug-clock checks. Existing digital
and arithmetic evidence may be reused only after exact input identity and
sealed inventory verification. A timing failure must remain recorded and must
not be programmed. The previous 30 ns target remains available.

Before accepting the candidate, run matched physical baseline and candidate
campaigns against the same complete-layer and cached-decode CPU references.
Include actual launch, polling, final readback and CPU checks in resident
end-to-end timings. Report initial upload and program switching separately.
Use the actual qualified clock period when converting counters; no change to
host polling, tolerance, tensor payload or sampling policy is part of this
experiment. Preserve all 199 integer inputs and previous sealed evidence.

The initial 40 MHz attempt, before correcting the FIFO constraints below,
missed setup by 2.053 ns after physical optimization and by 2.259 ns after
routing. A separate 37.5 MHz fallback build was also evaluated. Its exact
nominal period is 80/3 ns; Vivado reports the period rounded to 26.667 ns.
Counter timing must use the exact nominal period, while CAD clock checks use
the tool's reported resolution. Both build attempts remain retained.

A third attempt used a 28 ns clock (nominal 1 GHz / 28, recorded under the
rounded frequency key 35714286) and incremental implementation from the
qualified baseline's routed checkpoint. The actual clock generator is rebuilt;
only matching physical placement/routing may be reused. The checkpoint hash
and reuse report are retained, with all normal physical checks still required.
The vendor sequence follows [AMD's incremental implementation guide](https://docs.amd.com/r/2025.1-English/ug904-vivado-implementation/Using-Incremental-Implementation-in-Non-Project-Mode).
The uncorrected 37.5 MHz and 28 ns attempts were stopped after identifying the
constraint defect. Their logs and exact termination receipts remain retained.

The post-synthesis probe identifies a target-constraint defect: canonical
asynchronous FIFO payload paths were checked against the shortest related-clock
edge spacing (5 ns at 40 MHz, rather than the FIFO's synchronized publication).
The corrected target profile must derive its endpoints from the pinned bridge
IR and validate the synthesized structure before applying any exception.

For each of 34 Gray-pointer buses, require direct registered sources, two
ASYNC_REG stages, correct clocks and exact widths. The top Gray bit can share
the owning binary-pointer MSB after synthesis because their functions are
identical. Bound source-to-first-stage delay to 10 ns and bus skew to 5 ns;
keep first-to-second-stage timing intact. Bound the existing health-level
synchronizer's source-to-first-stage delay to 10 ns. Bound each of 17 FIFO
storage-clock-to-destination paths to 10 ns, while leaving destination read
address paths timed normally. These constraints do not apply to unrelated
clock-domain paths.

The FIFO publishes a registered Gray write pointer through two synchronizer
stages, then registers nonempty before a destination transfer can occur.
Even the fastest destination has at least two complete 10 ns cycles between
the first possible sampling of publication and the first payload consumption.
The 10 ns storage bound is inside that window. Backpressure preserves ownership
until a consumed slot returns through the synchronized read pointer. This is
the existing coordinated-reset FIFO contract, not a new CDC implementation.
Only the four asynchronous assertion pins of the reset-release synchronizer
may receive a reset exception; its shift chain and synchronous consumers stay
timed. Report coverage, routed delay/skew, normal setup/hold, and unresolved
CDC diagnostics separately. No clock-wide asynchronous-group exception is used.

This follows AMD's guidance on [bounded asynchronous paths](https://docs.amd.com/r/en-US/ug903-vivado-using-constraints/Constraining-Asynchronous-Signals)
and [individual CDC constraints](https://docs.amd.com/r/2021.2-English/ug949-vivado-design-methodology/Constraints-on-Individual-CDC-Paths).
These physical constraints do not prove analog metastability behavior.

The reusable scripts are `prx100-layer-cdc.mbtx` (derive guarded constraints),
`prx100-layer-cdc-build.mbtx` (reimplement a retained synthesized checkpoint),
and `prx100-layer-cdc-audit.mbtx` (independently inspect the routed checkpoint).
The ordinary target build also accepts `bounded-cdc` after its explicit clock
argument and applies the same constraints after reopening its synthesis
checkpoint. The measured campaign uses the checkpoint reimplementation path;
the composed single-invocation wrapper is checked but is not a separate fresh
physical experiment in this campaign. Every regenerated image requires its
own physical qualification.

Status: the 40.000 MHz candidate passed independent physical/digital qualification and the matched complete-layer/cached-decode CPU campaign. See [the measured report](evidence/prx100-layer-matrix2-20261023.md). The integer core and all 1,448 module inputs remain unchanged.
