# PRX100 four-lane complete Qwen3 layer — 2026-10-18

The complete BF16/FP32 Qwen3-0.6B layer now uses four output-row lanes and
three-stage FP32 multipliers in MoonBit hardware. A fresh physical comparison
on PRX100 gives **4.437× faster kernel execution** and **2.208× faster warm
end-to-end execution**. All 656,960 readback words are bit-identical to the
scalar FPGA baseline and the separate operation model. They also pass the
unchanged independent CPU reference tolerance. The integer core is unchanged.

The optimized scalar CPU reference takes **93 ms** for this four-token layer.
The earlier 2.750 s CPU figure was a native **debug** build; a fresh debug run
takes 2.751 s. Use the release result as the CPU performance baseline. This
FPGA implementation improves its earlier FPGA design substantially; it remains
slower than the CPU.

## Workload and construction

This is the same layer0 and checkpoint revision
`c1899de289a04d12100db370d81485cdf75e47ca` as the
[scalar experiment](prx100-layer-20261018.md): hidden1024, intermediate3072,
16 query heads, eight KV heads, head dimension128, RMS epsilon1e-6 and
RoPE theta1000000. Three embedding inputs (token IDs42,100,1000) form the
causal prefill; token42 at position3 performs cached decode. Context capacity
is eight; tested context is four. This does not establish full-model generation.

The FPGA still executes input RMSNorm, Q/K/V projections, Q/K head RMSNorm,
RoPE, causal grouped-query attention and stable softmax, output projection and
residual, post-attention RMSNorm, gate/up projections, SiLU gating, down
projection and the final residual. The host supplies weights, embeddings,
immutable RoPE coefficients and descriptors. It supplies no runtime CPU
normalization, attention or MLP intermediate to the device.

Weights remain BF16; activations, separately rounded products and ordered
accumulations remain FP32. Nonlinear approximations, numerical tolerance and
the 2,025-descriptor program are unchanged. The seven matrices occupy
31,457,280 bytes; all27 uploaded assets occupy31,485,952 bytes.

`designs/qwen_layer/parallel.mbt` implements four independent row accumulators,
with four packed weight-line BRAMs and a shared scratch activation read.
`parallel_multiply.mbt` constructs three registered stages: full24×24 product,
full-width normalization, then RNE packing. Each lane accepts one product per
edge and preserves its row's original k-order. There are no parallel partial
sums, changed reduction order, fused arithmetic or new quantization.

Each stripe loads four128-byte weight lines, issues64 products per lane,
drains the read/multiply/accumulate pipeline, and advances the k-chunk. Four
row results use the original single scratch write port. DDR staging remains
serialized. Opcode4 takes this path when n is divisible by four and input/
output spans are disjoint; other shapes and in-place spans use the scalar
path. All28 matrices in this workload qualify:62,914,560 of63,078,888 main
products are DDR matrix products (99.74%). This is a static workload profile,
not a measured per-state runtime breakdown.

All arithmetic, control and RAM behavior are constructed in LunaWire and
validated as canonical IR. The preserved physical RAM leaf modules are also
LunaWire-generated with synchronous ReadOld/HoldLast semantics. No numerical
RTL is handwritten. See the [implementation contract](../PRX100_QWEN_LAYER_PARALLEL.md).

## Fresh physical performance

Both profiles use the same board,25MHz core,100MHz DDR UI,6MHz CPU_TAG/JTAG,
host driver/decoder, assets, program, CPU arrays, poisoning and complete
diagnostic/KV readbacks. Campaigns are sequential, with three warm samples per
profile; this is not an interleaved statistical study.

| Measurement | Scalar FPGA | Four-lane FPGA | Speedup |
| --- | ---: | ---: | ---: |
| Four-token kernel, warm median |15.35820724 s|**3.46138364 s**|**4.437×**|
| Four-token warm end-to-end median |22.178887 s|**10.043216 s**|**2.208×**|
| Four-token cold end-to-end |278.633439 s|265.607355 s|1.049×|
| Three-token prefill kernel |11.51736240 s|2.59473620 s|4.439×|
| Cached-token decode kernel |3.84085520 s|0.86664788 s|4.432×|
| Three-token prefill application |17.370472 s|8.348289 s|2.081×|
| Cached-token decode application |5.829557 s|2.819669 s|2.067×|

Warm application samples are21.991634–22.198934 s for the scalar design
(22.178887,22.198934,21.991634) and9.982690–10.109005 s for the candidate
(9.982690,10.109005,10.043216). Every candidate sample is faster than every
baseline sample. Warm kernel latency falls77.462%; warm application falls54.717%.

Kernel time is the actual active-cycle counter divided by the qualified nominal
25MHz clock. It includes DDR staging, operators, instruction control and all
intermediate diagnostic stores. Warm application includes output/KV poisoning,
launch/polling/counters, every intermediate/KV readback and CPU comparison.
Cold additionally includes all asset/program uploads and full physical input/
program readback. Configuration/calibration, fixture preparation and Vivado
startup are outside these application intervals. These are diagnostic workload
times, with all20 stage tensors per token retained.

Candidate cold phases are117.129931 s upload,137.468329 s complete input
readback,1.011428 s program upload/readback,1.944832 s poisoning,3.577992 s
execution/completion/counters, and4.474715 s readback/CPU checking. The final
complete input-integrity readback takes another137.036618 s, outside run
intervals. The large cold transfer cost explains its smaller improvement.

| Candidate launch | Core cycles | Instructions | Main products | DDR responses |
| --- | ---: | ---: | ---: | ---: |
| Cold |86,534,687|2,024|63,078,888|31,594,560|
| Warm0 |86,534,544|2,024|63,078,888|31,594,560|
| Warm1 |86,534,642|2,024|63,078,888|31,594,560|
| Warm2 |86,534,591|2,024|63,078,888|31,594,560|
| Prefill |64,868,405|1,518|47,302,974|23,695,872|
| Decode |21,666,197|506|15,775,914|7,898,688|

Main products exclude nonlinear-unit internal multiplies. DDR responses include
store acknowledgments. The candidate records212 controls,6,717 bulk groups
and98,828 AXI transactions. Queue final response status is not represented as
individual status for every transaction; complete actual-byte checks establish
the payloads.

## CPU comparison and numerical checks

The native release CPU samples are **93,93,93 ms**; the traced four-token run
is103 ms. Fresh native debug samples are2751,2753,2750 ms. Release runs occur
after the FPGA campaign and collection finish, avoiding load on timed board
runs. Every one of108 asset/program/reference binary files is byte-identical
between CPU builds, including all80 mathematical CPU stage arrays.

CPU samples exclude asset loading/decoding and file/trace IO. The reference is
scalar MoonBit, not optimized BLAS. FPGA kernel time is37.22× this CPU release
compute time; warm diagnostic application is107.99×, with different boundaries.
No CPU acceleration or full-model inference performance is claimed.

Each physical profile executes four full programs plus separate prefill/decode:
six layer launches,20 token-layer executions,400 stage tensors and40 KV tensors.
All656,960 words pass `1e-4 + 1e-4*abs(reference)`, with maximum absolute error
**3.0517578125e-5**. Of these,266,180 words are bit-exact to the mathematical
CPU reference. The20,480 final hidden words have maximum error
**2.86102294921875e-6**.

Every word is additionally exact to the separate FP32 descriptor/arithmetic
model and byte-identical across FPGA profiles. Five CPU/program/emulator source
files are unchanged from the sealed scalar experiment. The fresh CPU fixture
has identical asset/stage hashes, tokens, descriptor bytes and tolerances.
All31,485,952 input bytes match both the initial and final physical readbacks;
all three program readbacks match. Six deliberately invalid/busy accesses
return the expected SLVERR. The final board is DONE/idle, healthy, error0 and
configuration CRC-error0. The task-owned hardware server is closed; the
validated volatile image remains configured and flash is unchanged.

## Qualification and retained failures

Vivado2025.2 qualifies `xc7a100tfgg676-2` on CPU_TAG `ME10E06D1010A`, FPGA ID
`13631093`. The corrected full build initially misses setup by0.216 ns; its
worst path is nonlinear instruction index `lc_n3458` to FP32 register `lc_n3462`.
Post-route AggressiveExplore and hold repair close the same RTL at25MHz:
setup **+0.013 ns**, hold **+0.052 ns**, zero failing setup/hold/pulse-width
endpoints, and no DRC Error/Critical Warning. All1,864 core flip-flop C pins
are checked at40ns. The13ps setup margin is tight. Warning advisories remain.

Final resources are **20,118 LUTs,9,649 registers,72.5 BRAM tiles and27 DSPs**
(31.73%,7.61%,53.70%,11.25% respectively). No RTL, arithmetic, clock or timing
constraint was weakened for the repair.

All **1,235 native tests pass**, including ten targeted core/controller tests.
The recorded Linux workspace runs `moon info`, `moon fmt`, strict native check
and strict native test with the pinned baseline SDK. Only its existing C
allocation-probe manifest has the documented GNU feature macro/libdl override;
repository hardware is unchanged by that environment adjustment. One active
native working cache is reused. New public scripts pass type checks.

The exact physical RTL passes102,804 LunaWave/Verilator cycles and2,261,688
output-word checks;835 raw uninitialized RAM outputs are ignored only while
their valid signal is zero. The multiplier passes100,000 native raw-bit product
checks and100,002-edge RTL replay, plus full generic Yosys synthesis. The whole
physical core/controller pass pinned Yosys0.68 coarse memory-preserving synthesis.
The independent FPGA audits bind15 source files, actual configuration and all441
Tcl comparison records to the bitstream and counter/wall-clock measurements.

A regression found that a delayed last-product token could escape a fault after
DDR health loss during drain. Completion/accumulation now require an active
compute state, healthy memory and no reset. The initial native failure, source
snapshot and unqualified initial CAD are retained; that image was never
programmed. The corrected native and RTL traces test health-loss drain/fault
stickiness and reset, alongside signed matrices, multiple stripes/row groups,
stalls, repeated starts, tails, in-place fallback, response errors and bad LAST.

Actual-core BMC48 passes eight control assertions with Bitwuzla, initial reset
only and all other inputs/unwritten RAM symbolic. Its1500 s attempt times out
at the last step; a2400 s retry passes with byte-identical DUT/assertions and
unchanged bound/assumptions. A slower Z3 alternative and an earlier rejected-
source run are deliberately stopped and retained without a proof/counterexample
claim. BMC48 reaches initial descriptor issue, not a complete four-line stripe;
it is not an arithmetic or full-layer liveness proof. Controller BMC32 and its
genuine negative counterexample are inherited only after exact DUT identity
against the prior sealed evidence. `formal-selection.json` records runner
provenance, including the actual timeout-adjusted executed runner.

The performance auditor also rejects a zero-speedup negative control after
checking all440 raw arrays. No precision, tolerance, reduction order, formal
assertion or data-readback check is relaxed for acceptance.

All352 protected production/interface files are byte-identical to the pre-task
inventory. All18 integer export files and16 prior floating-point projection
export files are unchanged. All16 new exports reproduce exactly after final
formatting. Pre-existing user work remains intact.

## Identities and reproduction

Qualified build: `/work/builds/prx100-layer-vivado-20261018-parallel-phys-a1`.
Actual candidate campaign: `/work/builds/prx100-layer-board-20261018-parallel-a1`.
Fresh baseline: `/work/builds/prx100-layer-board-20261018-parallel-baseline-a1`.

| Artifact | SHA-256 |
| --- | --- |
| Qualified `prx100_layer.bit` |`957f2cad10270443dde8abfdca2382a59b0d78d26fc67e52ada512f7c9da7aeb`|
| Input `SHA256SUMS` |`0c49f99350c5a8bd033306d8a84827e9c7b4b1e4119641d20b3bbe7f690647eb`|
| Physical `core.sv` |`2eb53e07618200ba1030901c38b83155f7497460b1dcb264ca07de3b9fb403ef`|
| Canonical core IR |`37aad2bfb7f56970825ad890d2a8388dc33dbeee8751070cda447b4a7b243fc6`|
| Candidate data audit |`4a6bfba2f353aea25ce21b5ee79f39c54bc943d7c856258d9bc02d73769f4732`|
| Performance comparison |`04dd32ea763ade0950afc63bffaf463ac3450f9a6e5c78ab255ac9ec86c68c3a`|

The sealed archive is `artifacts/prx100-layer-parallel-20261018`, mirrored to
`/work/builds/prx100-layer-parallel-full-20261018-a1/prx100-layer-parallel-20261018`.
It retains unique task source/IR/RTL, actual board data, reference inputs,
CPU debug/release identities, solver models/logs, CAD reports and all failed/
stopped attempts. Its `SHA256SUMS` and `SEAL` bind a closed inventory. Compiled
caches, Verilator objects and CAD checkpoints/projects are excluded. Prior
sealed archives remain immutable; inherited evidence is identified by seal.

Use `moon run --target native cmd/prx100_layer -- export-parallel NEW_ROOT`.
The same CLI provides `replay-parallel`, `pipeline-replay` and
`core-formal-parallel`. The archived corrected formal job/actual runner retain
the2400/3000 s budgets used for the accepted proof. The public build driver
generates the full25MHz design; `prx100-layer-parallel-route.mbtx` applies the
source-bound physical repair with strict timing/DRC gates. The original board,
data and configuration auditors remain enabled; `prx100-layer-parallel-audit.mbtx`
additionally verifies cross-profile bytes, conditions and measured gains.
Historical host status/recovery are preserved with a task-scoped integer-
unchanged flag. No full-model generation, optimized-BLAS, power or ASIC claim
is made by this experiment.
