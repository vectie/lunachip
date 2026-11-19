# PRX100 FPDDR1.1 banked loading contract

FPDDR1.1 retains the FPDDR1.0 DDR layout, bridge, 50 MHz core /100 MHz UI,
JTAG burst transport, cache ownership, batch scheduling and fault/reset rules.
It adds a separate MoonBit floating-point constructor and target; existing
integer and floating-point profiles remain unchanged.

The new core accepts a shared ten-bit write address, one BF16 activation and
eight independent BF16 weights. A load commits one packed operand to each of
eight independent1024-word core banks on the same edge. Loads are accepted only
while idle and outside reset. START/load conflicts, invalid lengths, busy writes,
reset cancellation, arithmetic ordering and5*K+4 compute cycles retain the FP1.1
rules. The multiplier and accumulator pipelines are unchanged.

The target stores weights in eight512-word synchronous BRAM banks. Each cache
word holds two adjacent BF16 values. The channel-major DDR stream selects bank
`block[6:4]`, and `block[3:0]` plus the response beat select that bank's word.
The activation cache remains512 words. All nine caches use explicit one-edge
ReadOld/HoldLast reads. Registered address parity selects each BF16 half.

The packer reads all nine caches together for1024 addresses, then drains the
last registered word. This takes1025 packing cycles per projection, compared
with8193 in FPDDR1.0. Load is suppressed on reset or any fault; idle data outputs
are explicitly zero. The final bank write precedes START by one edge. There is
no cache replication or increase in operand capacity.

The MMIO magic remains0x46504433; version is0x00010001. All other offsets retain
their FPDDR1.0 meaning. The packed-core-word counter at0x58 counts logical words:
eight per accepted load edge,8192 per successful projection. The pack counter
at0x40 counts1025 cycles/job. DDR byte counts and transaction shapes are unchanged.

Qualification requires targeted banked-core tests, full native gates, explicit
checks that old source/interfaces and arithmetic sections remain unchanged,
coupled Qwen CPU/native comparison, actual emitted controller/core RTL replay,
pinned synthesis and bounded control/helper sensitivity gates, then routed
clock/CDC/DRC checks. Physical performance comparisons use the same pinned
three-vector Qwen block and identical old/new board campaigns after CAD is idle.
Hardware load, compute, DDR and host timing must be reported separately.
