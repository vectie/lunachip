# Queue and engine retirement ownership

The next implementation closes the missing link between accepted engine work
and the live retirement table of the existing direct 1x1/K2/host1024/q3 design.
The established queue-control and original-monitor theorems allow arbitrary
terminal timing; they do not establish this ownership. Production hardware,
device ABI, existing observation inventories and accepted proof inputs must
remain unchanged.

## Ownership and edge timing

An engine owns work while its reset-inactive FSM is not Idle, including Done.
Loader and storer use states zero through four; compute uses zero through
three. At PRE Done, the engine still owns exactly one valid, nonterminal entry
with the same internal ticket. Its matched collector terminalizes that entry
on the same edge that the engine consumes its completion and becomes Idle.
The entry remains valid and terminal until ordered external acknowledgment.
It cannot be acknowledged on its collection edge because retirement reads
the old terminal bit. An older terminal entry can retire concurrently.

A newly reserved nonterminal entry can instead belong to the head in Dispatch
state three before engine acceptance. Therefore the reverse invariant is
head-pending or exactly one nonidle engine, not an engine for every nonterminal
entry. Caller IDs are not identities and may repeat. Engine ticket registers
in Idle are stale payload, not owners. Joint reset cancels this ownership
epoch; later work must use fresh reset-established state.

## Essential production state

Discover all roots through the existing 115 typed queue observations. Copy
original register specifications, synchronous reset, enable, initialization,
edge and next-state expressions. No root is reconstructed from a guessed node
ordinal or replaced by a shadow controller.

| State | Registers | Bits |
|---|---:|---:|
| Existing FIFO, head and retirement control | 16 | 37 |
| Head ticket and next ticket | 2 | 64 |
| Three entry terminal flags and tickets | 6 | 99 |
| Three engine FSMs and ticket registers | 6 | 104 |
| Total essential state | 30 | 304 |

Retain the exact three engine acceptance equations, three reset-gated Done
events, all nine matched collectors, local termination, head issue/finish,
reservation, allocation and public acknowledgment. The old free head-finish
and entry-terminal cuts must disappear. Readiness, acceptance, collection,
terminal events, ticket identity and essential state must never become free
inputs or internal premises.

## Payload and transport abstraction

Walk original next/reset/enable expressions and required events through every
combinational node. The first discovery probe may report foreign register,
public input and synchronous memory-read leaves as candidates for explicit
payload/core/transport boundaries. It is not an accepted projection or proof.
Unknown leaf kinds, asynchronous FIFO reads and unexpected control types stop
discovery.

Review and freeze the complete candidate list, original node/type/kind and
register-control signatures, and canonical production IR digest before a
projection is returned. The accepted production digest is
`35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc`.
A new unlisted leaf or changed source requires review; no broad fallback may
silently treat new ownership state as arbitrary data. Actual IDs must come
from canonical traversal and typed roots, not hand-selected guesses.

Foreign leaves may vary arbitrarily between edges, but the original FSM,
opcode, readiness, reset and response masks stay in the copied cone. This
overapproximates when payload/core/transport conditions permit progress; it
does not assume progress or prove the payload's correctness. Keep shared opcode
decode intact so independent free engine-valid bits cannot accept the same
head into several engines. No fairness or internal readiness premise is added.

## Relations to establish

The existing contiguous modulo-three live interval remains necessary. Extend
it with cyclic UInt32 ticket order: for each live offset from read pointer r,
the ticket is next_ticket minus occupancy plus offset, modulo 2^32. Occupancy
is at most three, so live tickets remain distinct even across ticket wrap.
Reservation saves the pre-edge next ticket in both head and selected entry.

Dispatch state three owns its selected valid nonterminal entry and matching
ticket until actual issue or local termination. A head waiting for issue is
not simultaneously engine-owned. Every nonidle engine matches exactly one
valid nonterminal entry; different engines have different tickets. Every
valid nonterminal entry has exactly one pending-head or engine owner.

Acceptance is mutually exclusive, starts only an Idle engine, saves the
current head ticket and removes pending-head ownership in the same commit.
Done produces exactly one matched collector; neither unrelated nor already
terminal entries collect. Collection and local termination preserve entry
identity and prevent duplicate collection. Public acknowledgment clears only
the oldest terminal entry. Simultaneous reservation and an older ACK preserve
ticket order, live interval and ownership without same-edge entry reuse.

These are conclusions to establish from startup reset and original transitions,
not assumptions to inject into a full-device task. A sensitivity comparison
must alter only a checked engine ticket at a genuine nonreset ownership edge,
retain all other assertions and produce the intended sole failure. The exact
comparison and causal trace criterion need source review before execution.

## Implementation and validation order

First add private typed discovery and a deterministic leaf probe. Check all
30 roots/304 bits, exact original specifications, derived-event closure and
source identity. Inspect the complete candidate inventory before freezing it.
Do not add a public exporter, runner or proof receipt at this checkpoint.

In parallel, add continuous native ownership checks over the actual unmodified
hardware. Reuse existing packet, host and observation helpers rather than a
second transport model. Cover duplicate caller IDs, all three engine kinds,
engine reuse, genuine overlapping owners, Done collection versus held public
retirement, simultaneous reserve/ACK and joint reset during owned work. Assert
actual reachability for each claimed scenario. Do not force internal progress
or count an unexercised path as covered.

After inventory review, materialize the exact sequential projection using
existing remapping/register-copy helpers. Add correspondence and representative
transition tests, then the ownership relation and original clock/reset bridge.
Independently review state, cuts, premises and causal sensitivity before serial
pinned engine execution. Retain observed results, including unsuccessful
attempts, and commit each completed implementation checkpoint.

Native checks use targeted tests while working, interface/format/strict native
checks at the checkpoint, and exact compatibility of every preceding artifact.
Do not rerun identical accepted helper engines when source-bound reuse is
valid. Do not retry the unchanged full-device timeout.

## Remaining product gate

This direct-queue ownership work cannot replace FIFO storage order, packet
provenance, dependency-generation composition, whole-Store leases, DMA cursor
and address safety, all nested memories, explicit-fairness completion, fetched
transport or the complete 8x8 formal gate. Original assertions, public premises,
bounds, timeouts and unsuccessful outcomes remain required. No FPGA, physical
timing, GDS or fabrication claim follows.

## Discovery and native checkpoint

Commits `87f9d44` and `4573cb1` complete the private probe and continuous actual
hardware ownership tests. The inspected snapshot retains 30 roots/304 bits,
59 derived events and a 1,155-node cone; all 82 foreign leaves (seven inputs,
75 registers, no memory reads) remain candidates, not accepted cuts. Original
specifications and the production digest are unchanged.

The clean committed checkpoint passes 143 targeted tests and preserves all
184 preceding artifact bytes. Actual witness counters require Store/compute
overlap, younger collection, engine reuse behind held ordered retirement,
simultaneous reservation/ACK and joint reset during owned loader work followed
by fresh recovery. No production or public-interface changes, accepted
projection, inductive ownership result or formal engine invocation follow.
See the [source, inventory and native evidence](evidence/phase6-queue-owner-native-20261007.md)
for exact scope and retained attempts. Materialization and induction are next;
the remaining product gate above stays open.

## Sequential materialization and proof input design

The accepted boundary will be separate from the candidate probe. Its reviewed
literal inventory digest is
`ad6dc56cf01fc55a28eacc6be5dc16493f882b665e1d9570e6e737f9985b289a`,
covering all 175 report lines/37,090 UTF-8 bytes, including complete root and
foreign-leaf specifications, event identity and the production digest. Both
this literal and the existing complete production IR digest must match before
an accepted plan is returned. A new leaf, type, specification, event or report
format requires review; acceptance must not regenerate its expected hash.
This freezes the inspected allowlist without duplicating 82 handwritten IDs.

The report includes only the combinational cone count. Therefore source-bound
closure and field-by-field mapping tests remain indispensable. Select the
disjoint source-order union of 30 roots, 82 accepted leaves, 1,155 original
combinational nodes and the clock: 1,268 nodes, 83 inputs, 30 registers, one
domain, 89 outputs and no memories. Preallocate every mapped reference before
copying register next expressions. Reuse the existing register-copy and
combinational-remap helpers; explicitly retain original edge, reset, enable,
initial value and all required output drivers. There is no assumed relation
or replacement controller in materialization.

Correspondence tests compare every retained register and derived event at PRE
and POST with the actual unmodified hardware. Before each comparison, mirror
all 82 actual foreign-leaf LogicValues into projection inputs. Reuse the existing
formal-package retirement-record packet/host scenario, adding only observer
hooks and a projection edge; do not introduce another transport model. Count
actual engine acceptance/collection and reset witnesses. Separate abstract-cut
tests may vary payload, dependency, arbiter and core conditions, but must not
be described as production reachability.

The proof bridge uses the original rising domain under the existing initialized
global-clock toggle and a sole first-sampled joint-reset premise. Raw ownership
relations depend on current retained state, not reset gating: PRE later reset
can still contain busy engines. Only event expectations are reset-gated.
Assert contiguous ring and cyclic UInt32 ticket order, legal FSM ranges,
pending-head newest ticket and entry, forward/reverse exclusive ownership,
exact matched collection, acceptance exclusivity, reset establishment and
nonrising retained-state hold. These are conclusions, not internal premises.

The causal sensitivity changes only the loader's checked ownership ticket by
UInt32 plus one at a nonreset busy edge after genuine admission, reservation
and loader acceptance history. The dedicated engine-identity assertion compares
the checked entry-match mask with the original one-hot match mask; merely
requiring a checked ticket to match some entry could falsely pass when it
matches the adjacent live ticket. Actual engine tickets, collectors, transitions
and all other assertions remain unchanged. Review the exact assertion set and
trace criterion before engine execution. Exported inputs, if added, remain
proof inputs only and reuse existing artifact/CLI conventions, not a new task
family or permanent proof-runner framework.
