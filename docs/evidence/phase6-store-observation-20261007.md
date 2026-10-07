# Original Store observation and finite preservation checkpoint

Clean source `336fc563878b69f531c0dd5df03beb3b48dbc29e` passes 345/345
targeted native tests. All 196 preceding exported artifacts remain byte-identical.
This checkpoint adds an original-storage observation view and a finite
Store/opposite-slot capture witness. It does not add a sequential projection,
formal theorem or completed Phase 6 gate.

The work is committed in three implementation steps: design `5962093`,
observation seam `ef292ea`, and composed native scenario `336fc56`.
The [Store design](../PHASE6_STORE_PRESERVATION.md) specifies the next discovery
step and the remaining lease/payload obligations.

## Source-bound observation view

`queued_concurrent_store_preservation_fixture()` constructs the ordinary direct
queued device at 2x2/K2/host1024/q3. Optional collectors only read existing
handles and append host metadata; they allocate no hardware and replace no
original transition or expression. There is no new device debug port.

The 83 observations comprise 48 distinct original registers totaling 515 bits,
33 existing expression/event roles, and two actual signed 32-bit C-memory
read references. Register roots cover Store, outer compute including `leased`,
inner slotted/capture and execute control, C-valid/shape metadata, and read
identity/fault state. Each C memory is resolved through the actual MemoryRead
memory/port IDs, with its complete original specification rather than a guessed
name or ordinal.

Four independent black-box tests compare the whole fixture module and canonical
bytes with ordinary construction; independently enumerate roles, types and
register controls; verify both depth-four C memories and their actual ports;
and preserve the preceding 115-role queue and 48-role dependency inventories.
Memory checks retain ReadOld, Reject writes, enabled-access Fault, OneCycle
reads and HoldLast read results. These inventories are not a discovered or
accepted projection size.

Independent source review accepts the nine construction hooks, three metadata
source files and two test files. The root separately reviews the explicit
trait-declaration repair. `StoreTerminal` is fault/cancellation only, not
successful final-response release; `CoreFinalStep` is a raw comparison, not an
advance event. Pending-read protection blocks inner admission through ACK;
outer compute can legally acquire Issue after Store Done while a prior read
response drains. The observation view does not change these semantics.

## Finite actual-device witness

The new public-port scenario uses the existing native simulator, byte-memory
environment and matrix oracle. It seeds old C0 at 3x2/K5 and an independent
C1 computation at 2x3/K2 with signed-extreme inputs. A genuinely accepted loader
transaction keeps the arbiter waiting while Store C0 progresses through six
actual read-window edges without any Store bus grant.

Same-C0 overwrite is blocked. Opposite-slot C1 compute is accepted and must
perform five Run advances, six capture advances and the final capture while
Store still cannot receive a grant. Compute acknowledgment removes compute
busy as an alternative explanation; the still-reserved C0 remains blocked.
After the actual loader response, the first offered Store word must equal the
old C0 oracle. Delaying the grant matters: an already-latched arbiter payload
could otherwise conceal corruption of the pending read response.

The scenario then checks all six public payload fields through at least three
stalled Offer edges, completes exactly six correct host writes, checks final
Store acknowledgment and no release-edge reuse credit, and reads back both
old C0 and fresh C1 through actual host writes. Transport remains unpoisoned.
Indexed-read occurrence is inferred from the authoritative FSM and actual
read-window edges, not directly counted through a new internal callback.
This is a finite native witness, not independent RTL replay or a formal
numerical MatMul/payload-preservation theorem.

## Validation and preservation

The detached checkout
`/private/tmp/lunachip-queue-control-composition-native-20261007.pnlu45`
is clean at the complete source commit above. Module-wide interface generation,
format checking, strict native checking with warning 73, targeted tests,
exporter build, fresh artifact comparison, source patch capture and toolchain
version capture all exit zero. All sixteen corresponding HEAD records agree;
all sixteen status records are empty. Tests cover `designs/flux_tile`,
`validation/formal`, `cmd/phase6-formal-fixtures` and `cmd/phase4-formal`.
The full module test matrix is not rerun. Five focused new tests also pass in
the preceding working-source context, recorded separately from clean validation.

Fresh export compares 153 ordinary artifacts, thirteen generation inputs and
six each of compute, queue-control, monitor, ownership and arbiter inputs:
196 exact files, without normalization. No external HDL compiler, formal
engine, helper qualification or unchanged whole-device timeout is rerun.

Support root:
`/private/tmp/lunachip-store-observation-native-20261007.DkJzPo`.
Repository mirror: `.phase6-store-observation-evidence-20261007`.
Both verify all 485 inventoried files, with manifest SHA256
`4491784b3244322b4b1c9adcff22e31eb9d77b23bae10335571f08932e023d7f`.
Recursive copies are exact excluding disposable build/dependency caches.
The initial strict-check failure contains twenty public trait-declaration
diagnostics; explicit Debug/Eq extensions fix it without a hardware change.
The unsuccessful attempt and subsequent successful checks are retained.

The user-authorized cleanup removed exactly two rebuildable `_build` caches
(approximately 636 MiB), not source or sealed evidence. The user's untracked
`ir/codec/decode_wbtest.mbt` is excluded from clean validation and unchanged at
SHA256 `733a07a75a013be509738bb853b6fd8d66ca432210a8445db25780acd8d0925f`.

Next discover the complete original storage/control closure with reviewed
foreign-leaf provenance before materialization. Store formal lease/payload
preservation, FIFO storage and packet provenance/generation composition, DMA
and nested-memory bounds, fetched transport, fairness and full 8x8 formal
checks remain open. No runtime speedup, FPGA or physical-chip result follows.
