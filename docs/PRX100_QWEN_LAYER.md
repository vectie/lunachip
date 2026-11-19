# PRX100 Qwen3 layer experiment

Status: implemented and physically validated on 2026-10-18. Layer 0 completed
three-token prefill and a cached fourth-token decode on PRX100, including all
runtime normalization, attention and MLP operators. All 656,960 readback words
passed the CPU reference tolerance and exactly matched the separate FP32
operation model. Four-token kernel time is 15.355429 seconds; warm application
median is 22.156208 seconds. The scalar Linux CPU reference takes 2.750 seconds.
The integer core remains unchanged. See the [measured report](evidence/prx100-layer-20261018.md)
for precision, test scope, raw evidence and reproduction instructions.

Implement layer 0 of Qwen/Qwen3-0.6B at revision
`c1899de289a04d12100db370d81485cdf75e47ca`: hidden 1024, intermediate
3072, 16 query heads, 8 KV heads, head dimension 128, RMS epsilon 1e-6,
RoPE theta 1000000, causal grouped-query attention, SiLU gated MLP and both
residual additions. Scope follows the pinned configuration and the Qwen3
decoder-layer equations. Sampling and final-model logits are outside a single
transformer layer.

The layer uses checkpoint BF16 weights expanded to FP32, FP32 activations,
separate RNE FP32 products and ordered FP32 sums. It is a mixed BF16-weight /
FP32-activation experiment, not bit-identical emulation of a framework's BF16
activation rounding or fused BLAS reductions. The reference must report both
the arithmetic-contract comparison and errors against mathematical nonlinear
functions. No integer quantization is introduced.

New hardware lives in focused MoonBit packages. Existing integer and previous
floating-point designs remain unchanged. A bounded instruction sequencer owns
the complete layer schedule on FPGA. Linux supplies weights, input vectors,
immutable RoPE coefficients and instruction descriptors, launches a program,
and reads actual intermediate/final outputs; Linux must not calculate the
layer's runtime normalization, attention, softmax, SiLU or residuals for the
device.

The first workload is three layer-0 embedding inputs (tokens 42, 100, 1000)
processed causally, followed by a fourth input at position 3 that uses the
existing KV cache. Context capacity is bounded and explicit. One layer's
weights fit DDR3. Matrix/vector arithmetic is reused sequentially to favor
correctness and resource fit before parallelism.

Nonlinear implementation: FP32 reciprocal and reciprocal-square-root Newton
iterations from bit-pattern seeds; exponential uses range reduction, a
polynomial and repeated squaring. Domains, exceptional inputs, clipping and
numerical error limits must be specified and independently tested before the
layer is accepted. Bit-pattern seeds are initialization for floating-point
iterations, not fixed-point substitutes for floating-point arithmetic.

Validation gates: protected-source inventory and old integer export identity;
native arithmetic/operator/program tests; LunaWave / pinned Verilator
differential checks; pinned Yosys synthesis; bounded control/formal checks;
Vivado 2025.2 timing/resource qualification; actual PRX100 layer outputs versus
an independent CPU reference; repeated cold/warm timing including transfer,
execution and completion. Retain failed attempts and raw values. No passing
simulation or synthesis result substitutes for a physical board result.

Primary semantic references: [pinned model configuration](https://huggingface.co/Qwen/Qwen3-0.6B/raw/c1899de289a04d12100db370d81485cdf75e47ca/config.json)
and [Transformers Qwen3 implementation](https://github.com/huggingface/transformers/blob/v4.51.3/src/transformers/models/qwen3/modeling_qwen3.py).

## Implementation contract

`designs/qwen_layer` constructs the FP32 arithmetic, iterative nonlinear unit
and instruction machine in LunaWire. `targets/prx100_layer` constructs the
AXI control/portal controller. `cmd/prx100_layer` emits canonical IR, ordinary
SystemVerilog and the physical DDR/JTAG wrapper, and generates independent
CPU references and descriptor programs. The existing integer packages and
previous floating-point profiles are separate.

The complete program contains 2,025 descriptors, including HALT. Each of the
four tokens executes 506 descriptors. The prefill program is the first 1,518
descriptors followed by HALT; the decode program contains the final 506 plus
HALT. START resets execution control and counters while retaining scratch/KV.
Linux uploads raw assets and descriptor bytes; it does not supply intermediate
normalization, attention or MLP tensors to the device.

Storage is 32,768 instruction words, 32,768 FP32 scratch words and a 32-word
packed BF16 weight line. Scratch words 16,384–24,575 hold eight K vectors and
24,576–32,767 hold eight V vectors. Scratch reads use two explicitly scheduled
cycles: state4 reads A, state16 captures A and reads B, state5 operates on the
registered operands. Matrix products and sums round separately to FP32.

The physical memory adapter moves each canonical memory into a preserved
LunaWire-generated leaf module, with identical synchronous ReadOld/HoldLast
semantics. This permits BRAM inference before whole-datapath optimization.
Canonical IR and ordinary emission remain available. For Verilator, the same
physical text is split into correctly named module files; their concatenation
must equal CAD's `core.sv` byte for byte. No numerical RTL is handwritten and
no lint warning is suppressed for this packaging step.

## Instruction format

Every descriptor is sixteen little-endian UInt32 words:
`op,dst,a,b,n,k,bs,br,ddr,imm,flags,0,0,0,0,0`.
Scratch addresses and strides count words; DDR addresses count bytes.

| Opcode | Operation |
| --- | --- |
| 0 | HALT |
| 1–3 | Copy, FP32 add, FP32 multiply |
| 4 | BF16-weight DDR GEMV, FP32 activations/products/sums |
| 5 | Strided scratch FP32 GEMV |
| 6–8 | Sum, sum of squares, maximum |
| 9–11 | FP32 reciprocal, reciprocal square root, exponential |
| 12 | Negative absolute value |
| 13 | Stable SiLU numerator `x*(sign(x)?exp(-abs(x)):1)` |
| 14–15 | DDR FP32 load/store |

Flags select a B vector(0), broadcast B(1), or immediate FP32 B(2).
Descriptor validation checks opcode, reserved words, shapes, complete scratch
spans/strides and complete DDR spans/alignment before issuing requests.
Lengths are1–4096; DDR GEMV reduction lengths are multiples of64 and its
weight address is128-byte aligned. Invalid jobs enter a sticky fault until
reset. DDR response errors and malformed LAST terminate execution with fault.
The watchdog limit is15 billion active core cycles.

Reciprocal and reciprocal-square-root use four Newton iterations, accept
positive inputs in `[2^-64,2^64]`, and reject other inputs. Exponential uses an
eighth-degree polynomial after division by64, followed by six squarings on
`[-32,32]`; larger negative inputs return zero and larger positive inputs return
infinity. The layer uses stable softmax and stable SiLU with nonpositive exp
arguments. These are bounded numerical operators, with the predeclared full
layer comparison tolerance `1e-4 + 1e-4*abs(reference)` per value.

## AXI control contract

| Byte address | Meaning |
| --- | --- |
| 0 / 4 | Identity `0x514c5930` / version `0x00010000` |
| 8 / 12 | Flags `{fault,done,busy,healthy}` / error |
| 16 | Write1 to START |
| 20 | Descriptor count1–2048 |
| 24 / 28 / 32 | PC / state / opcode |
| 36 / 40 | Active execution cycles low / high |
| 44 / 48 / 52 | Completed non-HALT instructions / main products / DDR responses |
| `0x10000000..0x1fffffff` | DDR portal |
| `0x20000000..0x2001ffff` | Program portal |
| `0x30000000..0x3001ffff` | Scratch portal |

CSR diagnostics remain readable while busy. START, descriptor changes and
host program/scratch/DDR accesses require an idle, fault-free controller;
unsupported or busy accesses complete with SLVERR. CPU_TAG uses homogeneous
AXI queues of at most16 transactions, at most256 words per transaction and no
4KiB crossing. A queue's final response is not claimed as a response for every
individual transaction: complete input/program readback and actual output
checks provide the payload evidence.

## Measurement boundary

The hardware cycle counter includes DDR weight staging, all operators,
instruction control and intermediate diagnostic stores. Main product counts
exclude the nonlinear unit's internal arithmetic. The diagnostic program
stores twenty full-shaped tensors per token; these stores are included in
kernel time. It is a correctness-oriented layer benchmark.

The cold application interval includes all input uploads, complete input and
program readback, output/KV poisoning, launch/polling/counters, actual tensor
and KV readback and CPU checks. Warm intervals reuse weights/program and
include poisoning, execution/completion and all diagnostic readback/checks.
Vivado startup, bit programming/calibration and CPU fixture preparation are
reported outside these intervals. Native scalar CPU compute samples exclude
file IO and use library nonlinear functions rather than the FPGA polynomial
and Newton approximations. They are not an optimized BLAS baseline.

The JTAG rate must be selected from the actual routed debug-hub clock, with
the ratio required by [AMD UG908](https://docs.amd.com/r/2023.2-English/ug908-vivado-programming-debugging/Debug-Cores-Clocking-Guidelines).
The build checks actual core register clock periods, setup, hold and DRC;
requested clock settings alone do not qualify a bitstream.
