# PRX100 JTAG control and diagnostic batches

This host-only experiment uses the qualified FPDDR1.3Q bitstream from
`prx100-fpq-vivado-20261018-hold-a2`. The integer core, floating-point core,
controller, bridge, target RTL and vendor IP are unchanged. The canonical
MoonBit hardware remains the source of the emitted RTL. No new synthesis or
place-and-route is needed for this change.

Two host strategies were measured on that same bitstream. The explicit-queue
candidate is `scripts/prx100-fpc-board.mbtx`; the selected compact driver is
`scripts/prx100-fpc-compact-board.mbtx`.

| Profile | Model transfers | Configuration and START | Completed-job reads |
| --- | --- | --- | --- |
| `queue` | Existing depth-16 DDR groups | Separate calls | Separate result, counter and error calls |
| `control` | Identical DDR groups | One ordered write group | One read group containing results, 34 counters and error |
| `compact` | Identical DDR groups | Reuse identical descriptors; publish changed descriptors before serial START | One status/error burst per poll; complete result and counter reads retained |

The compact driver also offers `queue` as its matched baseline. Both compact
and matched-baseline profiles publish the three initial DDR base registers
in one burst. The original candidate is retained because reducing the number
of `run_hw_axi` calls alone does not predict latency for tiny queues.

The compact profile combines adjacent status and error registers in a
two-word read at byte address 8. The error word follows status in the same
burst. A completed snapshot requires DONE=5 and error=0; the full counter
and output checks follow. Intermediate busy snapshots also require error=0.
No invalid or reserved address is added to a burst.

An identical K/job/vector descriptor can remain installed across repeated
STARTs. The driver writes all three words whenever the tuple changes. The
campaign has ten descriptor writes for sixteen STARTs, versus sixteen writes
in the matched baseline. Cold invalidation and changing batch size retain
the expected descriptor semantics. This assumes exclusive AXI target ownership
during the campaign. Independent raw audits reconstruct installed register
values and recompute every output from that state.

The cable is CPU_TAG `ME10E06D1010A` at 30 MHz. The driver checks the FPGA
identity, bitstream and source qualification, both runtime AXI queue depths
(16), and configuration DONE/CRC. The core and DDR interface remain at 50 MHz
and 100 MHz respectively. Programming is volatile; configuration flash is
untouched.

## Ordering and access boundary

The prelaunch cache-valid read remains a separate, checked transaction in
every profile. The remainder of this section describes the explicit-queue
candidate; the compact profile uses the coalescing rules above.
The launch group contains exactly a three-word write at byte address 32
(K, job count, vector count), followed by START=1 at byte address 16. Both
are writes through the same AXI master. All descriptors must be valid before
any transaction object is changed. Changing K, vector count and batch size
through the qualification campaign checks the resulting execution against
the CPU and exact job counters.

Polling remains serial and checks errors. Only after observing DONE=5 may
the diagnostic group read the output DDR range, the 34-word counter burst
at byte address 48, and the one-word error register at byte address 12.
These are stable completed-job reads; no read/write dependency is put into
a mixed-direction queue. Larger output ranges use two bursts. No group
exceeds 16 entries, no burst exceeds 256 words or crosses a 4 KiB boundary.

The generic DDR bulk function still rejects MMIO. A separate bounded
`control_group` validates the two permitted shapes and active phase before
creating objects. Negative controls exercise phase, direction, order,
descriptor and address rejection without issuing those invalid groups.

Vivado exposes the final group response. `GROUP_OKAY` in the raw log means
that observed final response; it does not establish each queued request's
individual AXI response. Full operand readbacks, every output, the complete
counter set and the error read provide independent content/behavior checks.
The group auditor verifies launch order and cache-read adjacency, and
requires an observed serial DONE immediately before each diagnostic group.

## Validation and timing

The fixed workload is Qwen3-0.6B layer-0 q_proj channels 0–7, K=1024, with
three normalized embedding vectors. It also checks K=1,2,3,16,1023 prefixes,
repeated full projections, warm batches of 1/18/48, and a final cold batch.
Each campaign runs 106 projections and checks 848 outputs against an
independent scalar reference using BF16 operands, separately rounded FP32
multiply and increasing-K FP32 accumulation. Complement poisoning precedes
the actual model upload; all actual operands are read before and after the
campaign. Scratch, guard, cache, error and exact counter checks are retained.

Resident wall time starts before configuration/cache checks and ends after
all result, counter and error validation. For the explicit-queue candidate,
the launch phase includes configuration publication and the results phase
includes the complete diagnostic group. For compact, the poll phase includes
error readback and unchanged descriptors need no configuration write. Compare
total wall times: individual phase boundaries differ. Every output and all 34
diagnostic words are checked in every profile. Compact removes redundant
descriptor writes and reads error alongside every status poll.
Application time additionally includes the actual 22,528-byte model upload,
both actual operand readbacks, all 106 projections and final guard checks.
Qualification time also includes poison and initial checks. Programming and
Vivado startup are excluded from these workload timings.

Raw transactions, group timing, per-batch timing, the CPU audit, group audit
and timing audit are retained. Queued raw/stage timing zeroes are placeholders;
`queues.tsv` contains their real group timings. Independent audits run on
Linux and macOS and must produce byte-identical receipts. Measured results
are recorded in `docs/evidence/prx100-fpc-20261018.md`.

This remains a selected projection experiment, not full Qwen model inference.

The subsequent [polling/diagnostic profile](PRX100_JTAG_POLLING.md) reuses the
validated cache word from each completed counter snapshot and tests bounded
post-START pacing, with full output/counter checks on this same bitstream.
