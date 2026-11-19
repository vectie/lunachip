# PRX100 broader signed matrices and timing, 2026-10-16

The unchanged Array8/K16 image passes40 directed/seeded/repeated board cases,
checking1,955 signed INT32 outputs through8,222 UART exchanges. A separate
synthetic1x1024 by1024x8 projection passes64 FPGA tiles,512 partial outputs
and eight final host sums through6,275 exchanges. Across the successful runs,
all14,497 exchanges pass envelope, CRC, sequence, status and expected payload
checks; all416 ordered completions are fault-free. Result guards and per-row
padding remain intact. No portable hardware source or bitstream was changed.

## Coverage and state reuse

| Cases | Shapes and checks |
| --- | --- |
| Zero | Full8x8/K16, all64 outputs zero |
| Identity | 8x8/K8, output exactly equals B; padded strides |
| Signed extrema | Full8x8/K16:−128×−128→262144,127×127→258064,−128×127→−260096 in every output |
| Cancellation | Alternating−127/+127 with127, full8x8/K16, all outputs zero |
| Boundaries | 1x1/K1,1x8/K16,8x1/K16,8x8/K1 |
| Rectangles | 3x5/K5 and5x3/K7 |
| Seeded mixed signs | Eight deterministic shapes, reductions1..15, varied signed operands |
| Repetition | Twenty identical full8x8/K16 workloads, alternating slots |
| Long reduction | Synthetic1x1024 by1024x8,64 K16 tiles and checked host accumulation |

Each successful campaign performs one initial Reset and Configure. Subsequent
batches advance the absolute producer count by4, reusing the four physical
ring entries at verified quiescent boundaries. No between-case reset masks
state reuse. Slots0/1 alternate, and every used descriptor, operand and result
sentinel is initialized before publication. Each batch drains LoadA, LoadB,
MatMul and StoreC completions with unique IDs and exact acknowledged byte
counts. An early result read must return busy without consuming a completion.

Operands are contiguous or padded (A stride20, B stride12, C stride40).
Every result word, every C padding word and both adjacent guards are read
back. Status must be configured/quiescent with matching producer, consumer
and retired counts; all Diagnostics words must be zero; a final Completion
must be empty. The board is left quiescent after the last linear tile,
producer/consumer/retired256. References use ordinary host signed arithmetic,
independently of LunaWire/LunaWave. Fixed extrema/identity/cancellation have
additional closed-form checks in the driver's selftest.

The first campaign attempt passed the zero case, then exposed a host-driver
error: Configure was attempted again in case1. The board correctly returned
busy(status4); Configure is accepted only in the unconfigured state. The
driver was corrected to configure once and advance producer counts, then a
fresh campaign reset once and passed all40 cases. The exact failed attempt,
including its driver and refusal frame, is retained. No core fix or automatic
retry of an uncertain mutation was performed.

## Measured performance

The persistent socat session removes the former diagnostic's300ms EOF delay
per command. A request is16 bytes and a reply32 bytes, at115200baud8N1.
There is one outstanding request. Each round-trip interval starts immediately
before writing the request and ends after reading exactly32 reply bytes.
Host timestamps have1ms resolution and include the bridge, USB and guest OS
scheduling. They are epoch-clock measurements, not a high-resolution or
monotonic instrument measurement. All recorded differences are nonnegative.

| Measurement | Result |
| --- | --- |
| Full8x8/K16 repeated driver interval,20 runs | min1.408s, median1.482s, mean1.5048s, max1.662s |
| Same20 runs, sum of UART round trips per batch | min1.160s, median1.196s, mean1.19135s, max1.212s |
| Full8x8/K16 FPGA compute counter | 31 cycles at nominal50MHz =620ns |
| Full8x8/K16 result capture counter | 64 active capture cycles =1280ns |
| 1x8/K16 case | 1.049s driver interval;606ms UART round-trip sum;24 compute cycles =480ns |
| Whole40-case suite | 70.896s wall time;41.349s UART round-trip sum |
| Whole synthetic K1024 projection | 76.591s wall time;31.888s UART round-trip sum |

The per-case driver interval covers descriptor upload through final checks,
including descriptor-file I/O. It excludes fixture creation and the final
case transcript flush. Whole-suite wall time includes these per-case evidence
operations, but excludes initial setup, final receipt serialization and serial
process shutdown. These are measured verification-harness timings, not an
optimized inference-runtime benchmark. Exact phase intervals and every RTT
are retained for reanalysis.

The compute counter ends before output capture and excludes operand loading,
result storage, descriptor fetch and UART. Therefore620ns is not complete
MatMul command latency. Within that counter window,1024 MACs/620ns is about
1.65GMAC/s; this must not be reported as end-to-end throughput. The repeated
driver interval corresponds to about0.665 fully checked tiles/s, or680MAC/s.
The capture counter is active cycles, not a separate measured total latency.

The repeated full batch uses238 command/reply pairs. Their UART wire-time
floor is238×48×10/115200 =0.9917s; the measured mean RTT sum is1.19135s.
Thus the serial protocol explains most of the observed cost. Improving the
host harness further cannot remove this wire-time floor.

## Synthetic Qwen-width projection

The long-reduction experiment is an INT8 numerical building block, not a
model execution. For global reduction index k and output j:

```text
A[k] = (47*k +13) mod256 -128
B[k,j] = (83*(8*k+j) +231) mod256 -128
```

The FPGA computes64 distinct1x16 by16x8 products. The host accumulates their
INT32 results and compares against a direct1024-term CPU reference:
`[-19968,60416,9728,-16384,145920,-52224,-135680,141312]`.
All512 partials and all eight sums match. This proves the current K16 ABI can
compose a K1024 reduction with host accumulation. It does not validate model
weights, quantization/scales, nonlinear operators, KV cache, logits or tokens.
See the updated [Qwen feasibility and next steps](../PRX100_QWEN_FEASIBILITY.md).

## Reproduction, validation and retention

The [MoonBit host driver](../../scripts/prx100-matrix-suite.mbtx) has `run` and
`linear` modes. In the existing Ubuntu22.04 guest with its baseline Moon toolchain:

```text
moon run /work/prx100-matrix-suite.mbtx -- run /work/builds/prx100-matrix-suite-NEW
moon run /work/prx100-matrix-suite.mbtx -- linear /work/builds/prx100-matrix-suite-linear-NEW
```

Use fresh roots; do not run both modes concurrently on the serial device.
Both require the existing Array8 programming receipt and identify shape8x8/K16.
Bitstream hashes are checked before and after each campaign:
`3e575862fa4520ddbd23fab02e516d46560584715db1b6667152b4bbbc66f55b`.
The prior [programming/build ledger](prx100-array8-matrix-20261016.md) retains
the source-bound RTL, Vivado2025.2 build and DONE/CRC programming confirmation.
No new package, USB mapping or host/guest configuration change was required.

Warning-strict native checking, interface generation and formatting pass.
The full native suite passes1,094/1,094 with zero failures; its complete log
is retained with the campaign evidence. All207
production source/interface identities captured before this work remain
unchanged. Script selftests check request parity with the existing CLI, a
retained physical reply, rejection of a corrupted CRC and closed-form edge
oracles. No emitter or simulator semantics were modified.

`artifacts/prx100-broad-matrix-20261016` retains successful and failed physical
campaigns, exact as-run drivers, all raw frames packed in per-case binary
transcripts, complete serial logs, per-request timing/command metadata,
fixtures, descriptors, actual/reference results, counters, source/tool
identities and validation logs. Requests are16-byte records; replies32-byte
records, correlated by their sequence fields and `transactions.json` order.
An independent offline audit rechecks all104 cases'14,493 exchanges (plus four
setup exchanges checked by the driver), all2,467 physical result words and
eight final K1024 sums directly from captured frames and fixture operands.
Inventories and copies are byte-verified before sealing. Compiler caches and
older regression archives are not copied; all originals and protected recovery
volumes are preserved.

This is bounded workload/repetition coverage. Long-duration soak, power and
temperature measurement, injected-fault coverage, optimized application
throughput, Qwen inference and full Phase6/7 closure remain open.
