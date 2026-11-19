# PRX100 FPDDR1.3Q JTAG AXI queue contract

This target rebuilds the existing FPDDR1.3 physical shell with vendor JTAG AXI
`RD_TXN_QUEUE_LENGTH=16` and `WR_TXN_QUEUE_LENGTH=16`. These are the only changed
user component parameters. First-party canonical IR, SystemVerilog, integer
core, FP arithmetic/controller/bridge, DDR layout, MMIO version0x10003 and
50/100 MHz clocks remain unchanged. The reproducible build checks the pinned
Vivado executable/version, qualified MIG configuration and exact hardware inputs.
A fresh route must pass setup/hold, DRC, every core clock pin and all unfiltered
bus-skew constraints before programming.

[AMD PG174](https://docs.amd.com/api/khub/documents/LqQTk0RcZiVWPLA84Eji0A/content)
defines read/write transaction queue lengths1..16. The host uses
[`run_hw_axi -queue`](https://docs.amd.com/r/2020.2-English/ug835-vivado-tcl-commands/run_hw_axi)
for homogeneous DDR groups with at most16 transactions, each at most256 words
and never crossing4 KiB. Addresses advance in order. Transactions are reused by
operation/address/length; write DATA updates before each run. MMIO, calibration,
fault checks, configuration and polling remain serial, with individual responses.
The bulk helper rejects MMIO, misalignment, zero length, out-of-range/cross-end
and invalid-operation requests before creating transactions.

Queued groups transfer the weight and activation upload/readbacks and the
two-burst384-word result read for a48-job batch. Short/single-burst transfers
retain the serial path. No read/write dependency is placed within one group.
The existing converter/bridge applies normal AXI backpressure; the host waits
for each group before its dependent work.

Vivado exposes the group's final RRESP/BRESP through the AXI object. A raw
`GROUP_OKAY` tag records that final group observation; it does not assert
individual responses. Each transaction's DATA and length are retained, every
model input is checked before execution and again afterward, all outputs are
recomputed against an independent CPU reference, and guards/fault counters pass.
The independent group audit binds raw/result hashes and checks exact coverage,
capacity, addresses, burst boundaries and group timing. This evidence does not
establish independent error-status reporting for every queued transaction.

Before timing the real upload, both benchmark profiles write the bitwise
complement of every model input and read it back. Every actual model write must
then replace a verified poison value, and complete model readback precedes START.
The raw-memory CPU audit requires this order, two writes per model word, and
three readbacks per input word (poison, model before jobs, model after jobs).
Stale DDR contents therefore cannot hide a lost model write. Guard counts and
the pinned106-projection/848-output campaign remain exact.

`uploads.tsv` measures the actual22,528-byte upload and its complete readback.
`timings.tsv` retains the full per-batch timer from before configuration/cache
checks through every output/counter/error read and local checks. The new
`application-us.txt` starts after verified poisoning and includes actual upload,
both actual input readbacks,106 projections and final guards. `campaign-us.txt`
additionally includes poison and initial qualification. Startup/programming and
CPU reference preparation remain outside these timers. The new campaign includes
more validation than its predecessor; compare fresh profiles with the same work.

The baseline is the current30 MHz, one-entry target with reused transactions
and coalesced configuration. The queued target keeps30 MHz and changes the IP
depth and bulk batching. A same-new-bitstream serial control can separate shell
and host batching effects. Physical campaigns run with CAD idle and preserve all
observations, including host latency outliers. This selected eight-channel Qwen
projection is not full-model inference;82 µs FP arithmetic remains unchanged.

Reproduction uses `scripts/prx100-fpq-{build,route,review,board,audit,groups,metrics,close}.mbtx`.
Board syntax is `run BUILD JOBS QUALIFICATION NEW_ROOT 30000000 reuse|queue`;
the queued mode requires a bit/source-bound qualification with both queue depths16.
Each board root records its actual driver, Tcl, inputs, transactions, group/stage
timings, CPU checks and configuration identity. All evidence roots are fresh;
prior sealed archives remain immutable.

The subsequent [control/diagnostic batching profile](PRX100_JTAG_CONTROL_BATCHES.md)
uses this same qualified bitstream. It compares explicit MMIO queue groups
with coalesced status/error reads and unchanged-descriptor reuse; the latter
is selected after fresh interleaved board measurements. The `fpq` driver and
measurements above continue to describe the original queued-DDR profile.
