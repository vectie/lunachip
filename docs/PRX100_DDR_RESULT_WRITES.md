# PRX100 DDR result-write batching

Target 1.6 keeps the portable word-read core and the DDR result byte layout
unchanged. The target collects four adjacent signed INT32 results before
requesting one aligned 16-byte write. Each tile writes two partial-result
lines; the final eight sums use two further lines. A successful line ACK
accounts for four completed partial words. DONE follows the second final ACK.

The host portal retains aligned, masked 32-bit writes. Job requests carry four
explicit 32-bit words with `request_line=1`; reads still return four ordered
beats, while either write shape returns one held ACK with `response_last=1`.
Line addresses must be 16-byte aligned. The 64-bit asynchronous request FIFO
transports a line write as one header/data word followed by three data flits.
The fast domain gathers all four words before issuing the single MIG command
and full-mask data beat. Command and write-data acceptance remain independent.
Rejected lines are drained without issuing native writes. Reset clears both
FIFO endpoints together; calibration loss poisons subsequent work.

Register version is `0x00010006`. Register `0x68` counts accepted write
requests: `2*tiles+2` for a successful job. Register `0x34` still counts
acknowledged partial words, `8*tiles`. Operand staging remains nine line reads
and 36 words per tile. Activity windows may overlap.

Acceptance requires native edge/backpressure/fault/reset tests, independent RTL
replay, pinned synthesis and bounded formal checks, qualified routed timing,
and a fresh physical A/B campaign using the unchanged Qwen fixture and CPU
oracle. Physical qualification and the fresh A/B campaign pass; see [the evidence](evidence/prx100-results-20261017.md). Median0.48054→0.45618ms,5.07% lower;40 jobs match the CPU. The portable core retains exact source, IR, ordinary/normalized SV and names.
