# Direct8 inductive progress and useful Store reachability

The 11,718-edge completion obligation remains open. This slice decomposes its
first public transport progress component on the ordinary direct8×8/K16,
host4096/q3 device. It also executes the unchanged useful Store cover and
independently validates useful Store traffic in native trajectories. Native
execution is not a solver witness or a universal completion proof.

The implementation plan and remaining composition edges are in
[direct8 progress](../PHASE6_DIRECT8_PROGRESS.md). Previous full-bound positive
BMC timeout and successful Fence ordinal-retirement cover remain unchanged in
[the earlier direct8 evidence](phase6-direct8-fairness-20261016.md).

## Inputs and public conclusions

Commits `71052a6`, `4235783` and `0513cee` add independent native observers,
the typed unbounded transport task and its host reviewer. Frozen source
`42357837cb5cce8b9179d8d0422f01b94d1d9866` passes all19 focused native tests,
strict check, info, formatting, script tests, all six registered task-input
checks and the exact nineteen-comparator reuse audits for four bundles.

The new component selects the original request stability, serial ownership
and DUT response readiness conclusions, together with:

- R2 offer drain: a stalled public request accepts on the next rising PRE.
- H2 accepted-request drain: its matching response accepts by the second
  later rising PRE, not merely becoming available.
- Public service drain: from the first offer to matching ACK by the third
  later rising PRE. ACK at the age limit wins.
- Observer ownership and age-history correspondence. Ages saturate rather
  than wrap and continue counting after an offered but unaccepted response.

Exactly the original seven public premises remain: initial joint reset,
held producer packet, owned matching successful response, held response
payload, R2 request-ready opportunities, H2 response availability and C2
retirement-ready opportunities. Internal progress/readiness is not assumed.
Induction depth12 global steps is not a shortened completion BMC. Both base
and induction must pass before accepting an unbounded result.

The original DUT SV hash is
`118611a4f68b9e525f069104cf0e9230a60d1ae8c84f681d20fb7ed74fef52eb`;
canonical IR is
`12e94f78c7136ada755eed2f35c92af52d77aa75fa2f1398bab19872057ff3ae`.
All38 memories and8960 unknown initial storage bits, unknown read INIT,
full-width host addresses/payloads and exact comparator bodies remain. No
production debug port, abstract engine, cut or forced SRAM initialization.

## First transport induction

Task `phase6-flux-tile-direct8-q3-transport-progress-r2-h2-prove` returns
`TIMEOUT 8 218`, after601 wall seconds at its original600-second limit.
The base case passes global steps0–11 in49 engine seconds. Induction then
reports failures at `lc_mem34_read0_bounds` and `lc_mem37_read0_bounds`, the
original lane0/lane3 depth3 FIFO read addresses. The run times out while
exporting its induction VCD; the retained VCD is zero bytes, not a complete
counterexample. There is no typed result/receipt or accepted theorem, and
no demonstrated reachable DUT failure.

Independent model review confirms84 assertion cells (eight selected public
conclusions plus76 original automatic bounds), seven premises,38 memories,
unknown INIT/read INIT and exact search source copies. Clean source head,
status and protected volume inventories remain unchanged across the run.

## Assertion-only FIFO support

Commits `44e0dd1` and `25f9bd9` register the separate `-fifo-support` variant.
The failing two-bit pointers reset to0, hold on idle and wrap2→0 on transfer.
Access-conditional bounds alone permit an arbitrary induction-start pointer3
to stay idle throughout the earlier induction steps. The variant adds eight
range conclusions on the actual four FIFO read/write address registers,
including idle cycles; no premise is added and no bounds check is removed.

Actual address nodes come from original IR memory ports and emitter names,
with checked two-bit register, clock/reset and no-initialization identities.
Removing this assertion-only overlay recovers the original formal DUT
byte-for-byte. Production RTL, IR, names, harness, properties and original
seven premises remain byte-identical. The engine must prove92 total assertion
cells, including the76 original bounds and eight new range conclusions.

All four component tests, three reviewer tests and two launcher tests pass.
Strict native check, info and formatting pass with no added public API.
The additional pinned engine run is pending at this documentation checkpoint.

## Useful Store qualification

The original registered cover keeps its23,552-global-step horizon,
11,718-edge inclusive deadline,600-second limit and additional named public
four-packet producer premise. The sequence is LoadA8×16 at256, LoadB16×8
at512, MatMul8×8/K16 and Store8×8 at1024, all caller ID73. No initial SRAM
value or host response data is fixed by the producer premise.

Qualification requires256 distinct byte-read accept/ACK addresses,64 distinct
word-write accept/ACK addresses, three earlier successful completions and
the watched successful Store ordinal retirement. The host reviewer replays
the public bus independently, matching full tags, ownership, sizes, masks,
address ranges/alignment and each unique ACK before accepting a witness.
It does not trust only the harness's bitmap or cover wire.

Both real native slot trajectories satisfy these independent address/ACK
sets. High-address rejection, unknown-memory/reset preservation, inclusive
age3/age2 ACKs, stuck response consumption, duplicate addresses and high-bit
tag/address alias checks also pass.

The unchanged formal cover returns `TIMEOUT 8 161`, after601 wall seconds
at the original600-second limit. Last logged reachability check is global
step63 of23,552 at442 engine seconds. It produces no trace, result or receipt;
useful Store formal reachability remains open. Model review confirms all
eight premises,38 original memories/8960 unknown storage bits and unknown
read INIT. Standard SBY cover preparation removes assertions, including
automatic bounds, not premises; this run establishes no safety result.

Both completed runs have clean, unchanged frozen source heads/status and
byte-identical protected-volume inventories before/after. Fresh Docker
inventory is empty and exactly the eight original protected volumes remain.
No unrelated volume or VM is removed. Both attempts and their complete source,
tool/model, review and cleanup records are sealed in
`artifacts/phase6-direct8-progress-20261016-r1`, inventory SHA256
`51a25742a522101c52db10b9afb68dbe09317903971b3cca5a6283808f318c51`.
The archive is verified before relocation and again at the destination. Its
separate retained host reviewer is commit `0513cee`, SHA256
`908d56fa3433d613045e0bf656c40e53a0b0e7974b503833ff76887ea7ef97b8`.

## Remaining scope

Even an accepted transport component would establish only public offer-to-ACK
progress. Internal two-client grant/regrant, request snapshots/routed ACK,
loader and Store cursor progress, compute/capture/lease release, older-writer
dependency drain and queue/head/retirement ranks must still compose the
candidate T6/L1666/S898/M99 and final11718 deadline. Fetched publication needs
its own allowance. No existing small-profile theorem is silently promoted.
