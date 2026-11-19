# PRX100 complete-layer JTAG host profile

This profile changes host automation around the qualified four-lane,
four-row-batched BF16/FP32 layer image. The integer core, floating-point
hardware, descriptor program, memory map, arithmetic order and FPGA clocks
remain unchanged. See [the hardware contract](PRX100_QWEN_LAYER_BATCH_DDR.md).

## Transfer ownership and actual data

`scripts/prx100-layer-io.mbtx` emits the vendor Tcl transport. A homogeneous
queue contains at most sixteen transactions, each at most 256 words, aligned
to four bytes and contained within one 4 KiB page. All use AXI ID zero.
Every queued command finishes before its transaction objects can be reused.

The pool has one slot per direction and queue position: at most 32 live bulk
objects. A same-length slot receives its new address and, for writes, its new
DATA property. A changed-length slot is deleted and recreated. Vivado checks
the retained DATA length when CMD.LEN shrinks, including on read objects;
changing CMD.LEN alone is therefore deliberately avoided. This behavior is
covered by the independent memory mock and the retained failed board attempt.
Control transactions retain their separate address/shape cache.

Reads always execute on the FPGA. A binary file read obtains each transaction's
actual DATA property, validates its exact hexadecimal length and alphabet,
packs its most-significant-word-first representation and reverses its bytes
into the original little-endian memory order. It does not substitute request
data, expected tensors, cached previous results or CPU intermediates. The list
read interface remains available for program/smoke checks. Upload conversion
uses fixed-width scanning of reversed bytes. Every write object's DATA echo
remains checked; every input is additionally read back in full before and
after execution. Per-group response evidence remains the final homogeneous
group status, rather than an individual status for every burst.

Existing group timings still partition preparation, `run_hw_axi` and finish.
`pool-activity.tsv` accounts for every created/reused slot, binary-read word,
status fetch, DATA fetch and decoding interval. `pool-summary.tsv` records the
total creations/reuses and live objects immediately before explicit cleanup.
Additional profile logging is included in application wall time.

## Clock profile

The physical image's routed debug hub and core both run at 25 MHz; DDR UI
runs at 100 MHz. The preceding host profile uses 6 MHz JTAG. The optional
10 MHz profile reaches the 2.5:1 debug-hub/JTAG ratio required by
[AMD UG908 2025.2](https://docs.amd.com/r/2025.2-English/ug908-vivado-programming-debugging/Debug-Cores-Clocking-Guidelines).
No FPGA clock or constraint changes. The driver checks cable-supported rates
before setting the requested rate, reads back the actual rate and records it.
This is specific to the qualified image and attached cable.

`scripts/prx100-layer-jtag-profile.mbtx` accepts only the exact preceding
qualification digest and bitstream, preserves every hardware qualification
field and adds explicit inheritance provenance for the 10 MHz host setting.
Its output requires a new physical campaign. Digital/formal/CAD results are
inherited by exact unchanged source/DUT/bit identities; they are not freshly
rerun by changing a host cable setting.

## Fixed workload and measurement boundary

The program remains Qwen3-0.6B layer 0 at revision
`c1899de289a04d12100db370d81485cdf75e47ca`: three-token prefill plus one
cached decode, tested context four, KV capacity eight. Each campaign runs
cold, three warm full programs, separate prefill and separate decode. All
27 assets, three programs, 440 stage/KV arrays and 656,960 FP32 words retain
their original checks. Mathematical CPU tolerance remains
`1e-4 + 1e-4 * abs(reference)`; the separate operation model and cross-profile
FPGA arrays must be bit-exact. Poisoning, expected bus errors, counters and
final healthy/idle/DONE/CRC checks remain mandatory.

Warm end-to-end time includes output/KV poisoning, hardware computation,
launch/poll/counters and all stage/KV readback with CPU comparisons. Cold time
also includes asset upload, full physical input reread and program upload/
reread. The final input integrity reread is timed separately. Configuration,
tool startup and fixture preparation are excluded. CPU release timing is
compute-only and has a different boundary. Hardware counter time remains
separate; host transport changes do not accelerate FP32 arithmetic.

## Reproduction

Use the existing Ubuntu/Vivado/MoonBit pins, CPU fixture and qualified
`5e33d7b091fb0e8fb985e1409c9dcfd0402be0a84a1c568c7a3ffb3ee748fe22`
bitstream from the preceding batched-DDR phase. Its report records the
complete build and physical timing recipe. Do not compile in a sealed archive.

1. Run `moon run scripts/prx100-layer-io-test.mbtx -- NEW_TEST_ROOT` and native
   deny-warning checks plus formatting checks on the changed `.mbtx` files.
2. Run the existing board driver at 6 MHz with the original scripts recovered
   from `artifacts/prx100-layer-batch-20261019/source/scripts/`. Use fresh
   output directories and close only that run's temporary hardware server.
3. Install the current board/IO scripts under their `/work/` names. Run the
   same fixture, bitstream and original 6 MHz qualification in a fresh board
   directory to isolate software changes.
4. Generate a fresh 10 MHz qualification with
   `moon run scripts/prx100-layer-jtag-profile.mbtx -- ORIGINAL_QUAL NEW_QUAL`.
   Run the current board driver with that qualification and another fresh
   directory. No flash operation is involved.
5. Audit each physical campaign with `prx100-layer-audit.mbtx` and
   `prx100-layer-evidence-audit.mbtx`, using the exact inherited fixture,
   operation model and qualified build. Compare profiles with
   `prx100-layer-jtag-audit.mbtx`. Its `observe` mode reports signed changes;
   `require` additionally requires lower cold, warm and full result-readback
   times. Identical campaigns must fail `require`.

The comparison auditor byte-compares all actual arrays, checks identical bulk
operations/addresses/burst shapes/payload lengths and compares the complete
workload Tcl after removing only the cable-support check, pool cleanup and
requested JTAG rate. All diagnostic operations and timer boundaries must
remain identical. Report all warm samples and single cold observations;
sequential campaigns do not establish confidence bounds or tail latency.
This remains one complete layer, not full-model text generation.
