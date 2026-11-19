# PRX100 resident complete BF16/FP32 layer — 2026-10-19

Final-output-only resident execution passes on the PRX100. Intermediate
tensors stay in DDR3 and KV stays in on-board scratch memory. The integer
core, floating-point hardware, descriptor programs, bitstream and clocks are
unchanged. This is an execution-policy improvement, not a compute speedup.

| Measurement | Result |
| --- | ---: |
| Four-token resident end-to-end median, five runs | **1.094324 s** |
| Previous full-diagnostic warm median, three runs | 6.054825 s |
| Reduction relative to that diagnostic harness | **81.93%, 5.53×** |
| Four-token FPGA kernel median | 0.926146 s |
| Three-token resident prefill, one observation | 0.860391 s |
| Cached position-3 resident decode median, five runs | **0.379963 s** |
| Cached-decode FPGA kernel median | 0.232839 s |
| Fresh scalar native release CPU, four-token compute | **90 ms** |

Four-token samples: `[1.085328,1.101128,1.089072,1.094324,1.118026]` seconds.
Cached-decode samples: `[0.396361,0.374292,0.381846,0.378806,0.379963]` seconds.
The repeated decode launches use the same token at position 3 and overwrite
its KV entry; they are not five successive generated tokens. These are small
fixed-workload samples, not confidence intervals or full-model throughput.

Resident end-to-end starts before program-count write/read and START, and ends
after status/error/counter validation, actual final-hidden-state readback and
CPU comparison. Every timed launch reads only 1024 final FP32 words per token,
plus completion status and counters. The four-token result payload falls from
131,392 stage/KV words to 4,096 final words: **525,568 → 16,384 bytes**.
The median full run's actual components are 0.976894 s launch/poll/counters,
0.057823 s final readback and 0.059155 s CPU checking; its 0.926146 s FPGA
kernel is included in launch/poll time. Diagnostics outside those samples
still validate every operator and KV entry.

Programs are installed and physically reread before their resident series.
Separately measured prefill program setup is **0.512226 s** and decode setup
is **0.181809 s**; add the relevant setup when switching programs. One-time
weight upload is **80.647311 s**. Complete physical input-integrity reads take
**95.458100 s before** and **97.152354 s after**. Programming/tool startup,
initial full-program setup, deliberate poison writes and three full diagnostic
snapshots are also outside resident samples. No cold-start total or unchanged
verification boundary is claimed. The preceding 6.055-second baseline includes
per-run poisoning and all intermediate/KV readback; this comparison deliberately
changes that policy. Full-stage DDR stores inside the unchanged hardware still
occur, and the approximately 0.93-second compute limit remains.

All **28 final tensors / 28,672 FP32 words** across eleven resident launches
pass mathematical CPU tolerance `1e-4 + 1e-4*abs(reference)`. Maximum final
absolute error is **2.86102294921875e-6**. Three full diagnostic snapshots add
264 stage/KV arrays: before resident execution, after five full runs and after
prefill plus repeated cached decode. Across all **292 arrays / 422,848 words**,
maximum CPU error is 3.0517578125e-5, and every actual result bit equals the
separate ordered FP32 operation model. All 27 assets are physically reread
before and after; all three programs are read back byte-for-byte. Six expected
SLVERR guards, all twelve launches' descriptor/product/DDR counters and fresh
healthy/DONE/error-zero snapshots pass.

KV is poisoned before initial validation and once more before the resident
prefill. After that prefill starts, the physical transaction audit permits only
control accesses, decode-program publication/readback and final-output reads;
there is no host KV access or intermediate upload. All prefill K/V entries and
the final decode entry pass the post-decode full diagnostic snapshot. No CPU
operator intermediates are supplied to the FPGA.

The independent auditor reconstructs the actual vendor Tcl from the reviewed
MoonBit driver and inherited qualified connection/IO procedures, derives all
316 read jobs and every burst from the fixed fixture, accounts for every
transaction sequence, and checks the timed windows contain only controls,
status/counters and final outputs. A one-bit mutation of an actual final output
is rejected by its operation-model check. Tcl's printed binary64 maximum-error
summary allows last-digit decimal formatting variation; all actual raw FP32
CPU tolerance and bit-exact model checks remain strict.

The actual emitted campaign also passes an independent Tcl mock on Mac and
Linux. Before board use, that test caught a missing Tcl global for the timing
file; both failed and corrected test inputs are retained. During independent
audit development, a run label containing `-kv-` exposed ambiguous filename
parsing; the final auditor obtains reference identities directly from fixture-
derived job metadata. The board campaign itself completed once with exit 0,
PASS receipt and final healthy flags. One long-lived wrapper and one initial
test-transfer wrapper reported `ShellError.CommandFailed`; their cause was
not established. The retained physical exit/receipt were checked independently,
no FPGA campaign was rerun, and the Linux test was retried successfully.
Failed local test inputs/logs and the wrapper observation note
are retained; no earlier data was overwritten.

The guarded host status update completed, but its final wrapper text comparison
included an extra printed newline. A read-only recovery verified the exact
published and backup byte hashes without repeating the update; both receipts
and the original before/after status files are retained.

All three new host scripts pass native deny-warning and format checks. All
**1,411 Mac module inputs**, **1,411 actual Linux compiled-source inputs** and
**352 protected production/interface files** remain unchanged. The native
1,257-test phase, info/fmt/check, differential RTL, Yosys/formal and routed CAD
gates are inherited by exact source/DUT/bit identities, not rerun for these
host-only additions. Same bit SHA256
`5e33d7b091fb0e8fb985e1409c9dcfd0402be0a84a1c568c7a3ffb3ee748fe22`,
core 25 MHz, DDR UI 100 MHz, CPU_TAG/JTAG 10 MHz, queues 16; Vivado 2025.2,
xc7a100tfgg676-2, CPU_TAG ME10E06D1010A. Prior routed setup/hold qualification
remains +0.014/+0.059 ns with zero failing endpoints.

Fresh MoonBit native release CPU samples after the board campaign are
`[90,90,90]` ms, one traced warmup. All 108 common fixture binaries match the
qualified debug fixture. This scalar CPU measurement excludes model loading
and IO and is not BLAS; it remains about **10.3× faster than the FPGA kernel**.
Qwen/Qwen3-0.6B revision `c1899de289a04d12100db370d81485cdf75e47ca`, layer 0,
hidden 1024/intermediate 3072, 16 query/8 KV heads, dimension 128; token IDs
42/100/1000 prefill plus 42 at position 3. Context four, KV capacity eight.
All norms, projections, RoPE, causal attention/softmax, residuals and gated
SiLU feed-forward operations execute on the MoonBit-constructed hardware.

[Execution and reproduction contract](../PRX100_QWEN_LAYER_RESIDENT.md).
Unique raw physical readbacks, counters, timings, CPU timing, source identities,
host gates and negative test are retained in
`artifacts/prx100-layer-resident-20261019`, mirrored to
`/work/builds/prx100-layer-resident-full-20261019-a1/prx100-layer-resident-20261019`.
The adjacent transport receipt records the closed-inventory checksum verification.
Prior hardware, fixture and model archives are inherited by sealed identities;
compiler and CAD caches stay outside evidence. No user data is deleted. The
temporary hardware server is closed; volatile FPGA configuration and resident
weights/KV remain, flash and host OS are unchanged. This demonstrates **one
complete layer, not full-model text generation**.
