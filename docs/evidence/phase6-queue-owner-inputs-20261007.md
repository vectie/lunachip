# Exact engine/live-entry ownership projection and proof inputs

Commits `02f8faa` (accepted sequential projection and correspondence) and
`ea27f7ec30c252ddf5d48935a051c49e0381e108` (supporting proof inputs/API/CLI)
complete the next checkpoint of the
[ownership design](../PHASE6_QUEUE_OWNERSHIP_LEMMA.md). Clean committed-source
validation passes 151/151 targeted tests and preserves every byte of the
184 preceding artifacts. No formal engine is invoked and no ownership theorem
is established by this checkpoint.

## Accepted projection

The private accepted plan requires both the complete original production IR
digest `35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc`
and the independently frozen complete discovery-report digest
`ad6dc56cf01fc55a28eacc6be5dc16493f882b665e1d9570e6e737f9985b289a`.
The latter covers 175 lines/37,090 UTF-8 bytes, including full original root
and foreign-register specifications. Expected identity is a reviewed literal,
not a hash regenerated from the current candidate report.

Because that report gives only the combinational cone count, an independent
closed-cone traversal must also equal the entire original cone. Roots, cuts,
cone and clock are disjoint, source-bound and copied in source order. All
mapped IDs are allocated before copying forward register-next references.
Existing register-copy/remap helpers preserve clock, edge, reset, enable,
initial value, operands, constants, slices and output drivers. No unlisted-leaf
fallback or replacement controller is introduced.

| Retained projection | Count |
|---|---:|
| Original essential registers / bits | 30 / 304 |
| Accepted foreign leaves | 82 |
| Original combinational nodes | 1,155 |
| Total nodes / input ports | 1,268 / 83 |
| State and derived-event outputs | 30 + 59 |
| Rising clock domains / memories | 1 / 0 |

The foreign leaves are the previously reviewed seven public inputs and
75 registers. Shared packet/opcode decode and actual acceptance, terminal,
collector, allocation, retirement and reset equations remain original logic.
Arbitrary foreign conditions overapproximate delay or failure; they do not
assume readiness or establish payload, dependency, lease or DMA correctness.
Production hardware, ABI and existing observation inventories are unchanged.

## Finite correspondence

The existing formal-package retirement-record packet/host test keeps every
preceding action and assertion. A nonfeeding observer mirrors all 82 actual
foreign LogicValues and compares every retained register and all 59 events
at each PRE and POST. The projection commits using saved PRE values before
POST boundaries are mirrored again. Equality includes width, value and known
masks; genuinely unknown startup roots must be observed.

Unconditional counters require acceptance and matched collection counts
`[2, 1, 1]` across loader/compute/storer, four local terminalizations, seven
public retirements, at least sixteen held-retirement edges, two reset edges
and one later reset with a held terminal record. Fresh post-reset admission,
reservation, local terminalization and retirement each occur exactly once.
These are finite actual-source witnesses, not arbitrary-cut reachability,
physical UInt32 ticket-wrap coverage or universal RTL equivalence.

## Supporting bridge and sensitivity input

The bridge binds original state and events under the existing initialized
global-clock toggle. Its only premise is first-sampled joint reset; later
reset and all 82 foreign boundaries remain symbolic. Raw busy includes Done,
and raw ownership is not bypassed by current later reset. Invalid stale entry
ticket/terminal payloads remain legal.

Nine conclusions cover structure, cyclic UInt32 ticket order, forward/reverse
bijection, engine identity, exact events, sampled edge updates, reset-zero
state, raw establishment and nonrising hold. Pending Dispatch head ownership
requires the newest live ticket and slot. PRE observers feed conclusions only,
never the DUT or additional premises.

The negative differs by exactly one checked-loader-ticket assignment: guarded
UInt32 plus one after reset-cleared admission, reservation and acceptance
history at a nonreset busy loader. The dedicated identity assertion compares
its checked match mask with the original one-hot ownership mask. This also
rejects an incorrect adjacent live ticket. Raw tickets, collectors, transitions,
histories and all other assertions are identical. A qualified actual causal
counterexample and intended sole failure are still required.

Independent source review confirms 50 PRE samples/324 bits plus eight other
observers/311 bits: 58 observer registers/635 bits, with the separate toggling
clock/one bit. These are declaration counts, not prepared-model measurements.

The sole new public API returns existing `FormalBundleArtifact` values;
`queue-owner DIRECTORY` uses the established exclusive-output CLI convention.
Exactly six files are returned: sequential IR, production RTL, binary-helper
RTL, positive bridge, ticket-negative bridge and a source-bound inventory.
No task family, runner profile, typed result or proof receipt is added.
Boolean-helper equivalence, payload correctness and the full-device gate are
explicitly unestablished by export.

## Committed-source validation and retained attempts

The clean frozen checkout reuses
`/private/tmp/lunachip-queue-control-composition-native-20261007.pnlu45`
at exact commit `ea27f7ec30c252ddf5d48935a051c49e0381e108`.
Interface generation, formatting, strict native deny-warning checking with
warning 73, the 151 targeted formal/Phase6/Phase4 CLI tests and native exporter
build all exit zero. Every logged command retains unchanged committed HEAD
and empty full before/after source status. The full native matrix and the
preceding three accelerator ownership scenarios are not rerun here.

Interactive authoring initially encounters a missing parenthesis, reserved
counter name and unused private derives. Repairs preserve semantics and compare
fields directly. A mistyped Phase4 package path exits before testing. The
support note distinguishes these chat-recorded diagnostics from complete raw
logs. The initial inventory-digest script source is also retained; corrected
digest calculation has complete logs. No failed attempt is represented as a
pass.

The original comparison helper exports all inputs and matches all 184 preceding
artifacts, then exits one on ordered directory-array equality for the six new
names. Its source, recorded hash, complete logs and generated files are retained
unchanged. A separate read-only qualifier requires exact membership/count and
canonical regular paths, iterates ownership filenames in explicitly fixed
manifest order, rereads all 184 preceding byte pairs without normalization and
checks the original helper/exporter hashes and clean source context. It exits
zero without re-export, HDL compiler or formal engine invocation. This does
not change the original comparison child's failed outcome.

- Prior 178-artifact manifest: `e87dced38059bf4320763d1ad69b6072685ec01905a75ffddacb208be0db6bd5`.
- Prior six-monitor manifest: `4fff9be6f74b7808cb3f8dcbfae3b0e2f22cdce6c3cf1b8e1f20869eb5757182`.
- New six-input manifest: `2c4074fb653afe0db7519f00ba62dc7bbd44554933c36c6e6fb12e66b488f639`.

Sealed support root:
`/private/tmp/lunachip-queue-owner-proof-support-20261007.LYOxVE`.
Repository-local immutable copy:
`.phase6-queue-owner-inputs-evidence-20261007`.
The 457-file support manifest SHA-256 is
`6cfb3dc05f294b7f81bc011ad8d487f61f79ab85847b1938dca70be60763225e`.
Both complete digest checks and the original/copy recursive comparison exit
zero. Script caches are excluded from sealing and retention. Existing sealed
evidence and the user's untracked codec test are untouched.

## Next required result

Qualify the actual binary helpers and prepared-model state/cuts/premises,
then run reviewed original-clock induction and ticket sensitivity under the
pinned tools. Retain observed outcomes and qualify the actual causal trace;
do not add an ownership premise or retry the unchanged full-device timeout.
Larger composition, FIFO storage order, packet provenance, generation, Store
leases, DMA/memory safety, fairness, fetched transport and the complete 8x8
gate remain open. No runtime performance, FPGA, fabrication or physical chip
claim follows.
