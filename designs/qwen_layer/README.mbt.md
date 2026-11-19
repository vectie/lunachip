# Qwen layer memory aperture

All layer-machine generators accept an explicit `MemoryAperture`. Existing
calls default to `MiB256`, retaining the PRX100 28-bit byte-address port and
256 MiB bounds. `GiB2` exposes a 32-bit byte-address port with the exclusive
capacity limit `0x80000000`.

```mbt check
///|
test {
  assert_eq(@qwen_layer.MemoryAperture::MiB256.address_width(), 28)
  assert_eq(@qwen_layer.MemoryAperture::GiB2.address_width(), 32)
  assert_eq(@qwen_layer.MemoryAperture::GiB2.capacity_bytes(), 2147483648UL)
}
```

The initial PBlaze3 composition uses the existing sixteen-row feedback design
with eight 32-bit response words per wide beat:

```mbt nocheck
///|
let layer = @qwen_layer.feedback_layer_machine(delivery=true, memory=GiB2)
```

The PBlaze3 512-bit inference image accepts sixteen 32-bit words per AXI
response. Its ordered matrix pipeline computes 32 row-major BF16 weight
products per issue edge when the output row count is divisible by 32.
Packed-16 descriptors retain their layout and sixteen-row issue width.
Both modes preserve the FP32 summation order within each row.

```mbt nocheck
///|
let layer = @qwen_layer.interleaved_layer_machine(
  memory=GiB2,
  pipelined_vectors=true,
  wide512=true,
)
```

The 64-row configuration accepts the same 512-bit input. Row-major
descriptors with row counts divisible by 64 use 64 lanes. Other supported
row counts use 32, 16 or scalar execution. Packed descriptors retain 16
lanes. With `rows64=true, banked64=true`, 64 dual-port memories hold both
64-by-64 BF16 stripes in 16 KiB. For row `r` and 32-bit weight pair `p`,
the bank is `(r + p) % 64` and the address within the stripe is `p`.

`export-inference-64-prefetch` accepts 32 words per compute edge. For
row-major matrices with a 512-byte aligned base and K divisible by 256,
each stripe covers 256 columns. Each read batch fetches sixteen 512-byte
rows. Both stripes occupy 64 KiB across 64 RAM banks. The higher pair
address bits select one of four 64-column segments within a stripe.
Packed descriptors, shorter K and bases aligned only to 128 bytes retain
64-column stripes. The next row group starts loading during the preceding
group's final compute interval.
A write across 16 consecutive pairs hits 16 distinct banks. An issue edge
reads one pair index from every bank, then rotates the halfwords back into
row order. The core keeps the same DDR burst sequence and FP32
accumulation order.

The memory aperture changes external address validation and request width.
It does not change arithmetic, scratch/program memory capacity, descriptor
encoding, matrix row order, or the DDR response protocol. Target adapters must
preserve all 32 address bits and independently check their request extent.

External matrix descriptors count BF16 bytes (`n * k * 2`); load/store vectors
count FP32 bytes (`n * 4`). Shape limits bound legal descriptor sizes. The
2 GiB profile adds the base and size in 33 bits and rejects an out-of-range
base or end before the first request. An extent ending exactly at
`0x80000000` is legal. Word addresses require four-byte alignment; external
weight matrices require 128-byte alignment. Batch request data retains bit 31
as the read-only batch flag and the row-byte stride in the remaining bits.

Tests exercise scalar load/store at the last legal words, high-address
scalar/parallel/overlapped matrix reads, packed sixteen-row prefetch ending at
the capacity boundary, backpressure, invalid extents, UInt32 wrapping inputs,
misalignment and unchanged default configuration. These are simulation tests;
DDR calibration, physical address-line wiring, memory aliasing and throughput
require the actual board.

The PBlaze3 `export-inference-64-load-lines` target coalesces 32 consecutive
FP32 words of a vector LOAD (opcode 14) into one 128-byte request when the
DDR address is 128-byte aligned and at least 32 words remain. Scalar requests
cover the prefix and tail. The core captures every response word on the
handshake and commits one word per clock through the scratch write port.
Each later LOAD fetches current DDR data. The DDR word counter still counts
logical words, and the weight packet counters count only matrix responses.

The PBlaze3 `export-inference-64-store-bursts` target also combines 64
contiguous FP32 STORE words (opcode 15) at a 256-byte DDR boundary. The core
streams the words from its synchronous scratch port and issues one two-beat
1024-bit INCR burst. A successful write response starts a second ordered
scratch pass for the FPGA argmax. Each group contributes 64 logical words.
Unaligned prefixes and short tails retain scalar writes.
