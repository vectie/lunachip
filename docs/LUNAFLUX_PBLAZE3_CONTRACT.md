# LunaFlux / PBlaze3 integration

2026-10-29. Experimental software preparation; full-model device execution
and PCIe qualification remain open. The board's 2 GiB DDR aperture passed the
complete two-pattern physical test in `PBLAZE3_MEMTEST.md`.

LunaChip publishes a serialized device contract and the existing 16-word
Qwen layer ISA. LunaFlux owns the adapter, model tensor binding, memory/KV
placement, token scheduling, tokenizer and sampling. Neither project imports
the other's packages. The integration fixture crosses the boundary as JSON
and little-endian words. Simulator evidence does not promote a device backend
to production or establish full-model numerical agreement.

The first deployment target is Qwen3-0.6B, 28 layers, batch one, at most 2048
total prompt plus generated tokens. Matrix weights remain row-major BF16;
activations and KV are FP32. Small normalization weights may have FP32 copies.
The tied embedding/output matrix has one BF16 allocation. This is a separate
numerical profile from LunaFlux's BF16-activation/BF16-KV CUDA plan. Matrix
products and ordered sums round separately; reciprocal, rsqrt and exp use the
reference core's explicitly approximate algorithms. No FMA or BF16 round-back
equivalence is implied.

The exported contract identifies control ABI 1.1, 2 GiB DDR, 32768 FP32 scratch
words, 2048 descriptors per launch and the numerical profile. Each descriptor
contains 16 little-endian UInt32 words:

`opcode dst a b n k bs br ddr immediate flags reserved11..15`

Existing opcode meanings and decoder limits remain authoritative in
`designs/qwen_layer/decode.mbt` and `cmd/prx100_layer/program.mbt`. Opcode 0 is
HALT; 1 copy; 2 add; 3 multiply; 4 external BF16 GEMV; 5 scratch GEMV;
6 sum; 7 sum of squares; 8 maximum; 9 reciprocal; 10 rsqrt; 11 exp;
12 negative absolute value; 13 stable SiLU selection/product; 14 FP32 DDR load;
15 FP32 DDR store. Reserved words are zero. Maximum vector and reduction
dimensions are 4096. External GEMV K is a multiple of 64 and base alignment
is 128 bytes. Byte range arithmetic must not wrap at 2 GiB.

Each submitted program ends in HALT, leaving at most 2047 non-HALT operations.
Scratch survives consecutive launches. Host ownership excludes concurrent
scratch/program writes and DDR writes to live operands. A launch is complete
only for the expected accepted-START sequence, matching program length, healthy
DONE and no error; stale DONE cannot satisfy a new launch. Timeout or uncertain
submission poisons the owner until coordinated reset, rather than retrying START.

Implementation milestones:

1. Publish and strictly consume the contract; reject incompatible numerical
   profiles. Place all 310 source tensors and per-layer FP32 KV without aliasing.
2. Lower a deliberately bounded LunaTile FP32 subset to actual descriptors,
   preserving copy and operation order. Run its exported fixture through the
   existing LunaWave core/controller/AXI bench, including high DDR addresses.
3. Prepare full Qwen operation lowering: embedding BF16 expansion, per-head
   Q/K normalization, RoPE, streaming long-context attention, 28-layer recurrence,
   tiled output head and sampling. The current 4-token layer fixture cannot be
   enlarged by just increasing its context constant: its KV lives in scratch.
4. Validate full logits/tokens against an independent reference, then real
   board execution. PCIe, sustained throughput and serving remain separate gates.

The memory plan and bounded tile adapter are preparation milestones, not a
claim that item 3 or 4 is complete. All numerical, transport and hardware
limitations must remain visible in the LunaFlux adapter documentation.

## Software preparation result

The LunaFlux-owned packages are `device/lunachip`, `compiler/lunachip_tile`,
`model/qwen3_lunachip` and `integration/lunachip_qwen`. `cmd/pblaze3 contract`
publishes the device contract. UInt64 quantities in JSON use decimal strings;
UInt32 instruction words use JSON numbers. This distinction is exercised by
the cross-repository fixture rather than assumed by two independent unit tests.

The actual LunaFlux compiler output passed the existing LunaWave digital
composition on 2026-10-29: six descriptors; 1050 edges; eight AXI read beats;
four AXI write beats; four bit-exact FP32 values and two intact neighboring
words. DDR operands include the last 16 bytes of the 2 GiB aperture and an
output offset within an AXI beat. This is copy/add/multiply integration, not
Qwen inference. Full-model operation lowering and physical accelerator execution
remain open. The board currently contains the completed DDR BIST image; this
software work does not reprogram it.

The exact exported RTL/stimulus also passes strict lint and replay under
pinned Verilator 5.050; all 1050 clock-edge output rows match LunaWave byte for
byte. Canonical IR, emitted RTL, input/output traces and tool receipts are
retained. There is no RTL semantic change or new formal-property claim.

Evidence: `artifacts/lunaflux-pblaze3-adapter-20261029-a1`. The memory placement
uses the existing Qwen config and reserves 64 MiB each for workspace and spare
capacity, leaving 334.875 MiB beyond weights, normalization copies and FP32 KV.
LunaFlux's `docs/LUNACHIP_BACKEND.md` contains entry points and the remaining gates.

## Explicit BF16 GEMV integration

The 2026-10-29 follow-up adds a LunaFlux-owned `OrderedBf16Gemv` compiler
operation and Qwen row-tile preparation using the existing layout. It consumes
LunaTile views but does not reinterpret generic MMA: this target uses BF16
weights, FP32 activations, separate RNE products and increasing-K FP32 sums
from +0. The hardware remains the existing opcode-4 row-major path. There is
no native BF16 arithmetic core or new RTL semantics in this change.

The external adapter fixture now admits opcode 4 and a bounded longer wait for
matrix completion. Its two cases exercise the parallel 16×128 and scalar 3×64
paths with BF16 subnormals, infinities/NaNs, ordered cancellation and values
that distinguish FMA or BF16 activation rounding from the declared arithmetic.
Inputs reach the end of the 2 GiB DDR aperture; output begins within an AXI beat.
This software campaign does not reprogram the board or qualify PCIe inference.
Follow-up evidence: `artifacts/lunaflux-pblaze3-bf16-20261029-a1`.

This follow-up passed LunaWave and pinned Verilator 5.050: seven descriptors,
6779 edges, 472 AXI reads, 19 writes, all 19 FP32 results exact, and four intact
neighboring words. Every RTL output row matches LunaWave byte-for-byte.
The targeted cross-repository tests total 59. LunaFlux's focused implementation
review also fixed a generic CUDA `Maximum` reduction identity from `-FLT_MAX`
to `-INFINITY`, with a failing-before/passing-after source regression. That
CUDA correction has no new physical GPU qualification.

## Resident program chains on the 64-lane image

The `export-inference-64-chain` target adds token-level dispatch to the 40 MHz
inference image. Probe BAR offset `0x9c` for `0x43484e31` before selecting it.
Offsets below use the same AXI-Lite control base as the resident loader.

1. Place HALT-terminated segments consecutively in DDR. A descriptor occupies
   64 bytes. Each non-final segment contains 2,048 descriptors including HALT.
   The final segment contains 1–2,048. Keep each segment's scratch and KV
   operands valid through its successor.
2. Write the nonzero, 64-byte-aligned DDR address to `0x3c` and the total
   descriptor count (1–65,535, including every HALT) to `0x98`. The entire
   span must end at or below the exclusive 2 GiB boundary.
3. Write **2 once** to START at `0x10`. This advances the host sequence at
   `0x38` once. The scheduler stages, launches, and waits for each segment.
   It advances the DDR base by 131,072 bytes after each non-final HALT.
   Configuration remains locked until completion or fault.
4. Read the 16-word block at `0x200` with non-modifiable AXI attributes.
   The words are sequence, status, error, total descriptors, last PC, last
   state, last opcode, core cycles low/high, retired instructions, products,
   logical DDR words, loader cycles, sequence, completed segments, and
   START-to-DONE cycles. The sum of core and loader cycles plus one boundary
   edge per segment equals START-to-DONE for this workload. All counters
   except core cycles are 32-bit. Read results under exclusive ownership and
   check the surrounding sequence, healthy DONE, count and completed segments.
   A transport timeout or fault invalidates the launch owner.

START value 1 and the 14-word segment snapshot retain their existing semantics.

### Burst instruction staging (PBR1)

On the opt-in `export-inference-64-program-bursts` image, controller offset
0x240 reads 0x50425231. At idle, write 0 (default) to 0x244 for burst staging,
or 1 for the earlier scalar loader; other values or busy writes fail. CHN1
token launches and the program layout are unchanged. Check both capabilities
before benchmarking. Read/write these device registers with non-modifiable
AXI attributes. The loader does not accept a new segment before the active core
returns to idle.

Offsets 0x248, 0x24c and 0x250 count accepted scalar, 128-byte single-beat and
8-KiB grouped requests. Each group is sixteen 512-byte AXI INCRs of four beats
on the 1024-bit compute side. Offsets 0x254 and 0x258 count committed 32-bit
program words and accepted response packets, respectively. All five are
cumulative modulo 2^32; sample deltas outside the timer. Read the group and
beat counts separately: a held 128-byte beat writes 32 program words before
it is released. The response-state cycle counter includes this serialization.
Scalar edge reads can fetch a whole aligned bus beat but only stage the
requested word into RAM. Program layout and output precision are unchanged.

### Streaming unary operations and DDR residency (SFU1)

The `export-inference-64-stream-unary` target advertises `0x53465531` at offset `0x260`. The idle mode register at `0x264` selects streaming (0, reset default) or four-context execution (1). Opcodes 9 and 11 stream at lengths of at least 64 elements when the source and destination are identical or disjoint. Each element uses the existing ordered FP32 microprogram. A domain fault commits only the valid prefix. Partial overlaps follow scalar descriptor order. The host can select either schedule on the same image. PBR1 and CHN1 remain active.

Read 13 cumulative 32-bit counters at offsets `0x268` through `0x298` with non-modifiable AXI attributes. The first eleven count core states 4, 16, 5, 6, 7, 8, 17, 29, 30, 31 and 19 in that order. Their sum recovers the PFR1 `other` bucket for a completed inference. The last two count opcode 14 in the DDR request and response states. Subtract these from total scalar request and response counts to obtain the corresponding store cycles. Take deltas modulo 2³² around the trial.

Offset `0x29c` is an idle read/write residency latch. Configuration, core-controller reset and loss of DDR health clear it. The LunaFlux adapter reserves 64 bytes at DDR address `0x7fff0000` in the free tail of its diagnostic layout. The first 32 bytes hold a SHA-256 identity for the checkpoint payload, transfer layout and expanded-norm representation. The next 32 bytes identify the program layout and bytes. A new process checks the latch and both digests before reuse. A weight miss clears the latch and both records before uploading. A program-only miss invalidates the program digest before any writes to its range. The client publishes the digests after the corresponding transfers finish and checks the latch again. An external DDR writer must clear the latch before touching a protected region. Exclusive access is required across preparation and inference.


### Resident BF16 embedding lookup

The optional `export-inference-64-bf16-load` image exposes the read-only signature `0x42463136` at offset `0x2a0`. Read it with non-modifiable AXI attributes before selecting LOAD opcode 14 with descriptor word 10 set to 1. Descriptor word 8 then points to a four-byte aligned slot holding a little-endian DDR byte address. The element count must be a positive multiple of 64 within the destination scratch range. The device fetches the slot, checks 128-byte alignment and checks the entire `2 × count` span against the 2 GiB aperture before issuing a tensor read. Each 128-byte response contains 64 BF16 elements in ascending address order. Each scratch word is the raw BF16 payload shifted left by 16 bits. LOAD with flag zero retains its existing FP32 behavior.

LunaFlux selects this descriptor for the first layer with `PBLAZE3_BF16_INPUT=1`. For each input token it writes the tied embedding table address plus `2048 × token_id` to the slot. The checked JTAG command `E` verifies that four-byte write and the chain configuration before START. The original weight layout and checkpoint identity apply to both programs. Changing the descriptor changes the resident program digest.

With `PBLAZE3_TOKEN_QUEUE=1`, `PBLAZE3_BF16_INPUT=1` and `PBLAZE3_GREEDY_QUEUE=1`, the matching JTAG bridge accepts `G` with the same arguments as `E`. It returns the 64-byte chain completion and a four-byte little-endian greedy token. The bridge reads the device argmax and a trailing generation guard with the snapshot, checks successful completion for the expected generation, and rejects stale or out-of-vocabulary token values. The client validates the returned token before scheduling its next position. Each timed token uses one bridge command and one FPGA START. [Physical transcript](../artifacts/pblaze3-bf16-clock-target-20261115-a1/embed60-greedy/transport/transport.tsv) · [Full-logit validation](../artifacts/pblaze3-bf16-clock-target-20261115-a1/embed60-greedy/logits.sha256)
