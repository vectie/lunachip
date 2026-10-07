# Original storage discovery and FIFO-to-head native prefix

Clean source `933939d8a696344b927805b2c38e5e665c3fc748` passes the full
native gate: 940/940 tests, interface generation, format checking and strict
native checking. Fresh export preserves all 196 preceding artifacts exactly.
This checkpoint discovers original Store dependencies and materializes the
original descriptor FIFO-to-head storage prefix. No new symbolic proof or
completed Phase 6 gate is claimed.

Implementation commits are Store discovery `896f9e5`, FIFO discovery
`3bfc442`, FIFO materialization `0eb2ba8` and native correspondence `933939d`.
The [remaining formal sequence](../PHASE6_FORMAL.md) and
[FPGA target recommendation](../PHASE7_FPGA_TARGET.md) are also documented.

## Store discovery: candidates, not an accepted model

The ordinary direct 2x2/K2/host1024/q3 Store observation view supplies 48
original register roots/515 bits, 33 derived events and both original C-memory
read references. Discovery follows all register controls, event expressions
and memory ports with 154 typed seeds and complete per-seed provenance. It
finds 948 combinational nodes and 58 distinct foreign candidates, in original
source order. Each depth-four SInt32 C memory retains its actual domain,
ports, addresses, masks, ReadOld/Reject/Fault policy and OneCycle/HoldLast
read state: 256 cell bits plus 64 registered read-result bits in total.

The candidates comprise five public inputs, 49 foreign control/identity
registers and four SInt32 accumulators. Only the four accumulator words are
justified arithmetic-production abstraction candidates; they occur solely
in the two C-write-data seeds. The other foreign registers must be retained
with their control/identity closure or explicitly scoped behind a sound
upstream boundary. In particular, public Store-to-DMA routing needs the
original eleven-register arbiter, not four independently arbitrary leaves.
This checkpoint does not accept all 58 cuts or create a Store projection.

The source digest is
`69b9a4a97b7ee2b050ad46d93ffe1786a54e09a932c431db30afc9255aa09f4a`.
The extracted exact report digest is
`719035593a20e9edace3b6190a5a3ad84b330b27f45a2d6997d9daa42a20dfb7`.
Tests independently enumerate original roots, ports, closures and provenance;
duplicate, omitted, corrupted and unsupported storage inputs fail closed.

## FIFO discovery and exact sequential projection

The ordinary direct 1x1/K2/host1024/q3 queue view retains 28 registers/309
bits, 46 derived events and four actual q3 Bits64 memories: twelve words/768
cell bits and four registered read results/256 bits. Its 126 typed seeds
produce 801 combinational nodes and 59 candidates. Actual pointers, push/pop
fires, registered response-valid next state and head-capture expressions are
discovered from original roles and ports, not guessed memory names or IDs.

The private sequential model retains 893 nodes, 60 input ports and 78
observation aliases. The 59 cuts/805 bits comprise seven public inputs and
52 foreign registers. Each original cut is shared across all uses, including
terminal uses in both fence/head finish and retirement equations. Arbitrary
foreign values can cause premature retirement, poison changes or permanent
dispatch stalls. Those possibilities are not excluded by assumptions.

The accepted boundary is only public admission through actual FIFO storage,
registered response and captured head. It does not establish full ordinal
retirement provenance, engine ownership, completion payloads, fault ordering
or progress. Full packet provenance still needs retained entry/ticket/owner
state or checked composition with its supporting theorems.

The original source digest is
`35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc`;
the exact report digest is
`9a4613301556bfd0229a8696e219e9853047f645813e4f5b27032fdc5476f29d`.
Acceptance requires a freshly rederived complete Probe equality in addition
to both pins. A test changes a convenience field without changing report
bytes and confirms rejection; a hash alone is not trusted.

Independent tests reconstruct each operation and full memory/register
specification without the production remapper. Original source order,
memory-ID mapping, startup X, uninitialized cells/read state, synchronous
reset, masks, addresses, ReadOld, OneCycle and HoldLast are preserved. Reset
does not initialize SRAM or registered read data.

## Finite native correspondence

The actual-device scenario mirrors all 59 full PRE LogicValues, including
unknown masks, into the projection's raw boundaries. Both models then clock
before any POST remirroring. No retained register, memory cell or read result
is injected. Every PRE/POST comparison covers 28 roots, 46 events, four read
results and all twelve cells.

The witness records 100 PRE and 100 POST comparisons, 23 head captures and
17 full simultaneous pop/refill collisions with changed data. Read pointers
wrap seven times per lane; write pointers wrap eight times. Two reset edges
include reset with a full FIFO, held head and populated retirement table:
all twelve known cells and four read results persist while control resets.
Fresh admission and head capture then recover. The original device receives
distinct malformed public packets; the scenario does not fabricate internal
cut histories. This is a finite native witness, not an independent RTL replay
or universal storage theorem.

## Validation and preserved evidence

The clean detached checkout is
`/private/tmp/lunachip-queue-control-composition-native-20261007.pnlu45`.
The earlier discovery-only source `3bfc442` passes 935/935 full native tests;
the final source above passes 940/940. Native tests and compiler jobs are
serialized with `-j1`; full tests additionally use `--no-parallelize`.
The toolchain is Moon 0.1.20260920 (`914d7da`).

The read-only collector verifies 24 clean HEAD/status pairs across the two
source groups and all 25 zero-exit comparison commands. The fresh exporter
compares 153 ordinary files, thirteen generation inputs and six each of
compute, queue-control, monitor, ownership and arbiter inputs: 196 exact
files with no normalization. Source patch and toolchain outputs are retained.

Support root:
`/private/tmp/lunachip-store-discovery-native-20261007.a4rGg7`.
Repository mirror: `.phase6-storage-discovery-evidence-20261007`.
Both verify all 579 inventoried files and match recursively excluding caches.
Manifest SHA256:
`496d01d914fd3e1dcbc7e5fff032744c52d282d53c734e9a8e0b6243db7c614c`.

Unsuccessful drafts are retained separately from clean validation: discovery
syntax/type failures, an 11/12 test attempt with a wrongly typed corruption
target, sequential effect/reserved-identifier failures, and a missing import
in the read-only context collector. The repaired attempts pass. Exact report
extraction and the full PRE/POST witness remain in the sealed support.

The user's untracked `ir/codec/decode_wbtest.mbt` is excluded from the clean
checkout and remains unchanged at SHA256
`733a07a75a013be509738bb853b6fd8d66ca432210a8445db25780acd8d0925f`.
No source, user evidence, VM configuration or tool image is deleted here.

Next are FIFO-prefix symbolic proof, original Store closure, full queue
provenance/retirement composition, fetched transport and DMA bounds, explicit
host fairness/completion, and the full 8x8 formal obligations. No new formal
engine, external HDL compiler, unchanged proof rerun, FPGA measurement or
Phase 6 completion follows from this checkpoint.
