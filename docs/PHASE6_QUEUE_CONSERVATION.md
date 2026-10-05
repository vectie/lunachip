# Direct queue admission and retirement conservation

The next supporting formal slice links actual packet admission, FIFO storage,
head reservation, engine ownership and ordered retirement in the fixed direct
1x1/K2/host1024/queue-depth-three device. Local generation and compute induction
does not establish this queue composition. Conservation must be checked before
the proposed 252-edge completion deadline relies on its predecessor bound.
This supporting slice does not replace the original transport or dependency
safety tasks, establish fetched-reader liveness or complete Phase 6.

## Observation seam

Add a purpose-specific `queued_concurrent_queue_formal_fixture` returning
`QueueConservationFixture`, with immutable `QueueConservationObservation` records
and `QueueConservationRole` keys owned by the public FluxTile package. The fixed
ordinary hardware and the existing 48 dependency observations stay unchanged.
Do not extend the old role enum or change its inventory. All new observations
reference existing canonical nodes and their exact signal types; they add no
builder operation, register, memory, derived debug signal or device port.

The complete new inventory contains 115 semantic references:

| Group | Roles | Count |
| --- | --- | --- |
| Four FIFO lanes | PushValid, PushReady, PopRequest, PopReady, ResponseValid, ResponseData, Occupancy, Full and Empty, each indexed by lane | 36 |
| Head | Four Lane values, State, Entry, Ticket, NextTicket, Reserve, Pop, Capture, Issue, Finish, Reject, Fence and LocalFault | 16 |
| Retirement | ReadPointer, WritePointer, Occupancy, Fire and the five selected public terminal fields | 9 |
| Three entries | Valid, Terminal, Ticket, Id, Fault, Progress, Address, Allocate, Acknowledge and LocalTerminal, plus three Collector signals per entry | 39 |
| Three engines | Accept, State, Ticket, Terminal and Fault for loader, compute and storer | 15 |

Use distinct role names such as `FifoPushValid(lane)`, `HeadLane(lane)`,
`EntryCollector(entry, engine)` and `EngineState(engine)`. Engine indices are
loader zero, compute one and storer two. Entry indices are zero through two;
lane indices are zero through three. Roles may intentionally alias the same
physical node. Role keys themselves are unique.

FIFO data and head lanes are Bits64, controls Bits1 and FIFO occupancy UInt2.
Head state is UInt2; head entry, retirement pointers and retirement occupancy
are UInt5. Tickets, IDs, progress and addresses are UInt32, faults UInt4.
Loader and storer state are UInt3; compute state is UInt2. Selected retirement
fields keep their exact ordinary types. Tests must check signedness/type as
well as width and canonical-node identity.

Capture existing FIFO push-valid expressions individually inside their original
lane construction order. Do not hoist four builder calls into one shared call.
Record head Pop/Capture/Issue/Finish inside their existing construction seam
and collect/allocate/ACK/local-terminal expressions inside the actual entry
loop. Engine state and ticket references come from authoritative registers.
Optional host-side observation arrays are forwarded through private constructors
only. An observer helper may call `Signal.id`, `signal_type` and register `value`,
but no hardware builder. Ordinary constructors use no observer.

The native seam gate checks all 115 unique typed roles, deterministic order,
actual register/memory-read kinds where required, emitted-name resolution and
byte-identical ordinary canonical IR and RTL. Existing dependency observations
remain exactly 48. Directed native checks exercise real FIFO admission and
response/capture, head allocation, terminal collection and held ordered
retirement, including duplicate caller IDs. A seam is not a proof result.

## Production conservation obligations

Use the actual full DUT and existing clock/export/typed-task framework. No
handwritten replacement queue or mirrored controller becomes the proof target.
If a smaller exact cone is needed later, identify every retained state element,
memory and free boundary, verify closure/reset/type/alias correspondence, and
keep its conditional theorem distinct from full-device safety.

The first production assertions cover these relations:

- All four lane pushes, pops and synchronous response-valid signals are
  atomic; occupancies agree, remain bounded and justify actual packet storage.
- Head capture receives the complete accepted packet in order. Reservation
  uses a free retirement entry and publishes exactly one next ticket.
- Retirement pointers and occupancy stay in range; occupancy equals live
  entries. Allocation, collection and acknowledgement follow actual pre-edge
  ownership, including simultaneous unrelated events.
- Each dispatched engine owns one valid, nonterminal entry with its accepted
  ticket. Distinct live owners cannot alias; caller IDs may repeat.
- Each engine terminal is collected only into its matching outstanding entry;
  local rejection/Fence terminates the reserved head's actual entry. A completed
  entry is immutable until acknowledgement or reset.
- Public retirement selects the oldest valid terminal entry, matches its
  entire payload and advances only on the real valid/ready handshake. A held
  oldest completion permits younger terminal collection without reordering.

An independent admission/retirement ordinal watch provides packet identity.
It may track older outstanding packets and saved admitted lanes, but must not
assume ticket uniqueness, dependency readiness, engine acceptance or terminal
arrival. Account atomically for an older retirement on the watched admission
edge; the newly admitted packet cannot retire on that same edge. Reset cancels
the watch and all monitor ownership through the actual joint-reset contract.

Keep the initial reset and existing legal-public-peer assumptions. Later reset
and transport fault behavior remain symbolic for safety unless a separately
named obligation explicitly scopes them. Fairness belongs only to public peers
and is not required to assume internal progress for these safety relations.
Existing PRE sampling, two-global-step clock convention and complete original
property groups remain authoritative.

## Tasks and evidence

After the native seam is validated, add a supporting production bounded safety
task through the existing property plans, bindings, registry, clocked export,
tasks, pinned runner and typed result mapping. Add full/refill, simultaneous
collector and held-oldest/younger-progress witnesses that actually traverse
the stated paths. A sensitivity task alters a monitor comparison only and must
fail its exact selected assertion after a real admission; production DUT and
peer assumptions remain identical. Preserve original receipts and independently
inspect PRE-phase ownership and packet identity in every witness/counterexample.

Record native source checkpoint and unchanged older artifacts separately from
tool results. No PASS is inferred from generated bundles, preparation, timeouts,
partial progress or a cover alone. Selected bounded/inductive results name their
exact properties, bounds and assumptions. Original transport/dependency safety,
lease/cursor progress, arbitration bounds, the proposed fairness deadline,
fetched-device composition and the 8x8 scope remain separate unfinished gates
until their own direct results are retained.

Implementation proceeds in three commits: the fixed observation specification,
the validated metadata seam with native evidence, and the actual checked
supporting tasks/results. The complete Phase 5 aggregate runs from a separate
clean frozen checkout; agents may edit this branch while it runs, but compiler,
tests and external engines remain serial.

## First supporting task scope

Start with three structural assertions on the actual full direct-q3 device,
one full/refill cover and one comparison-only sensitivity task. Keep the
existing 256 global steps / 128 DUT clocks, timeout 600, PRE sampling and four
legal-public-peer assumptions: initial joint reset, descriptor payload hold,
response payload hold and joint-reset response flush. Later reset and malformed
responses remain symbolic; neither fairness nor internal progress is assumed.

The lane assertion binds every push fire to the public descriptor handshake,
every pop fire to HeadPop, equal bounded occupancies and exact full/empty flags.
A sampled nonreset pop produces all four synchronous response-valid signals
at the next PRE boundary. The retirement assertion checks pointer ranges,
free pre-edge allocation, exact selected acknowledgements and simultaneous
pointer/occupancy updates.

For population conservation, maintain an independent small outstanding counter
from only public descriptor admission and public completion retirement. Reset
clears it; simultaneous handshakes update it atomically. At every sampled
nonreset boundary require:

~~~text
outstanding = FIFO occupancy + retirement occupancy + unreserved head
unreserved head = 1 when HeadState is 1 or 2, otherwise 0
retirement occupancy = widened sum of the three EntryValid bits
outstanding <= 7
~~~

HeadState three is already counted by its reserved retirement entry. A stale
EntryTerminal bit may remain set after acknowledgement clears EntryValid, so
terminal ownership and immutability assertions must be guarded by validity.
No ticket uniqueness or internal readiness is assumed by this counter.

The cover requires FIFO occupancy three followed by actual simultaneous full
pop and public admission, then synchronous response and head capture. The
negative changes only the checked retirement-population comparison by one
after genuine admission and reservation; the raw relation must still hold.
It selects the exact population assertion, leaving DUT, peer assumptions and
ghost history identical. A complete counterexample remains required.

Saved packet identity through response/head/entry/retirement, accepted-engine
ownership, collector matching, immutable terminal payloads and oldest selection
follow as separate supporting tasks with their own witnesses. This first
structural task cannot stand in for them or the original safety tasks. The
full memory-bearing DUT may still be expensive; no solver speedup is assumed.
