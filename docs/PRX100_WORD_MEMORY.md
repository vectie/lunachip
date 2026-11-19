# PRX100 portable word-read interface

This implementation adds an opt-in `ring_concurrent_word_tile` generator and
selects it for the PRX100 DDR projection target, introduced at version `0x00010004`.
Target1.5 reuses this exact core with [DDR line staging](PRX100_DDR_STAGING.md);
the core's memory protocol and request counters remain unchanged.
The existing `ring_concurrent_tile` generator retains its byte-read protocol
and canonical identities. Earlier proofs and physical measurements continue to
describe that legacy variant; they do not qualify the new core.

The [portable transport contract](PHASE6_WORD_MEMORY.md) defines the new core.
The shared port remains byte addressed, globally tagged, and limited to one
outstanding acknowledged transaction. An aligned four-byte little-endian read
uses `bytes=4`, `mask=15`, `write=0`, `data=0`. A byte read uses `bytes=1`,
`mask=1`; its response is zero extended. Result writes remain aligned four-byte
writes. No burst crosses an operand row or its admitted address rectangle.

Each 32-byte descriptor now takes eight reads. The operand loader requests a
word only when its address is aligned and at least four columns remain in the
current row. Otherwise it requests one byte. It buffers the returned word and
commits its low byte as signed INT8 through the existing bank-ready channel.
Each accepted byte shifts the buffer by eight bits, advances the cursor and
increments completed bytes. Backpressure holds the buffer and coordinates.
Word transfer acceptance advances the memory tag once, not once per byte.

An owned failed word read commits none of that word. Previously committed
bytes remain the command's acknowledged progress. A malformed tag/status
retains the existing transport poison behavior. Reset clears the buffer lease
and requires the same joint external-transaction flush as the legacy core.

The target staging adapter accepts both read shapes, checks alignment and
bounds before enabling BRAM, and returns a held tagged word or selected byte.
Its separate collection port remains isolated from held core replies. DDR
staging, descriptor publication, arithmetic, result storage, ring encoding,
clock frequencies and the pinned Qwen workload retain their meanings.

Read-only registers `0xa0`, `0xa4`, `0xa8` and `0xac` count accepted core
reads, writes, byte reads and word reads respectively. START clears them;
they count staging handshakes rather than DDR transactions. The board auditor
checks each raw readback and job record against the expected tile count.

For the projection's four commands per tile, descriptor reads fall from128
bytes to32 words, and operand reads from144 bytes to36 words. Together with
eight unchanged result writes, that is280→76 memory transactions per tile
(72.86% fewer). This is a transaction-count calculation; physical latency
and performance are now verified by the [physical campaign](evidence/prx100-word-20261017.md):
fresh target1.3→1.4 median1.12710→0.53526ms,52.51% lower (2.11× faster).
All20 jobs per image match the CPU reference. Hardware counters verify4352
word reads, zero byte reads and512 writes per full projection. Scalar CPU183µs
remains faster. Setup/hold are+0.125/+0.047ns;1176 native tests and both3947-cycle
RTL replays pass. Bounded local formal checks pass; unbounded closure is open.

Validation includes the unchanged legacy identity check, signed matrices at
all four address alignments and row tails, fault/reset tests, held word/byte
responses and malformed target access tests. Independent replay compares the
new core's complete output boundary with LunaWave. Local loader properties
use its exact production functions with explicit free command, memory,
poison and bank-ready inputs; they do not establish a queue or device theorem.
