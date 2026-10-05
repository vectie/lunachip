# Fetched ring control rejection and recovery design

This is a documentation-first implementation design, not executed evidence.
It closes the independent replay gap for runtime ring configuration and invalid
producer publication. The existing [ring contract](PHASE6_RING.md),
[fetched concurrent fault rules](PHASE6_RING_CONCURRENT.md), Device ABI 1.0 and
Phase 6 exit requirements remain unchanged.

## Fixed profile and reuse

Identity: `fetched-concurrent-1x1-k512-ring-control-recovery`. Use checked
capabilities rows1, columns1, reduction512, host4096, ring4, queue3. Reuse the
ordinary capability-driven fetched constructor, all 30 public taps, existing
trace/host/completion/bundle machinery and eleven-artifact replay protocol.
Add only one fixture constructor and explicit `export-ring-control` /
`audit-ring-control` CLI choices. Do not change hardware, adapter, runner,
descriptor0.2, ABI, host engine or receipt schema.

Reuse `HostKind.Concurrent` with fixture-specific initial memory. Request-ready
is zero when cycle modulo32 is zero, otherwise one; each accepted request gets
the existing delay1 response, matching saved global tag and success status.
Host memory is 165 everywhere except A1 bytes512..1023, all2; B1
bytes1280..1791, all3; scalar A0 byte32=2 and B0 byte64=3. Ring base3072 has
four physical 32-byte slots. Output words are2816 for long C1 and2800 for
recovered C0; all other bytes are sentinels until explicit descriptor install.

There are seven epochs, with an initial joint reset and six later joint resets.
Each reset flushes the host's pending/held obligations and tag epoch, not host
bytes or lifetime transaction totals. Physical SRAM may persist; logical slot
metadata must be invalidated. Use a total finite bound of32,768 post-initial-reset
edges. Fail incomplete obligations instead of truncating the workload.

## Five isolated configuration/publication epochs

| Epoch | Offered action | Exact outcome |
| --- | --- | --- |
| 1 | Configure base4097/origin17 | Alignment wins: ring fault1/address4097, configured0, producer=consumer=0 |
| 2 | Configure base4064/origin17 | Aligned end4192 exceeds4096: fault2/address4064, configured0, counters0 |
| 3 | Configure base`ffffffc0`/origin17 | Wide end`100000040`, not wrapped64: fault2/address`ffffffc0`, configured0, counters0 |
| 4 | Configure3072/origin17; publish17, then16 | Unchanged publication is legal; backward publication faults3/address0, configured1, counters17 |
| 5 | Configure3072/origin17; publish22 | Forward advance5 exceeds depth4: fault3/address0, configured1, counters17 |

Configuration acceptance and its following validation edge are different
events. Do not publish before actual configured status. Count the no-op
publication handshake separately; it must produce no fetch. All five epochs
have zero memory requests, ACKs, completions and compute activity, and no shared
transport poison. After each fault, drive configuration and publication offers
for eight active edges: fault/code/address/counters stay fixed, all those
handshakes remain closed, and no packet or completion is invented. Only then
jointly reset into the next epoch.

## Invalid publication on a genuine packet admission edge

Epoch6 configures3072/origin0. All packets have version0.2, zero reserved and
unused fields, and the following fixed command table:

| Position / ID | Command | Fields | Expected fault/progress/address |
| --- | --- | --- | --- |
| 0 /501 | LoadA1 | rows1, columns512, reduction0, base512, stride512; A1 | 0/512/0 |
| 1 /502 | LoadB1 | rows512, columns1, reduction0, base1280, stride1; B1 | 0/512/0 |
| 2 /503 | MatMul C1 | rows1, columns1, reduction512; A1/B1/C1 | 0/0/0 |
| 3 /504 | StoreC1 | rows1, columns1, reduction0, base2816, stride4; C1 | 0/4/0 |
| 4 /505 | Fence | All fields zero | Never fetched/admitted; no completion |
| 5 /506 | Fence | All fields zero | Never fetched/admitted; no completion |

Install0/1, publish2 and fully retire both loads. Require producer=consumer=2
and no pending/held host transaction before installing2..5 and publishing6.
Every physical slot is free by pre-edge consumer credit; do not overwrite a
published unresolved packet. Keep completion-ready high until the measured
hold below.

Track the saved successful ACK for descriptor3's final byte at3199. Before
the subsequent packet-admission edge, require producer6, consumer3,
publish-ready1 and actual `0 < active_cycles < 512`. Offer candidate8 on that
edge. Pre-edge occupancy3 leaves only one slot; advance2 must fault even though
that same edge independently admits the complete Store packet. Afterward
require producer still6, consumer exactly4, ring fault3/address0, configured1,
no transport poison and active cycles increased by exactly one.

The overlap predicate is an obligation, not an assumed cycle number. Fail
generation if it is never reached. There must be exactly128 descriptor read
requests/ACKs in this epoch, and no further descriptor read after the fault.
Do not prohibit all bus traffic: the admitted Store must still reach its real
data write and saved successful ACK. The already admitted MatMul/Store finish
normally; IDs505/506 never complete. No fault10/15 cancellation is permitted.

Require512 accepted Run advances, active512, elapsed513, stall0 and capture1
for the long MatMul. Derive its INT32 result using the independent oracle on
512 twos and threes:3072. Check the actual Store request's address2816, bytes4,
mask15 and data3072 before applying host effects, then its saved success ACK.
Hold ID503's visible completion for32 active edges before release; its complete
payload remains stable while admitted younger work may progress. Following
both retirements, observe eight quiet edges with sticky ring fault and no new
request/completion, then jointly reset.

## Reset invalidation and fresh recovery

Epoch7 configures3072/origin0 and publishes these first four commands:

| Position / ID | Command | Expected fault/progress/address |
| --- | --- | --- |
| 0 /601 | MatMul A1/B1→C1, rows1/columns1/K512 | 4/0/0: stale physical operands are logically unavailable |
| 1 /602 | StoreC1→2816, rows1/columns1/stride4 | 5/0/0: no usable result generation |
| 2 /603 | LoadA0 from32, rows1/columns1/stride1 | 0/1/0 |
| 3 /604 | LoadB0 from64, rows1/columns1/stride1 | 0/1/0 |

Drain all four, require producer=consumer=4 and an empty host obligation, then
safely refill positions4..6: MatMul A0/B0→C0 K1(ID605), StoreC0→2800/stride4
(ID606), Fence607. Expected fault/progress/address are0/0/0,0/4/0,0/0/0.
Unavailable commands perform no data DMA or compute issue. Recovery must have
one actual Run and capture, with counters1/1/2/0/1; its oracle result is6.
Compare all4096 final host bytes: long word3072 persists at2816, recovered6 is
at2800, both source regions and sentinels are untouched, and final ring slots
contain positions4,5,6,3 in physical order. Descriptor expectations come from
the host-authored packet table, not observed device data.

## Measured acceptance and stepwise validation

Expected finite totals are11 fetched/admitted/retired descriptors,352 descriptor
reads,1,026 operand reads, two word writes,1,380 request/ACK pairs,1,378 read
bytes and eight written bytes. Record observed accept/ACK classes separately;
all actual requests use sequential saved global tags within their reset epoch.
No fabricated record, response-edge ownership or live-bus ACK inference is
allowed. End with eight quiet active edges and no pending host obligation.

First commit this design, then implement focused fixture/check/stimulus files
and independent native tests; keep each below500 lines. Test deterministic
eleven-artifact generation, complete port identity, typed Equal and a real
valid observation mutation returning Mismatch. Preserve all110 artifacts from
the ten existing replay bundles byte/SHA-identically. Run the completed native
phase gate once, review generated public interfaces, and commit implementation
and CLI changes step by step. Freeze and export afterward; run unchanged pinned
lint/build/execute/typed audit, retain all actual failures/results, and commit
evidence separately. Agents may author separate source concurrently; compile
and tool engines remain serialized.

A pass covers this finite ring-control fault/recovery workload. It does not
prove universal publication correctness, internal ticket wrap, fairness,
full-device safety, synthesis equivalence, physical performance or Phase6
completion. Constructor parameter errors are not runtime ring commands.
