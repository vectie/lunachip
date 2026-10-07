# Packet composition: qualified cover and negative, positive still open

At clean `ad22f658b0b99e735e1ab0c0a5bdd1a187b3f90d`, the original packet
composition reaches its same-watch retirement cover and detects the intended
checked-packet mutation. The positive base case passes twenty global steps,
but its induction attempt times out. This is not a positive packet theorem,
the required longer bounded gate, or completion of Phase 6.

## Inputs and preparation

The eight actual exported inputs use the unchanged ordinary direct
1x1/K2/host1024/q3 source and the 201-output private projection described in
[the native checkpoint](phase6-packet-composition-native-20261007.md).
The complete input inventory digest is
`a0d0ffcadd19053fff4b37741dda55aff07cfb275202727191dfc53bfb1a389a`.
The clean collector passes its actual one test; working and clean stdout
are byte-identical. Complete artifact markers and printed digests are
validated before creating the eight files.

The actual source-bound helper audit reuses all nineteen complete comparison
function pairs from the retained accepted whole-miter result. The complete
remaining DUT, arithmetic functions, four array-knownness functions and eight
memory bounds are unchanged. This is pointwise binary helper equivalence,
not a new SAT run, four-state or sequential equivalence claim.

The positive model retains 54 original registers/876 bits, four actual held
reads/256 bits, and four real q3 Bits64 arrays/12 cells/768 bits. All 1,900
original storage bits remain; SRAM initialization is arbitrary. It has
seventeen assertions: seven original conditions, eight actual memory bounds,
checked strengthening and global nonrising retention. Exactly four original
public premises remain, with no private readiness or storage assumption.

Eleven unused foreign cuts are optimized away: source 101 cuts/1,557 bits
plus the original one-bit watch selector become 91 source `anyseq` values/
1,242 bits. Twelve additional lowering `setundef` values/520 bits model
invalid read branches and inactive write fields, not arbitrary legal read
data. Independent review accepts actual rising-01/PRE sampling, ReadOld,
HoldLast and complete nonrising storage retention. Four final positive model
files byte-match separately extracted, independently audited live snapshots.

## Actual serial results

All jobs use the existing pinned Yosys/SBY/Bitwuzla image, multiclock lowering,
and a 600-second timeout. Source HEAD/status and input/helper/tool pins remain
unchanged before and after execution.

| Job | Actual result | Accepted scope |
| --- | --- | --- |
| Positive `prove20` | TIMEOUT, child exit 8, 601 s | Base case checks 0–19 pass in 34 s; no induction proof |
| Original p13 cover, horizon 256 | PASS, child exit 0, 57 s; reached step 13 | Complete coherent watched-packet transfer and ordinal retirement witness |
| Selected p12 negative, horizon 256 | Expected FAIL, child exit 0, 15 s; fails step 7 | Genuine watched-response sensitivity to the sole checked bit-128 mutation |

SBY's expected-failure handling returns zero for the qualified negative; this
does not mean its assertion passed. The enclosing collection command's zero
exit similarly does not turn the positive timeout into success.

The positive induction reports p12 failure at 96 seconds, then times out
exporting its trace. The retained 556,039-byte VCD has complete values for
global steps 0–11; step 12 has only a step marker. No SMTC/YW/testbench or
complete failing transition exists. It begins with impossible predecessor
history, but neither a reset-reachable hardware bug nor induction success
can be inferred. Its VCD digest is
`4d6deede8605da2470ccc8958de8a3d98fbfe3ae82defdd16986bce09bf363a5`.

## Coherent cover and selected negative

Both accepted traces include complete VCD, SMTC, Yosys witness and Verilog
testbench formats. Cover contains fourteen complete snapshots through POST
time 130; negative contains eight through POST time 70. Times below refer to
actual trace PRE states, not elapsed seconds or a new timing contract.

| Cover PRE time | Actual watched path |
| --- | --- |
| 20 | Public 256-bit admission/watch, FIFO write slot 0, no older ordinal |
| 40 | Actual watched FIFO pop from slot 0; no simultaneous refill |
| 60 | Four valid ReadOld responses equal saved packet; real head Capture |
| 80 | Held head equals saved packet; reserve entry 0 with ticket 0 |
| 100 | Matching live entry/head owner; actual local rejection makes terminal |
| 120 | Entry 0 terminal, valid/ready and entry ACK; original independent ordinal watch retires and p13 is true |

POST130 releases the entry and advances the retirement pointer. Saved lanes
are `[0x840200, 0x1ffd, 0x200000000, 0]`, caller ID 0. Final fault is 1,
progress and address are zero: this is a rejection-path witness, not useful
arithmetic or Store execution. Later admissions also use ID 0; identity is
ordinal, not an ID lookup. A younger full-FIFO pop/refill occurs alongside
the watched ACK at PRE120. It is not a watched collision-policy witness.
The watched cell has legitimately been overwritten while saved packet,
held read results and head remain exact.

The negative admits all 256 bits set at PRE20, genuinely pops slot 0 at
PRE40, and has all four valid responses/Capture/raw equality at PRE60.
Only the checked packet flips bit 128: lane 2 becomes
`FFFFFFFFFFFFFFFE`. Response/current/p12 checks fail; other current subchecks
are true and prior sticky failure is zero. POST70 captures the unmodified
raw packet and records the transfer history. Negative preparation retains
only p12 and exactly the same four premises. Reversing its sole checked
expression restores the complete selected positive source.

Cover VCD digest:
`ec7540945f28fc1d735f99873e312e86065585b660d03a96ffb0c078c96469d9`.
Negative VCD digest:
`d6358324281c708ec2bde6095813e726da1b4c2aab81b40c107036af36d115ef`.
Cover and negative do not prove the assertions removed for their selection.

## Retention and next step

The complete 1,423-file support is sealed at
`/private/tmp/lunachip-packet-proof-inputs-20261007.X7IAoW` and mirrored under
`.phase6-packet-composition-experiment-evidence-20261007`. Both manifests
verify and complete directories compare identically. Manifest digest:
`8c0408928a3e66351e91f5f4d34ba6227d90382c4a0d1adb62b18c1e6d5daf33`.
Unsuccessful input drafts, compile/reachability failures, the premature
extractor failure, partial induction trace and actual job directories remain.

Separate source `5f4c4b9` adds only checked original predecessor-history
relations to the existing strengthening assertion, with no new state,
premise, cut or label. Strict native checks and four proof-input tests pass
in working and clean contexts. This sealed experiment does not claim a
solver result for that refinement. Positive packet safety, Store/DMA,
dependency conjunction, completion, fetched and 8x8 closure remain open.

## Refined history: actual results, not a closed positive gate

The separate clean `5f4c4b95c1439f2bd714c121f17aa3b6ace51a8f` experiment
uses the same 1,900 original storage bits, seventeen conclusions and four
public premises. Only the checked predecessor-history relation changes.
Its `prove20` run again times out after 601 s: base checks 0–19 pass, but
p8 induction fails and trace export is incomplete. This is neither a
reset-reachable counterexample nor an induction proof.

Fresh cover and selected negative runs are independently qualified. Cover
passes at step 13 in 59 s, including actual FIFO response, head Capture,
reservation and watched ordinal retirement. Its public tuple is ID 0,
fault 15, bytes 0, address 0: a local-error path, not successful Store.
The negative fails p12 at step 7 in 16 s after the genuine four-lane
response; only checked bit 128 changes. All four trace formats are complete.
The source-bound comparison-helper audit and complete nonhelper DUT remain
unchanged; no additional state, premise or free legal-read data is introduced.

Complete support, including unsuccessful drafts and partial induction trace,
is sealed at `/private/tmp/lunachip-packet-history-refinement-20261007.9rrRWa`
and mirrored in `.phase6-packet-history-refinement-evidence-20261007`.
Both manifests verify and match, with manifest digest
`0817d8a583009b995e742bfa8d881e6dc77707968df9b1b9e75be6eec514d6f2`.

An additional clean `d7b555d6d55deec63b6e394662b12d2e6e0df3e6`
`bmc256` run retains all seventeen conclusions and exactly the same four
premises. The actual prepared model is byte-identical to the refined positive
model. It times out after 601 s, completing checks 0–60 and starting 61;
no counterexample is reported. Actual work is retained separately at
`/private/tmp/lunachip-packet-bounded-driver-20261007.fSruFo`.
Its complete support is sealed with manifest digest
`c123d8f54fab3433bd05900f542c52d004bade2559a199435b4297ed5894b481`;
this separate support has not been mirrored into the repository.
This is not a completed 256-step gate. The next experiment partitions the
same seventeen conclusions into disjoint 11/3/2/1 groups, keeping all four
premises and the full 256-step bound. No group result is yet accepted.
