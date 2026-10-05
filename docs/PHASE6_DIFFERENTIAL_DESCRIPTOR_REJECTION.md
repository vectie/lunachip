# Fetched descriptor rejection replay design

This is the frozen implementation design. The separate
[RTL checkpoint](evidence/phase6-descriptor-rejection-20261006.md) records its
executed result; the design's predicted obligations are not proof receipts.
It closes named descriptor-rejection gaps in the current independent replay
matrix without modifying the hardware, Device ABI 1.0, descriptor encoding 0.2,
host engine, harness schema or tool runners. The normative requirements remain
in [PLAN.md](PLAN.md), [the ABI](PHASE6_DEVICE_ABI.md) and
[the queued dependency contract](PHASE6_QUEUED_CONCURRENT.md).

The retained [writer-fault replay](PHASE6_DIFFERENTIAL_WRITER_FAULT.md) checks
minor-version rejection, stride-zero reload rejection and failed generations.
The [fault/reset replay](PHASE6_DIFFERENTIAL_FAULT_RESET.md) checks reset-invalid
operands and actual reader poison. Neither establishes independent RTL coverage
of every reserved location, opcode aliases, raw dimension width, unused fields,
shape mismatches, alignment or wide preflight address overflow. This proposal
adds one finite fixture, not a general malformed-input or proof framework.

## Fixed profile and host layout

Use checked capabilities: rows 2, columns 2, maximum reduction 2, host_bytes 4096,
ring_depth 4, queue_depth 3. Construct the ordinary fetched concurrent device
through `ring_concurrent_from_capabilities`. Ring base 3072 and origin 0 remain
fixed throughout; there is one initial joint reset and no reset during work.
The array is elaborated as 2x2 so otherwise legal larger-shape probes can reach
exact-shape rejection. Every successful MatMul below is only 1x1/K1; no claim
of successful 2x2 arithmetic follows from this fixture.

Host memory starts at byte 165 everywhere except:

| Address | Initial byte | Meaning |
| --- | --- | --- |
| 512 | 2 | Original/recovery A0 scalar |
| 640 | 3 | B0 scalar |
| 768 | 5 | A1 scalar |
| 896 | 7 | Original/recovery B1 scalar |
| 1024 | 9 | Final replacement A0 scalar |
| 1536..1539 | 165 each | Repeated C0 destination |
| 1792..1795 | 165 each | Repeated C1 destination |
| 2048..2051 | 165 each | Final recovered C0 destination |
| 3072..3199 | Installed descriptors | Four 32-byte physical ring slots |

Only five operand byte addresses and three aligned output word addresses may
be used by actual data requests. Reuse the existing private `HostKind.WriterFault`
policy with this fixture's initial memory: request-ready is zero when
`cycle % 5 < 2`, otherwise one; accepted request ordinal t installs delay
`1 + t % 3`. All responses have the saved accepted global tag and fault 0.
The existing host owns stalled-payload checks, one outstanding obligation,
captured response identity and actual byte memory. Do not duplicate it or
reinterpret a rejection as a host-memory failure. Any unexpected data address
fails generation, including an address produced by premature UInt32 wrapping.

## Complete ordered descriptor table

There are exactly **86 descriptors**, positions 0..85. Caller ID is
`201 + position` (201..286), UInt32 little-endian. Canonical packets begin
`[0,2]`; reserved bytes/bits are zero unless the raw-mutation column says
otherwise. Canonical templates specify every field except ID:

| Template | Opcode | rows,columns,reduction | base,stride | A,B,C selectors |
| --- | --- | --- | --- | --- |
| A0 | LoadA=0 | 1,1,0 | 512,1 | 0,0,0 |
| B0 | LoadB=1 | 1,1,0 | 640,1 | 0,0,0 |
| X0 | MatMul=2 | 1,1,1 | 0,0 | 0,0,0 |
| S0 | StoreC=3 | 1,1,0 | 1536,4 | 0,0,0 |
| A1 | LoadA=0 | 1,1,0 | 768,1 | 1,0,0 |
| B1 | LoadB=1 | 1,1,0 | 896,1 | 0,1,0 |
| X1 | MatMul=2 | 1,1,1 | 0,0 | 1,1,1 |
| S1 | StoreC=3 | 1,1,0 | 1792,4 | 0,0,1 |
| R0 | LoadA=0 | 1,1,0 | 1024,1 | 0,0,0 |
| T0 | StoreC=3 | 1,1,0 | 2048,4 | 0,0,0 |
| F | Fence=4 | 0,0,0 | 0,0 | 0,0,0 |

Overrides below change canonical fields before encoding. `raw[i]=v` then
replaces byte i of the encoded packet; preserve those exact bytes in host
memory and never re-encode a decoded malformed packet. Raw high-dimension
replacement `rows=8192`, for example, means bytes 8/9 become `00 20`, not a
checked encoder call with that value. `f/p/a` is completion fault, committed
byte progress, and fault address. `R/W` counts operand-byte reads and result
word-write transactions only: **every row also requires 32 descriptor reads**.
All listed successful writes require a matching success ACK before terminal.
Generation notation `slot:S` / `slot:F` means latest writer becomes Success /
Failed; `-` means no writer intent, including all syntax faults.

| Pos | Template and canonical overrides | Raw mutation | f/p/a | Generation | R/W |
| --- | --- | --- | --- | --- | --- |
| 0 | A0 | - | 0/1/0 | A0:S | 1/0 |
| 1 | B0 | - | 0/1/0 | B0:S | 1/0 |
| 2 | X0 | - | 0/0/0 | C0:S | 0/0 |
| 3 | A1 | - | 0/1/0 | A1:S | 1/0 |
| 4 | B1 | - | 0/1/0 | B1:S | 1/0 |
| 5 | X1 | - | 0/0/0 | C1:S | 0/0 |
| 6 | A0 | version=[1,0]; raw[3]=1; opcode 255; raw rows 8192 | 12/0/0 | - | 0/0 |
| 7 | A0 | raw[3]=1; opcode 255; raw rows 8192 | 13/0/0 | - | 0/0 |
| 8 | A0 | raw[14]=1 | 13/0/0 | - | 0/0 |
| 9 | A0 | raw[15]=1 | 13/0/0 | - | 0/0 |
| 10 | A0 | raw[27]=1 | 13/0/0 | - | 0/0 |
| 11 | A0 | raw[28]=1 | 13/0/0 | - | 0/0 |
| 12 | A0 | raw[29]=1 | 13/0/0 | - | 0/0 |
| 13 | A0 | raw[30]=1 | 13/0/0 | - | 0/0 |
| 14 | A0 | raw[31]=1 | 13/0/0 | - | 0/0 |
| 15 | A0 | raw[24]=2 (upper A bit, low selector 0) | 13/0/0 | - | 0/0 |
| 16 | B1 | raw[25]=3 (upper B bit, low selector 1) | 13/0/0 | - | 0/0 |
| 17 | X1 | raw[26]=3 (upper C bit, low selector 1) | 13/0/0 | - | 0/0 |
| 18 | A0 | opcode 8; raw rows 8192 | 1/0/0 | - | 0/0 |
| 19 | B0 | opcode 9 | 1/0/0 | - | 0/0 |
| 20 | X0 | opcode 10 | 1/0/0 | - | 0/0 |
| 21 | S1 | opcode 11 | 1/0/0 | - | 0/0 |
| 22 | F | opcode 12 | 1/0/0 | - | 0/0 |
| 23 | A0 | raw rows 8192: bytes 8/9=00/20 | 14/0/0 | - | 0/0 |
| 24 | B1 | raw columns 8192: bytes 10/11=00/20 | 14/0/0 | - | 0/0 |
| 25 | X1 | raw reduction 8192: bytes 12/13=00/20 | 14/0/0 | - | 0/0 |
| 26 | S0 | - | 0/4/0 | - | 0/1 |
| 27 | S1 | - | 0/4/0 | - | 0/1 |
| 28 | X0 | - | 0/0/0 | C0:S | 0/0 |
| 29 | X1 | - | 0/0/0 | C1:S | 0/0 |
| 30 | S0 | - | 0/4/0 | - | 0/1 |
| 31 | S1 | - | 0/4/0 | - | 0/1 |
| 32 | A0; reduction=1 | - | 2/0/0 | A0:F | 0/0 |
| 33 | A0; B=1 | - | 2/0/0 | A0:F | 0/0 |
| 34 | A0; C=1 | - | 2/0/0 | A0:F | 0/0 |
| 35 | X0 | - | 4/0/0 | C0:F | 0/0 |
| 36 | S0 | - | 5/0/0 | - | 0/0 |
| 37 | B1; reduction=1 | - | 2/0/0 | B1:F | 0/0 |
| 38 | B1; A=1 | - | 2/0/0 | B1:F | 0/0 |
| 39 | B1; C=1 | - | 2/0/0 | B1:F | 0/0 |
| 40 | X1 | - | 4/0/0 | C1:F | 0/0 |
| 41 | S1 | - | 5/0/0 | - | 0/0 |
| 42 | A0 | - | 0/1/0 | A0:S | 1/0 |
| 43 | X0 | - | 0/0/0 | C0:S | 0/0 |
| 44 | X0; base=1, rows=0, reduction=0 | - | 2/0/0 | C0:F | 0/0 |
| 45 | X0; stride=1 | - | 2/0/0 | C0:F | 0/0 |
| 46 | S0 | - | 5/0/0 | - | 0/0 |
| 47 | B1 | - | 0/1/0 | B1:S | 1/0 |
| 48 | X1 | - | 0/0/0 | C1:S | 0/0 |
| 49 | S1; reduction=1 | - | 2/0/0 | - | 0/0 |
| 50 | S1; A=1, rows=0, base=4095, stride=0 | - | 2/0/0 | - | 0/0 |
| 51 | S1; B=1 | - | 2/0/0 | - | 0/0 |
| 52 | F; rows=1 | - | 2/0/0 | - | 0/0 |
| 53 | F; columns=1 | - | 2/0/0 | - | 0/0 |
| 54 | F; reduction=1 | - | 2/0/0 | - | 0/0 |
| 55 | F; base=1 | - | 2/0/0 | - | 0/0 |
| 56 | F; stride=1 | - | 2/0/0 | - | 0/0 |
| 57 | F; A=1 | - | 2/0/0 | - | 0/0 |
| 58 | F; B=1 | - | 2/0/0 | - | 0/0 |
| 59 | F; C=1 | - | 2/0/0 | - | 0/0 |
| 60 | X0 | - | 0/0/0 | C0:S | 0/0 |
| 61 | S0 | - | 0/4/0 | - | 0/1 |
| 62 | S1 | - | 0/4/0 | - | 0/1 |
| 63 | X0; rows=0 | - | 3/0/0 | C0:F | 0/0 |
| 64 | X0; rows=3 | - | 3/0/0 | C0:F | 0/0 |
| 65 | X0; columns=3 | - | 3/0/0 | C0:F | 0/0 |
| 66 | X0; reduction=3 | - | 3/0/0 | C0:F | 0/0 |
| 67 | X0; reduction=2 | - | 4/0/0 | C0:F | 0/0 |
| 68 | S0; base=4095, stride=0 | - | 5/0/0 | - | 0/0 |
| 69 | S1; rows=2, base=4095, stride=0 | - | 5/0/0 | - | 0/0 |
| 70 | X0 | - | 0/0/0 | C0:S | 0/0 |
| 71 | S0; base=4095, stride=3 | - | 6/0/0 | - | 0/0 |
| 72 | S0; stride=5 | - | 7/0/0 | - | 0/0 |
| 73 | S0; base=4095 | - | 7/0/0 | - | 0/0 |
| 74 | S0; base=4096 | - | 8/0/0 | - | 0/0 |
| 75 | S0; base=0xfffffffc | - | 8/0/0 | - | 0/0 |
| 76 | S0 | - | 0/4/0 | - | 0/1 |
| 77 | A0; rows=2, base=0xffffffff, stride=1 | - | 8/0/0 | A0:F | 0/0 |
| 78 | X0; rows=0 | - | 3/0/0 | C0:F | 0/0 |
| 79 | X0 | - | 4/0/0 | C0:F | 0/0 |
| 80 | S0; base=4095, stride=0 | - | 5/0/0 | - | 0/0 |
| 81 | S1 | - | 0/4/0 | - | 0/1 |
| 82 | R0 | - | 0/1/0 | A0:S | 1/0 |
| 83 | X0 | - | 0/0/0 | C0:S | 0/0 |
| 84 | T0 | - | 0/4/0 | - | 0/1 |
| 85 | F | - | 0/0/0 | - | 0/0 |

## Fault priority and generation obligations

Positions 6,7,18 demonstrate the competing syntax order 12 before 13 before 1
before 14; positions 23..25 isolate all three raw dimension words. Aliases 8..12
must be checked as full eight-bit opcodes, not their low three bits. All eight
ordinary reserved bytes and all three selector fields have isolated probes.
Selector upper bits are fault 13, whereas a legal low selector 1 in an unused
field is fault 2. This is finite location/branch coverage, not every bit/value
combination or every possible multiply-invalid packet.

Stores 26/27 prove syntax rejection preserved old C intent. MatMuls 28/29 and
stores 30/31 prove both A/B source generations survived the would-be writers.
Syntax-valid unused-field writers 32..34,37..39,44/45 must become Failed even
though actual SRAM contents remain from an older successful command. Their
consumers 35/40 and 36/41/46 must not fall back to those contents. Recovery 42/43
and 47/48 must perform real load, compute and capture; no reset clears the
generation history. Store 62 then proves unused Store/Fence rejections 49..59
preserved the recovered valid C1 intent. Each of the nineteen unused-field
positions is represented.

Positions 44 and 50 prove fault 2 precedes dimension and availability rejection.
Positions 63..66 distinguish representable but illegal M/N/K from syntax 14.
Position 78 checks fault 3 before a Failed A0 dependency. Position 67 uses legal
K2 with successful physical operands of K1, so fault 4 must arise from exact
shape rather than Empty/Failed summaries. Position 69 similarly uses legal
2x1 output dimensions with successful stored C1 shape 1x1: fault 5 precedes its
bad stride/address. Position 68 uses Failed C0 instead. Neither Store writes
an intended generation, and C1 remains usable at 81.

Position 71 has too-small stride, misalignment and an out-of-aperture word:
fault 6 wins. Position 72 isolates misaligned stride; 73 chooses fault 7 over 8.
Position 74 isolates aperture rejection. For 75 the wide exclusive word end is
`0xfffffffc + 4 = 0x100000000`; narrowing first would produce zero. For 77 the
two-row byte end is `0xffffffff + (2-1)*1 + 1 = 0x100000001`; narrowing first
would produce one. Both must fault 8 before any request. Load 77 publishes
Failed A0; 78..80 prove dimension priority and stale-operand/result exclusion.
The original unrelated C1 is stored successfully at 81. Fresh A0=9 at 82,
MatMul 83 and Store 84 establish recovery result 27 with B0=3.

## Safe publication and finite execution

Publish these **31 groups**, in order (inclusive endpoints):

```
0..2, 3..5, 6..9, 10..13, 14..17, 18..21, 22..25,
26..27, 28..29, 30..31, 32..35, 36, 37..40, 41,
42..43, 44..46, 47..48, 49..51, 52..55, 56..59, 60..62,
63..66, 67..69, 70, 71..74, 75, 76, 77..80, 81, 82..84, 85
```

Before installing each group, require every earlier command externally retired,
producer=consumer=the first position, and no pending/held host transaction.
Install each packet at `3072 + (position % 4)*32` only after this pre-edge
consumer credit proves the slot free. Offer the group's exclusive end as
publish_producer and hold it until acceptance. Every advance is at most four
and uses only pre-edge free capacity. Never claim same-edge freed-slot credit.
There are 30 refills after the initial group and no publication faults.
This intentionally drained schedule isolates rejection effects; it does not
claim new engine-overlap, capacity saturation or internal-ticket-wrap coverage.

Hold position 32's externally visible fault 2 completion for exactly 32 active
edges before acknowledging it. Check valid and ID/fault/progress/address both
before and after each edge, while continuing normal memory ticks. Descriptor
fetches are permitted during the hold; no payload transfer or compute is.
Do not require or claim a particular younger-fetch amount.

Require all 86 ordered completions and final producer=consumer=86, with no ring
fault or transport poison. After final retirement observe eight quiet active
edges with no completion, request or pending response. Bound generation at
65,536 post-reset edges and fail on incomplete obligations rather than shorten
the table. Actual total cycles, stall counts and hold discovery cycle must be
measured from the run and recorded; none is assigned by this design.

## Independent arithmetic, per-store and rejection checks

Use `matmul_int8_oracle` on the scalar source arrays to derive 6,35 and 27.
For every actual accepted word-write, validate destination, mask 15, bytes 4
and exact little-endian data before applying host memory effects. Validate its
success ACK from the saved accepted request, not later live bus outputs:

| Store positions | Word address | Oracle value | Write/ACK count |
| --- | --- | --- | --- |
| 26,30,61,76 | 1536 | 2*3 = 6 | 4 |
| 27,31,62,81 | 1792 | 5*7 = 35 | 4 |
| 84 | 2048 | 9*3 = 27 | 1 |

Repeated final values do not replace these per-write checks. Compare all 4096
final bytes to independent expected memory: scalar sources unchanged, exactly
three oracle words installed, final physical ring slots containing positions
84,85,82,83 in slot order 0,1,2,3, and every remaining sentinel byte unchanged.
Derive expected ring bytes from the table's host-authored packets and mutations,
never from observed device data.

Isolate rejection-only windows 6..25,32..41,44..46,49..59,63..69,71..75 and 77..80.
At each window start, earlier successful work must be terminal/drained. For
every edge until its last retirement, require no accepted operand read or word
write and unchanged complete compute-counter tuple, including resets-to-zero
that a mere positive-increment check would miss. Descriptor reads are allowed.
Record accepted and acknowledged classes separately; do not call the whole
bus idle. All local rejection completions have zero progress and zero address.

Observe nine real successful scalar Run advances and nine capture commits,
corresponding to MatMul positions 2,5,28,29,43,48,60,70,83. Capture counters reset
at each legal inner issue, so record the actual per-edge transitions rather
than treating the final value as a lifetime count. Per successful MatMul require
accepted_steps=active_cycles=1, elapsed_cycles=2, capture_cycles=1, stall_cycles=0.
Recovery must visibly clear/reissue and advance; old SRAM values alone cannot
satisfy it. Larger-shape and invalid MatMuls perform no inner issue.

## Independently derived totals and audit

The table contains 26 successes and 60 faults. Expected fault histogram is:
fault 1:5, fault 2:19, fault 3:5, fault 4:4, fault 5:6, fault 6:1, fault 7:2,
fault 8:3, fault 12:1, fault 13:11, fault 14:3. No 9/10/11/15 completion is expected.

- Descriptor reads:86*32 = **2,752**, each with one successful owned ACK.
- Operand reads: positions 0,1,3,4,42,47,82 = **7** (512 twice,640 once,
  768 once,896 twice,1024 once), each committed and acknowledged.
- Result writes: the three store-address classes above = **9** transactions,
  **36** bytes, each fully acknowledged before its Store becomes terminal.
- Accepted requests and ACKs:2,752+7+9 = **2,768** each.
- Read bytes:2,752+7 = **2,759**; write bytes 36; completion progress sums 43.
- Tags start 0, increase on actual request acceptance and end with next tag 2768;
  the last accepted tag is 2767. There is no epoch reset or tag wrap here.

Record measured cycle/ready-stall/response-delay counts, actual per-class
request and ACK totals, complete completion/fault histogram, safe refills,
held-record edges, nine Run/capture events, per-store oracle checks, all-byte
agreement and the exact scope in workload.audit. Do not substitute these
predicted totals for observed handshakes. Retain all 30 ordinary public outputs
on every replay edge under the existing ResultProtocol and eleven artifacts.

## Integration, validation and stepwise commits

Proposed single public fixture constructor:
`generate_descriptor_rejection_bundle() -> FixtureBundle raise`, identity
`fetched-concurrent-2x2-k2-descriptor-rejection`. Add only explicit
`export-descriptor-rejection` / `audit-descriptor-rejection` choices to the
existing fixture CLI. Keep fixture-local packet/check/stimulus files cohesive,
below 500 lines; reuse shared trace, host, completion snapshot, bundle assembly,
typed comparator and pinned runner. No private observation bridge is required.

First commit the reviewed design. Then implement the fixture and independent
tests as one reviewable slice; commit CLI wiring separately. Run strict targeted
native checks first, two-run deterministic comparison of all eleven artifacts,
typed Equal on expected output and a genuine valid public-output mutation that
must return Mismatch. No expected-failure snapshot updates may repair a fault
priority or missing obligation silently.

Before the completed combined slice gate, compare all **99 artifacts of all
nine older differential fixtures byte-for-byte** against their retained
baselines. Do not alter existing fixture IDs, policies, design names or report
schemas. Then run the completed combined native phase gate once, review public
interfaces and source/dependency boundaries, and commit the validated source
checkpoint. Serialize compilation with the root while the aggregate is live.
Only afterward export to a new evidence directory, run the unchanged pinned
Verilator lint/build/execute and typed audit, retain actual logs/digests and
commit evidence separately. Replay inputs are frozen, never adapted to RTL.

A pass establishes this exact descriptor-location/branch/priority workload,
not every malformed encoding, a pending-producer priority proof, arbitrary
fairness/liveness, full-device formal safety, complete synthesis coverage,
physical performance or the complete Phase 6 gate. Codec length/selector
construction errors are not atomic device packets; partial descriptor fetch
faults belong to the separately tested reader path, not fabricated command IDs.
