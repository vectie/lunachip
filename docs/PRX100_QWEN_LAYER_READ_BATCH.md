# PRX100 batched result and diagnostic reads

This host-only continuation keeps the qualified four-lane BF16/FP32 layer
image, integer core, descriptor programs and arithmetic unchanged. Core and
DDR UI clocks remain 25/100 MHz and CPU_TAG/JTAG remains 10 MHz. Hardware,
native-phase and formal qualification is inherited through exact source/DUT/
bitstream identities from the preceding contracts, not rerun for host changes.

`read_jobs` accepts at most 128 named jobs, only after a freshly observed
DONE/healthy/error-zero result. Each group holds at most sixteen ID-zero read
transactions. Every burst remains four-byte aligned, at most 256 words and
within one 4 KiB page. Original 4,096-word file chunk boundaries are preserved
when splitting bursts; queues can span chunks and tensor files. Result bursts,
addresses, lengths and order remain identical to the original physical reads.
Every returned DATA value is validated and converted to little-endian bytes
in the original output file. Nothing substitutes for an actual FPGA read.

The bounded 32-live-object read/write pool is retained. Same-length slots
update their address; changed-length slots are recreated because Vivado
retains DATA when validating CMD.LEN. The per-file cursor is separate from
the cursor used to distribute returned transactions. Independent mixed-file
tests cover this distinction, including the retained initial offset failure.

Completed diagnostics queue the existing eight counters with an additional
two-word status/error snapshot. This adds fourteen post-DONE status words over
the seven launches including smoke. All counter values and flags remain
checked. Initial identity/version/error reads become one four-word burst,
including one additional flags word; final status/error becomes one two-word
burst. START/count verification, polling, BUSY/SLVERR guards and poisoning
retain their behavior. Homogeneous-group status remains the final group
response, not an individual AXI status for each member.

`verify_stages` builds the same stage/KV file list, reads it through the queue
and applies the unchanged CPU comparison procedure to every file before the
next launch. No readback or comparison is omitted. Readback/CPU-check timing
still starts after counter validation and ends after the last CPU check.
Warm end-to-end includes poisoning, launch/poll/counters, computation and all
stage/KV reads/checks. Cold additionally includes upload and full input/program
rereads. The final input-integrity reread is separately timed. Tool startup,
programming and the additional final read-only health probe are excluded.

The fixed workload remains Qwen3-0.6B layer 0, revision
`c1899de289a04d12100db370d81485cdf75e47ca`, three-token prefill plus one cached
decode, context four and KV capacity eight. Each profile runs six layer
programs: cold, three warm full runs, prefill and decode. All 440 stage/KV
arrays and 656,960 FP32 words retain mathematical CPU tolerance
`1e-4 + 1e-4*abs(reference)` and bit-exact operation-model/cross-profile checks.
All 27 inputs are physically reread before and after; all programs, expected
errors and counters remain checked.

The ordinary group log records each physical command and its measured timing.
`scatter.tsv` records every queued transaction's sequence, slot, call, purpose,
file, address, file offset and length; `scatter-plans.tsv` records each job.
The independent scatter auditor derives all 454 jobs and their complete burst
coverage from the fixed fixture and raw counters. The comparison auditor
checks all actual result bytes and burst shapes/order, unchanged other bulk
traffic, unchanged verification/poisoning/upload/launch logic and all timer
boundaries. Its required-gain gate requires lower warm end-to-end and complete
result-readback medians; cold changes are reported without requiring a gain
from an unchanged upload path. Identical campaigns must fail the gain gate.

Reproduce with the pinned Ubuntu/Vivado/MoonBit environment and unchanged
qualified bitstream `5e33d7b091fb0e8fb985e1409c9dcfd0402be0a84a1c568c7a3ffb3ee748fe22`.
Recover the original per-file host scripts from the sealed
`artifacts/prx100-layer-jtag-20261019/source/scripts/`, run a fresh baseline,
then run the current scripts at the same clock/rate with a fresh directory.
Use `prx100-layer-io-test.mbtx`, native deny-warning/format checks on the seven
changed/new host scripts, and the data, physical, scatter and readbatch
comparison auditors. Existing native-module phase gates are inherited only
after the complete Mac and actual Linux source inventories match their
qualified snapshots. Keep caches outside sealed evidence. No data is deleted
and no flash programming is performed. This demonstrates one complete layer,
not full-model text generation.
