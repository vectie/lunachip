# PRX100 FPDDR1.3 host-transfer contract

The separately qualified [FPDDR1.3Q queue target](PRX100_JTAG_AXI_QUEUES.md)
now provides depth16 and batched DDR transfers. This document retains the
one-entry profile used for the matched baseline and recovery.

`scripts/prx100-fpt-board.mbtx` runs the existing qualified FPDDR1.3 bitstream
with a selectable JTAG clock and `serial` or `reuse` host policy. This is a host
change: canonical core/controller/bridge RTL, arithmetic, DDR layout, 50/100 MHz
clocks, MMIO ABI, integer core and all existing profiles are unchanged.

The driver checks the pinned Vivado executable/version, source-bound digital
qualification, source files, bitstream hash, fixture hash, cable identity, FPGA
part/IDCODE, DONE and configuration CRC. It requests the JTAG rate before opening
the target and requires the reported rate to match. CPU_TAG ME10E06D1010A reports
30 MHz among its supported rates. The selected clock is a measured property of
this cable/board/session, not a general guarantee for other wiring.

`serial` retains one transaction object per access and separate configuration
writes. `reuse` keeps transaction objects keyed by operation, address and burst
length, updates write DATA before every reuse, and writes the three adjacent
length/job/vector configuration words in one ordered INCR burst. Every access
still runs individually and checks its actual AXI response. Read data, complete
operand readbacks before/after jobs, all guard words, rejected-command checks,
FP32 CPU references and all 34 counter/result words retain their checks.
Burst lengths remain at most 256 words and never cross a 4 KiB boundary.

The independent existing `prx100-fpo-audit.mbtx` reconstructs the model operands
from raw DDR writes and recomputes every output, then validates the complete
campaign and overlap counters. `prx100-fpt-metrics.mbtx` additionally checks
transaction/stage accounting and batch wall-time phase sums. Results must pass
the CPU audit before their timing can qualify.

Per-batch `timings.tsv` starts before configuration and cache-state checks and
ends after START, polling, all result reads, all counter reads, the final error
read and local value/counter checks. It excludes programming, Vivado startup,
precomputed CPU references and output-table logging after the checks.
`results.tsv` retains its older, narrower timers for compatibility; neither is
substituted for the new complete timer. `stages.tsv` separates object handling,
`run_hw_axi`, property fetch and transaction logging. `uploads.tsv` measures the
same 22,528-byte model payload and complete input readback. Full campaign wall
time includes uploads, input/guard checks and all 106 projections.

Comparisons use the same bitstream, jobs, payload, 34-word diagnostics, complete
readback and error checks, with a recorded interleaved run order. Single-job,
three-job and 48-job host times are reported separately. FPGA arithmetic time
remains 82 µs per full projection; host improvements do not establish faster
arithmetic or full-model inference.

An exploratory queued-upload attempt is retained separately. Although
[Vivado supports queued AXI transactions](https://docs.amd.com/r/2024.1-English/ug835-vivado-tcl-commands/run_hw_axi),
the existing JTAG AXI IP was generated with read/write transaction queue lengths
of one. Vivado rejects a 16-write group with Xicom 50-38. The published driver
uses individually checked accesses; enabling a larger hardware queue would
require a separately rebuilt and qualified target. No queued-transfer speedup
or individual response guarantee is inferred from that rejected attempt.

Example in the prepared Linux guest:

```text
moon run /work/prx100-fpt-board.mbtx -- run BUILD JOBS QUALIFICATION NEW_ROOT 30000000 reuse
moon run /work/prx100-fpo-audit.mbtx -- NEW_ROOT/jobs.json NEW_ROOT/transactions.tsv NEW_ROOT/results.tsv NEW_ROOT/audit.json
moon run /work/prx100-fpt-metrics.mbtx -- NEW_ROOT NEW_ROOT/metrics.json
moon run /work/prx100-fpt-close.mbtx -- NEW_ROOT
```

Use a fresh `/work/builds/prx100-fpt-board-...` root. The close helper identifies
and stops only that run's `hw_server`; volatile FPGA configuration remains.
