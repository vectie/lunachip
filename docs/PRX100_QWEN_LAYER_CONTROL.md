# PRX100 layer completion snapshots

This host-only experiment uses the qualified sixteen-row BF16/FP32 image
without changing any hardware source, integer input, bitstream, clock, program,
weight, tensor layout or CPU reference. The previous cached-decode campaign
saved 7.715 ms in the FPGA kernel but lost that gain to measured host control
and readback time. A fresh comparison must alternate both host policies in one
Vivado session on the same programmed board and resident tensors.

The optimized policy reuses the last physically validated program count while
exclusive logged control ownership proves no intervening write changes it.
Cold or invalidated counts use the original serial write/readback before START.
Polling retains its checked two-word read at address 8, 2 ms sleep, 600 s deadline
and fault checks. At DONE, one legal nine-word read at address 20 revalidates
the count and retrieves all counters. Status files use the actual final poll;
counter files use the actual counter read. Redundant warm count operations and
post-completion status readback are removed. Final reads, CPU checks and every
counter invariant remain inside the end-to-end timer.

The readable register map has a gap at write-only START (address 16). No read
may cross it. A proposed twelve-word poll was rejected in static review before
board execution; its source and modeled attempts are retained. Only the qualified
homogeneous queues remain. A reset clears the hardware count, so START rejects
a stale cached count after reset. Each cache hit must cite the latest real
matching count read without intervening count writes. Bulk writes must never
target CSRs. Independent CPU/model and physical audits remain required.

The source of captured files must be independently checked against the actual
control transaction and run policy. Physical scatter records must never claim
that a captured register snapshot was a separate bus transaction. Legacy runs
retain their original diagnostics and source reconstruction checks.

Use five alternating pairs for full four-token layer execution, one checked
three-token prefill, then five alternating pairs of cached position-3 decode.
Alternate which policy runs first in successive pairs. Return only final
hidden states during resident samples; retain full stage/KV checks and input
integrity before/after outside the timer. Preserve every result, pair, outlier,
failed attempt and tool/source identity. No claim of reduced decode latency is
allowed unless the fresh measurements support it.

Before board execution, require deterministic host emission, modeled vendor
transaction regressions including negative responses/counts/faults/counters,
and exact bit/source qualification inherited from the sealed physical image.
At completion, independently audit all numerical payloads, transaction coverage,
captured snapshots, counters, sample windows and end-to-end timing. This remains
one complete fixed Qwen3-0.6B layer 0 at context four, not full-model inference.

The host path passes physical and numerical qualification.

| Median resident end-to-end, five alternating pairs | Legacy host path | Completion snapshot | Reduction |
|---|---:|---:|---:|
| Complete four-token layer | 530.920 ms | 517.736 ms | 2.48% |
| Cached position-3 decode | 148.310 ms | 138.997 ms | 6.28% |

A fresh same-session comparison alternates the legacy and optimized host paths on the exact same sixteen-row BF16/FP32 image. Five pairs per workload, with order reversed each pair, measure full-layer end-to-end latency **530.920 → 517.736 ms** (2.48% lower) and cached position-3 decode **148.310 → 138.997 ms** (6.28% lower). Warm launches reuse the latest physically validated count under exclusive logged control ownership. The checked two-word DONE poll supplies status and a legal nine-word read revalidates count and captures counters; redundant count/status round trips are removed. Final DDR readback, file writes and CPU comparisons stay in the timer. All 448,448 FP32 words across 317 tensors pass CPU tolerance and match the ordered model; all 54,272 actual checker words are independently rechecked. All 1,284 strict native tests pass. Both complete 1,432-input source cohorts, all 199 integer inputs, FP hardware, programs, clocks and bitstream remain unchanged. Five altered auditor inputs are rejected. Existing physical/digital/formal gates are inherited by exact identity and complete sealed-parent verification. [Measured evidence](../artifacts/prx100-layer-control-20261022/report.md) retains every pair and failure. This remains one fixed layer 0/context four and cached decode; full-model inference and Phase 7/8 closure remain open.


Reproduction: `scripts/prx100-layer-control-board.mbtx` is the paired runner; `prx100-layer-completion-io.mbtx` emits the host backend; `prx100-layer-completion-test.mbtx` checks modeled vendor operations. Run `prx100-layer-resident-audit.mbtx`, its completion-attribution helper and `prx100-layer-control-audit.mbtx` against the complete raw campaign and pinned fixture. The recorded drivers retain exact tool/source pins, native validation, physical invocations, collection, negative calibration, publication and mirror procedures. Use fresh output paths and keep sealed archives immutable.
