# FluxTile concurrent host engines

The functional implementation is `concurrent_engine_tile(rows~, columns~,
max_reduction~, host_bytes~)`. Three independent command and held-completion
channels feed one A/B loader, one compute/capture engine, and one C storer.
Two physical slots per operand/result and one globally outstanding host-memory
transaction permit computation to overlap real host transfers. This is an
engine integration contract, not the final queued device ABI. Existing serial,
queued/ring constructors and descriptor 0.1 remain unchanged.

## Command channels and faults

Load inputs are `load_command_valid` Bits1, `load_command_operand` UInt1
(0 A, 1 B), `load_command_slot` UInt1, `load_command_id` UInt32,
`load_command_rows`/`columns` UInt13 and `load_command_base`/`stride` UInt32.
Store inputs use the same `store_command_*` names/types without operand.
Compute inputs are `compute_command_valid` Bits1, `compute_command_a_slot`,
`b_slot`, `c_slot` UInt1, `compute_command_id` UInt32, and
`compute_command_rows`/`columns`/`reduction` UInt13. Every field latches on
its channel handshake. Each channel exports `*_command_ready`,
`*_completion_valid`, `*_completion_id` and UInt4 `*_completion_fault`, with
input `*_completion_ready`. Load/store also export UInt32
`*_completion_bytes_completed` and `*_completion_fault_address`.

Dimension fault is 3. Compute missing/mismatched exact source shapes is 4;
store missing/mismatched exact C shape is 5. Transfer stride, alignment and
aperture faults are 6, 7 and 8 in that priority after dimensions/availability.
Matching remote-memory failure is 9; malformed tagged response is 10;
unexpected nested compute/read failure is 11; active sibling cancellation on
transport poison is 15. Unsupported opcode/unused fields cannot be represented
by these operation-specific inputs. Preflight rejection has no storage or
memory-request effect. Failed transfer addresses and partial byte progress
retain the portable transport meanings.
Preflight/internal faults and sibling cancellation report address zero;
owner remote/protocol faults report the actual transaction address. The
transport fault address identifies the malformed response's owning request.

Each engine holds one accepted command/completion; it does not accept another
on the completion-ACK edge. Channels have no global completion ordering.
Caller IDs may duplicate across channels and are not dependency tokens. A
separate [queued concurrent frontend](PHASE6_QUEUED_CONCURRENT.md) now adds
ticket-based dispatch, latest-writer dependencies and ordered retirement;
these are not properties of the independent direct channels themselves.

## Ownership and admission

Older slot reservations always win, including their final release edge. Busy
conflicting slots backpressure admission rather than producing availability
faults, even for otherwise malformed candidates. Among new conflicting legal
admissions, compute wins. Unrelated load, compute and store may all accept on
one edge. A rejected compute reserves nothing and does not suppress an
otherwise legal new transfer.

A legal loader admission reserves and invalidates only its selected A/B slot.
Its final accepted physical SRAM write publishes exact host-load shape and
validity. Failure/cancellation leaves that slot invalid, even if old physical
prefixes or partial writes survive. Other sources and both C slots survive.

Legal compute admission immediately reserves its selected A/B sources and C
destination and enters registered Issue before handing off to the slotted
core. This closes the acceptance-to-core gap without combinational admission
feedback. Sources remain reserved through final successful capture; terminal
internal failure releases them too. Core C validity/shape is authoritative:
the inner accepted MatMul invalidates selected C, and final capture publishes
it. Do not create a second independently writable C metadata table. Result
visibility is exposed privately by references to existing state/signals.

A legal storer admission reserves its C for the entire rectangle, including
gaps between indexed reads, stalled requests and the final external response.
Per-word core pending-read protection alone is insufficient. Store success,
failure or cancellation releases the whole-store reservation without
invalidating C. Operational leases release at terminal processing, not when
the user acknowledges a held completion. Other engines may consume published
data or reuse released slots while that completion is held.

## Transfer and compute construction

Allocate separate transfer/compute registers and arbiter state first. Views
derived from pre-edge registers provide loader bank writes, compute Issue and
store indexed reads. Build one `build_slotted_graph`, then derive response
events and connect each next-state driver once. Reuse existing transfer-bound
and address arithmetic, narrowly shared response/cursor helpers, and the
unchanged two-client arbiter: reader route serves loader, engine route storer.

Loader states are Idle, Request, Wait, Commit and Done. A successful response
buffers one byte; progress advances only on its physical bank-write handshake.
Storer states are Idle, Read, Request, Wait and Done. It launches a synchronous
C read and presents only a successful, identity-matching response as a write.
It advances the rectangle only after a matching successful host response.
The current word may be released from the core in Wait; whole-store ownership
still protects all subsequent reads.

Compute uses Idle, Issue, Run and Done. Its internal completion is drained
into a separate held external completion, so load/store do not depend on that
ACK. Existing compute/capture counters and one-array arithmetic remain intact.
Counters reset on the inner core handshake from Issue into Run, not on the
outer compute-command acceptance. Until that inner handshake they retain the
previous issued MatMul's values; a rejected preflight leaves them unchanged.
The registered Issue overhead is outside the core counters.
The memory port, globally checked/restored transaction tags, latched stalled
payloads and fair serialized arbitration retain the existing bus contract.
Two DMA clients interleave transactions; they do not accept two external
requests on one edge.

## Poison and reset

A malformed accepted bus response terminates its owner with fault 10. After
registered poison, another unfinished transfer terminates with fault 15 and
its already committed progress; new requests and bank writes stop. Existing
held completions remain immutable. Terminal work on the discovery edge wins
over later cancellation. A matching remote failure remains local fault 9.
If a storer observes both a nested-read failure and registered sibling poison,
the concrete internal fault 11 takes priority over cancellation 15. Owner
protocol/remote faults retain higher priority. Done records cannot change.

Already accepted compute continues normally through Run/capture on transport
poison: its fully initialized reserved sources need no bus transactions.
All new admissions stop while poison is visible. Admission on the discovery
edge counts as accepted; such a transfer cancels afterward, while accepted
compute drains. Protocol recovery requires joint device/transport reset.
Reset clears all metadata, leases, pending reads, engine records and arbiter
state and suppresses handshakes. Flush old external transactions/responses
before deassertion. SRAM and already committed host writes are not rolled back;
interrupted commands produce no manufactured completion.

## Required local evidence

Observe accepted load-class and store-class host transactions on edges where
compute active/capture counters advance, then compare final host bytes with
the independent matrix oracle. Exercise signed padded rectangles and 8x8,
held compute/store completions with further loader progress, whole-store
overwrite exclusion between reads and through final ACK, same-edge priorities,
selector latching and duplicate IDs, partial reload/store failures and retries,
both poison owners with continuing compute, and real joint reset flushes.

Require deterministic canonical round trips and local SV, two sets of A/B/C
memories with one multiply array, unchanged legacy goldens, targeted strict
native checks and the repository gate. These are local simulation/construction
claims only. The packet frontend supplies bounded dependency tracking and
ordered retirement; concurrent fetched-ring integration, ABI freeze and named
independent RTL/synthesis/formal gates remain required by Phase 6. No new
assurance framework is introduced here.
